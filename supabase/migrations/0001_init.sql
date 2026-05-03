-- ============================================================
-- COMAND-IA · Migracion 0001 · Schema inicial
-- ============================================================
-- Contrato de datos Sprint 1: multi-tenant, RLS deny-by-default
-- y reglas de integridad para Capa 1/Capa 2.
-- ============================================================

-- Extensiones
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Tipos de dominio
-- ============================================================
CREATE TYPE app_role AS ENUM ('owner', 'staff');
CREATE TYPE order_status AS ENUM (
  'open',
  'sent',
  'preparing',
  'ready',
  'closed',
  'cancelled'
);
CREATE TYPE order_item_status AS ENUM (
  'sent',
  'preparing',
  'ready',
  'cancelled'
);
CREATE TYPE payment_method AS ENUM ('cash', 'card', 'transfer', 'other');
CREATE TYPE pin_auth_status AS ENUM ('valid', 'invalid', 'blocked');

-- ============================================================
-- Funciones auxiliares
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ============================================================
-- 1. VENUE
-- ============================================================
CREATE TABLE venue (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  settings    JSONB NOT NULL DEFAULT '{}',
  timezone    TEXT NOT NULL DEFAULT 'America/Santiago',
  currency    TEXT NOT NULL DEFAULT 'CLP',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_venue_updated_at
  BEFORE UPDATE ON venue
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 2. APP_USER
-- ============================================================
CREATE TABLE app_user (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  venue_id      UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  email         TEXT NOT NULL,
  display_name  TEXT NOT NULL DEFAULT '',
  role          app_role NOT NULL DEFAULT 'staff',
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (venue_id, email)
);

CREATE TRIGGER trg_app_user_updated_at
  BEFORE UPDATE ON app_user
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- SECURITY DEFINER evita recursion de RLS cuando las policies consultan app_user.
CREATE OR REPLACE FUNCTION current_app_user()
RETURNS TABLE(user_id UUID, venue_id UUID, role app_role)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT au.id, au.venue_id, au.role
  FROM public.app_user au
  WHERE au.id = auth.uid()
    AND au.is_active = TRUE
  LIMIT 1
$$;

CREATE OR REPLACE FUNCTION current_venue_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT cau.venue_id FROM public.current_app_user() cau LIMIT 1
$$;

CREATE OR REPLACE FUNCTION is_owner_of_venue(p_venue_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.current_app_user() cau
    WHERE cau.venue_id = p_venue_id
      AND cau.role = 'owner'
  )
$$;

ALTER TABLE venue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "venue_select_own" ON venue
  FOR SELECT USING (
    owner_id = auth.uid()
    OR id = current_venue_id()
  );

CREATE POLICY "venue_insert_owner" ON venue
  FOR INSERT WITH CHECK (owner_id = auth.uid());

CREATE POLICY "venue_update_owner" ON venue
  FOR UPDATE USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

ALTER TABLE app_user ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_user_select_own_venue" ON app_user
  FOR SELECT USING (venue_id = current_venue_id());

CREATE POLICY "app_user_insert_self_owner" ON app_user
  FOR INSERT WITH CHECK (
    id = auth.uid()
    AND role = 'owner'
    AND EXISTS (
      SELECT 1
      FROM venue v
      WHERE v.id = app_user.venue_id
        AND v.owner_id = auth.uid()
    )
  );

CREATE POLICY "app_user_insert_staff_by_owner" ON app_user
  FOR INSERT WITH CHECK (
    role = 'staff'
    AND is_owner_of_venue(venue_id)
  );

CREATE POLICY "app_user_update_by_owner" ON app_user
  FOR UPDATE USING (is_owner_of_venue(venue_id))
  WITH CHECK (is_owner_of_venue(venue_id));

-- ============================================================
-- 3. STAFF_PIN
-- ============================================================
CREATE TABLE staff_pin (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id         UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  app_user_id      UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  pin_hash         TEXT NOT NULL,
  failed_attempts  INT NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  locked_until     TIMESTAMPTZ,
  last_failed_at   TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (venue_id, app_user_id)
);

CREATE TRIGGER trg_staff_pin_updated_at
  BEFORE UPDATE ON staff_pin
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE staff_pin ENABLE ROW LEVEL SECURITY;

-- Deliberadamente sin SELECT: el cliente nunca debe leer pin_hash.
CREATE POLICY "staff_pin_insert_owner" ON staff_pin
  FOR INSERT WITH CHECK (is_owner_of_venue(venue_id));

CREATE POLICY "staff_pin_update_owner" ON staff_pin
  FOR UPDATE USING (is_owner_of_venue(venue_id))
  WITH CHECK (is_owner_of_venue(venue_id));

CREATE POLICY "staff_pin_delete_owner" ON staff_pin
  FOR DELETE USING (is_owner_of_venue(venue_id));

CREATE OR REPLACE FUNCTION validate_staff_pin()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user app_user%ROWTYPE;
BEGIN
  SELECT *
  INTO v_user
  FROM app_user
  WHERE id = NEW.app_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'staff_pin must reference an existing app_user';
  END IF;

  IF v_user.venue_id <> NEW.venue_id OR v_user.role <> 'staff' THEN
    RAISE EXCEPTION 'staff_pin app_user must be staff in the same venue';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_staff_pin
  BEFORE INSERT OR UPDATE ON staff_pin
  FOR EACH ROW EXECUTE FUNCTION validate_staff_pin();

CREATE OR REPLACE FUNCTION verify_pin(
  p_venue_id UUID,
  p_pin TEXT,
  p_display_name TEXT DEFAULT NULL
)
RETURNS TABLE(user_id UUID, display_name TEXT, auth_status pin_auth_status)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_pin staff_pin%ROWTYPE;
  v_display_name TEXT;
  v_next_attempts INT;
BEGIN
  SELECT sp.*
  INTO v_pin
  FROM staff_pin sp
  JOIN app_user au ON au.id = sp.app_user_id
  WHERE sp.venue_id = p_venue_id
    AND au.is_active = TRUE
    AND (
      p_display_name IS NULL
      OR LOWER(au.display_name) = LOWER(BTRIM(p_display_name))
    )
  ORDER BY sp.created_at
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::UUID, NULL::TEXT, 'invalid'::pin_auth_status;
    RETURN;
  END IF;

  IF v_pin.locked_until IS NOT NULL AND v_pin.locked_until > NOW() THEN
    RETURN QUERY SELECT NULL::UUID, NULL::TEXT, 'blocked'::pin_auth_status;
    RETURN;
  END IF;

  IF v_pin.pin_hash = crypt(p_pin, v_pin.pin_hash) THEN
    UPDATE staff_pin
    SET failed_attempts = 0,
        locked_until = NULL,
        last_failed_at = NULL
    WHERE id = v_pin.id;

    SELECT au.display_name
    INTO v_display_name
    FROM app_user au
    WHERE au.id = v_pin.app_user_id;

    RETURN QUERY
      SELECT v_pin.app_user_id, v_display_name, 'valid'::pin_auth_status;
    RETURN;
  END IF;

  v_next_attempts := v_pin.failed_attempts + 1;

  UPDATE staff_pin
  SET failed_attempts = v_next_attempts,
      last_failed_at = NOW(),
      locked_until = CASE
        WHEN v_next_attempts >= 5 THEN NOW() + INTERVAL '15 minutes'
        ELSE NULL
      END
  WHERE id = v_pin.id;

  RETURN QUERY SELECT NULL::UUID, NULL::TEXT, 'invalid'::pin_auth_status;
END;
$$;

-- ============================================================
-- 4. MENU_CATEGORY
-- ============================================================
CREATE TABLE menu_category (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id    UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  icon        TEXT,
  color       TEXT,
  sort_order  INT NOT NULL DEFAULT 0,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (venue_id, name)
);

CREATE TRIGGER trg_menu_category_updated_at
  BEFORE UPDATE ON menu_category
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE menu_category ENABLE ROW LEVEL SECURITY;

CREATE POLICY "menu_category_venue_access" ON menu_category
  FOR ALL USING (venue_id = current_venue_id())
  WITH CHECK (venue_id = current_venue_id());

-- ============================================================
-- 5. MENU_ITEM
-- ============================================================
CREATE TABLE menu_item (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id     UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  category_id  UUID NOT NULL REFERENCES menu_category(id) ON DELETE RESTRICT,
  name         TEXT NOT NULL,
  description  TEXT,
  price_cents  INT NOT NULL CHECK (price_cents >= 0),
  image_url    TEXT,
  active       BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (venue_id, category_id, name)
);

CREATE TRIGGER trg_menu_item_updated_at
  BEFORE UPDATE ON menu_item
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE menu_item ENABLE ROW LEVEL SECURITY;

CREATE POLICY "menu_item_venue_access" ON menu_item
  FOR ALL USING (venue_id = current_venue_id())
  WITH CHECK (venue_id = current_venue_id());

CREATE OR REPLACE FUNCTION validate_menu_item()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_category_venue UUID;
BEGIN
  SELECT mc.venue_id
  INTO v_category_venue
  FROM menu_category mc
  WHERE mc.id = NEW.category_id;

  IF v_category_venue IS NULL OR v_category_venue <> NEW.venue_id THEN
    RAISE EXCEPTION 'menu_item venue_id must match menu_category venue_id';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_menu_item
  BEFORE INSERT OR UPDATE ON menu_item
  FOR EACH ROW EXECUTE FUNCTION validate_menu_item();

-- ============================================================
-- 6. DINING_TABLE
-- ============================================================
CREATE TABLE dining_table (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id    UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  label       TEXT NOT NULL,
  capacity    INT NOT NULL DEFAULT 4 CHECK (capacity > 0),
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (venue_id, label)
);

CREATE TRIGGER trg_dining_table_updated_at
  BEFORE UPDATE ON dining_table
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE dining_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "dining_table_venue_access" ON dining_table
  FOR ALL USING (venue_id = current_venue_id())
  WITH CHECK (venue_id = current_venue_id());

-- ============================================================
-- 7. CUSTOMER_ORDER
-- ============================================================
CREATE TABLE customer_order (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id         UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  dining_table_id  UUID NOT NULL REFERENCES dining_table(id) ON DELETE RESTRICT,
  status           order_status NOT NULL DEFAULT 'open',
  opened_by        UUID REFERENCES app_user(id),
  opened_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at        TIMESTAMPTZ,
  total_cents      INT NOT NULL DEFAULT 0 CHECK (total_cents >= 0),
  payment_method   payment_method,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_customer_order_updated_at
  BEFORE UPDATE ON customer_order
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE customer_order ENABLE ROW LEVEL SECURITY;

CREATE POLICY "customer_order_venue_access" ON customer_order
  FOR ALL USING (venue_id = current_venue_id())
  WITH CHECK (venue_id = current_venue_id());

CREATE OR REPLACE FUNCTION validate_customer_order()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_table_venue UUID;
  v_user_venue UUID;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status = 'closed' THEN
    RAISE EXCEPTION 'customer_order % is closed and cannot be modified', OLD.id;
  END IF;

  SELECT dt.venue_id
  INTO v_table_venue
  FROM dining_table dt
  WHERE dt.id = NEW.dining_table_id;

  IF v_table_venue IS NULL OR v_table_venue <> NEW.venue_id THEN
    RAISE EXCEPTION 'customer_order venue_id must match dining_table venue_id';
  END IF;

  IF NEW.opened_by IS NOT NULL THEN
    SELECT au.venue_id
    INTO v_user_venue
    FROM app_user au
    WHERE au.id = NEW.opened_by;

    IF v_user_venue IS NULL OR v_user_venue <> NEW.venue_id THEN
      RAISE EXCEPTION 'customer_order opened_by must belong to the same venue';
    END IF;
  END IF;

  IF NEW.status = 'closed' AND NEW.closed_at IS NULL THEN
    NEW.closed_at = NOW();
  END IF;

  IF NEW.status <> 'closed' THEN
    NEW.payment_method = NULL;
    NEW.closed_at = NULL;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_customer_order
  BEFORE INSERT OR UPDATE ON customer_order
  FOR EACH ROW EXECUTE FUNCTION validate_customer_order();

-- ============================================================
-- 8. ORDER_ITEM
-- ============================================================
CREATE TABLE order_item (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id              UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  order_id              UUID NOT NULL REFERENCES customer_order(id) ON DELETE CASCADE,
  menu_item_id          UUID NOT NULL REFERENCES menu_item(id) ON DELETE RESTRICT,
  name_snapshot         TEXT NOT NULL,
  price_cents_snapshot  INT NOT NULL CHECK (price_cents_snapshot >= 0),
  quantity              INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  comments              TEXT,
  status                order_item_status NOT NULL DEFAULT 'sent',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_order_item_updated_at
  BEFORE UPDATE ON order_item
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE order_item ENABLE ROW LEVEL SECURITY;

CREATE POLICY "order_item_venue_access" ON order_item
  FOR ALL USING (venue_id = current_venue_id())
  WITH CHECK (venue_id = current_venue_id());

CREATE OR REPLACE FUNCTION validate_order_item()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_order customer_order%ROWTYPE;
  v_item menu_item%ROWTYPE;
BEGIN
  SELECT *
  INTO v_order
  FROM customer_order
  WHERE id = COALESCE(NEW.order_id, OLD.order_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_item must reference an existing customer_order';
  END IF;

  IF v_order.status = 'closed' THEN
    RAISE EXCEPTION 'customer_order % is closed and cannot change items', v_order.id;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  SELECT *
  INTO v_item
  FROM menu_item
  WHERE id = NEW.menu_item_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_item must reference an existing menu_item';
  END IF;

  IF NEW.venue_id <> v_order.venue_id OR NEW.venue_id <> v_item.venue_id THEN
    RAISE EXCEPTION 'order_item venue_id must match order and menu item venue_id';
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.name_snapshot = v_item.name;
    NEW.price_cents_snapshot = v_item.price_cents;
  ELSE
    NEW.name_snapshot = OLD.name_snapshot;
    NEW.price_cents_snapshot = OLD.price_cents_snapshot;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_order_item
  BEFORE INSERT OR UPDATE OR DELETE ON order_item
  FOR EACH ROW EXECUTE FUNCTION validate_order_item();

CREATE OR REPLACE FUNCTION compute_order_total()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id UUID;
BEGIN
  v_order_id := COALESCE(NEW.order_id, OLD.order_id);

  UPDATE customer_order
  SET total_cents = (
    SELECT COALESCE(SUM(price_cents_snapshot * quantity), 0)::INT
    FROM order_item
    WHERE order_id = v_order_id
      AND status <> 'cancelled'
  )
  WHERE id = v_order_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_compute_order_total
  AFTER INSERT OR UPDATE OR DELETE ON order_item
  FOR EACH ROW EXECUTE FUNCTION compute_order_total();

-- ============================================================
-- 9. AUDIT_LOG
-- ============================================================
CREATE TABLE audit_log (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id     UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  app_user_id  UUID REFERENCES app_user(id),
  action       TEXT NOT NULL,
  entity       TEXT NOT NULL,
  entity_id    UUID,
  diff         JSONB NOT NULL DEFAULT '{}',
  at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_log_select_owner" ON audit_log
  FOR SELECT USING (is_owner_of_venue(venue_id));

-- ============================================================
-- 10. ANALYTICS RPC
-- ============================================================
CREATE OR REPLACE FUNCTION dashboard_kpis(
  p_venue_id UUID,
  p_period TEXT
)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  WITH bounds AS (
    SELECT CASE p_period
      WHEN 'today' THEN date_trunc('day', NOW())
      WHEN '7d' THEN NOW() - INTERVAL '7 days'
      WHEN '30d' THEN NOW() - INTERVAL '30 days'
      ELSE NOW() - INTERVAL '7 days'
    END AS start_at
  ),
  closed_orders AS (
    SELECT co.*
    FROM customer_order co, bounds b
    WHERE co.venue_id = p_venue_id
      AND co.status = 'closed'
      AND co.closed_at >= b.start_at
  ),
  totals AS (
    SELECT
      COALESCE(SUM(total_cents), 0)::INT AS total_sales_cents,
      COUNT(*)::INT AS order_count,
      COALESCE(ROUND(AVG(total_cents)), 0)::INT AS average_ticket_cents
    FROM closed_orders
  ),
  top_items AS (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'name', ranked.name_snapshot,
          'quantity', ranked.quantity
        )
        ORDER BY ranked.quantity DESC
      ),
      '[]'::JSONB
    ) AS items
    FROM (
      SELECT oi.name_snapshot, SUM(oi.quantity)::INT AS quantity
      FROM order_item oi
      JOIN closed_orders co ON co.id = oi.order_id
      WHERE oi.status <> 'cancelled'
      GROUP BY oi.name_snapshot
      ORDER BY quantity DESC
      LIMIT 5
    ) ranked
  ),
  peak_hour AS (
    SELECT EXTRACT(HOUR FROM co.closed_at)::INT AS hour
    FROM closed_orders co
    GROUP BY hour
    ORDER BY COUNT(*) DESC, hour ASC
    LIMIT 1
  )
  SELECT jsonb_build_object(
    'period', p_period,
    'total_sales_cents', totals.total_sales_cents,
    'order_count', totals.order_count,
    'average_ticket_cents', totals.average_ticket_cents,
    'top_items', top_items.items,
    'peak_hour', peak_hour.hour
  )
  FROM totals
  CROSS JOIN top_items
  LEFT JOIN peak_hour ON TRUE
$$;

-- pending_op no se crea en Supabase: es una tabla local-only en Drift.
