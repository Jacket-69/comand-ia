-- ============================================================
-- COMAND-IA · Migración 0001 · Schema inicial
-- ============================================================
-- Contrato de datos Sprint 1 — Fundación
-- RLS deny-by-default en todas las tablas
-- Multi-tenant via venue_id
-- ============================================================

-- ─── Extensiones ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Función auxiliar: updated_at automático ──────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 1. VENUE (local gastronómico)
-- ============================================================
CREATE TABLE venue (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  timezone    TEXT NOT NULL DEFAULT 'America/Santiago',
  currency    TEXT NOT NULL DEFAULT 'CLP',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_venue_updated_at
  BEFORE UPDATE ON venue
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE venue ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. APP_USER (usuarios del sistema)
-- ============================================================
CREATE TABLE app_user (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  venue_id    UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  role        TEXT NOT NULL DEFAULT 'staff' CHECK (role IN ('owner', 'staff')),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_app_user_updated_at
  BEFORE UPDATE ON app_user
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE app_user ENABLE ROW LEVEL SECURITY;

CREATE POLICY "app_user_select_own_venue" ON app_user
  FOR SELECT USING (
    venue_id IN (
      SELECT venue_id FROM app_user WHERE id = auth.uid()
    )
  );

CREATE POLICY "app_user_insert_owner" ON app_user
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM app_user
      WHERE id = auth.uid()
        AND venue_id = app_user.venue_id
        AND role = 'owner'
    )
  );

-- ============================================================
-- 3. STAFF_PIN (PINs de garzones)
-- ============================================================
CREATE TABLE staff_pin (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id    UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  pin_hash    TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (venue_id, user_id)
);

CREATE TRIGGER trg_staff_pin_updated_at
  BEFORE UPDATE ON staff_pin
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE staff_pin ENABLE ROW LEVEL SECURITY;

CREATE POLICY "staff_pin_venue_access" ON staff_pin
  FOR SELECT USING (
    venue_id IN (
      SELECT venue_id FROM app_user WHERE id = auth.uid()
    )
  );

-- ─── Función SECURITY DEFINER: verificar PIN ─────────────────
CREATE OR REPLACE FUNCTION verify_pin(
  p_venue_id UUID,
  p_pin TEXT
)
RETURNS TABLE(user_id UUID, display_name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT sp.user_id, au.display_name
  FROM staff_pin sp
  JOIN app_user au ON au.id = sp.user_id
  WHERE sp.venue_id = p_venue_id
    AND sp.pin_hash = crypt(p_pin, sp.pin_hash)
    AND au.is_active = TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 4. MENU_CATEGORY (categorías del menú)
-- ============================================================
CREATE TABLE menu_category (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id    UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  icon        TEXT,
  color       TEXT,
  sort_order  INT NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_menu_category_updated_at
  BEFORE UPDATE ON menu_category
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE menu_category ENABLE ROW LEVEL SECURITY;

CREATE POLICY "menu_category_venue_access" ON menu_category
  FOR ALL USING (
    venue_id IN (
      SELECT venue_id FROM app_user WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 5. MENU_ITEM (ítems del menú)
-- ============================================================
CREATE TABLE menu_item (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id        UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  category_id     UUID NOT NULL REFERENCES menu_category(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  description     TEXT,
  price           NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  image_url       TEXT,
  is_available    BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order      INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_menu_item_updated_at
  BEFORE UPDATE ON menu_item
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE menu_item ENABLE ROW LEVEL SECURITY;

CREATE POLICY "menu_item_venue_access" ON menu_item
  FOR ALL USING (
    venue_id IN (
      SELECT venue_id FROM app_user WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 6. DINING_TABLE (mesas del local)
-- ============================================================
CREATE TABLE dining_table (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id    UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  number      INT NOT NULL,
  label       TEXT,
  capacity    INT NOT NULL DEFAULT 4,
  status      TEXT NOT NULL DEFAULT 'available'
              CHECK (status IN ('available', 'occupied', 'reserved')),
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (venue_id, number)
);

CREATE TRIGGER trg_dining_table_updated_at
  BEFORE UPDATE ON dining_table
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE dining_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "dining_table_venue_access" ON dining_table
  FOR ALL USING (
    venue_id IN (
      SELECT venue_id FROM app_user WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 7. CUSTOMER_ORDER (pedidos / órdenes)
-- ============================================================
CREATE TABLE customer_order (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id        UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  table_id        UUID NOT NULL REFERENCES dining_table(id),
  waiter_id       UUID REFERENCES app_user(id),
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'preparing', 'ready', 'served', 'paid', 'cancelled')),
  guest_count     INT NOT NULL DEFAULT 1,
  subtotal        NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax             NUMERIC(12,2) NOT NULL DEFAULT 0,
  total           NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_customer_order_updated_at
  BEFORE UPDATE ON customer_order
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE customer_order ENABLE ROW LEVEL SECURITY;

CREATE POLICY "customer_order_venue_access" ON customer_order
  FOR ALL USING (
    venue_id IN (
      SELECT venue_id FROM app_user WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 8. ORDER_ITEM (ítems dentro de un pedido)
-- ============================================================
CREATE TABLE order_item (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id        UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  order_id        UUID NOT NULL REFERENCES customer_order(id) ON DELETE CASCADE,
  menu_item_id    UUID NOT NULL REFERENCES menu_item(id),
  quantity        INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price      NUMERIC(10,2) NOT NULL,
  subtotal        NUMERIC(12,2) NOT NULL,
  notes           TEXT,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'preparing', 'ready', 'served', 'cancelled')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_order_item_updated_at
  BEFORE UPDATE ON order_item
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE order_item ENABLE ROW LEVEL SECURITY;

CREATE POLICY "order_item_venue_access" ON order_item
  FOR ALL USING (
    venue_id IN (
      SELECT venue_id FROM app_user WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 9. PENDING_OP (cola FIFO offline sync)
-- ============================================================
CREATE TABLE pending_op (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id        UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  table_name      TEXT NOT NULL,
  operation       TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
  payload         JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at       TIMESTAMPTZ
);

ALTER TABLE pending_op ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pending_op_venue_access" ON pending_op
  FOR ALL USING (
    venue_id IN (
      SELECT venue_id FROM app_user WHERE id = auth.uid()
    )
  );

-- ============================================================
-- 10. AUDIT_LOG (registro de auditoría)
-- ============================================================
CREATE TABLE audit_log (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  venue_id        UUID NOT NULL REFERENCES venue(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES app_user(id),
  action          TEXT NOT NULL,
  table_name      TEXT NOT NULL,
  record_id       UUID,
  old_data        JSONB,
  new_data        JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_log_venue_access" ON audit_log
  FOR SELECT USING (
    venue_id IN (
      SELECT venue_id FROM app_user
      WHERE id = auth.uid() AND role = 'owner'
    )
  );

-- ============================================================
-- Trigger: compute_order_total
-- ============================================================
CREATE OR REPLACE FUNCTION compute_order_total()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE customer_order
  SET subtotal = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM order_item
    WHERE order_id = NEW.order_id
      AND status != 'cancelled'
  ),
  total = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM order_item
    WHERE order_id = NEW.order_id
      AND status != 'cancelled'
  )
  WHERE id = NEW.order_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_compute_order_total
  AFTER INSERT OR UPDATE OR DELETE ON order_item
  FOR EACH ROW EXECUTE FUNCTION compute_order_total();
