-- ============================================================
-- 0003 · Snapshots de order_item provistos por el cliente
-- ============================================================
-- Motivo (COMA-008, ADR-0013): el sync offline drena pending_op hacia
-- Supabase tiempo después de la toma del pedido. ACID-2 fija los snapshots
-- de order_item AL MOMENTO DEL PEDIDO (offline, en el dispositivo), no al
-- momento del drenaje. El trigger original re-snapshoteaba desde menu_item
-- en cada INSERT, pisando el valor capturado offline si el precio cambió
-- entre la toma y la sincronización.
--
-- Cambio: en INSERT se respetan name_snapshot/price_cents_snapshot provistos;
-- solo se rellenan desde menu_item cuando name_snapshot viene vacío ('') o
-- NULL — el sentinel que usa el seed y cualquier insert server-side.
-- En UPDATE siguen congelados desde OLD (inmutables, ACID-2).
--
-- Forward-only e idempotente (CREATE OR REPLACE; el trigger existente apunta
-- a la misma función).

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
    -- ACID-2: el snapshot del cliente manda (capturado al momento del pedido,
    -- offline). Solo se rellena desde menu_item si no viene provisto.
    IF NEW.name_snapshot IS NULL OR NEW.name_snapshot = '' THEN
      NEW.name_snapshot = v_item.name;
      NEW.price_cents_snapshot = v_item.price_cents;
    END IF;
  ELSE
    NEW.name_snapshot = OLD.name_snapshot;
    NEW.price_cents_snapshot = OLD.price_cents_snapshot;
  END IF;

  RETURN NEW;
END;
$$;
