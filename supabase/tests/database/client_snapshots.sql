BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(7);

-- ── Fixture propia (aislada del seed; se revierte con ROLLBACK) ────────────

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'b1000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'snapshots@test.local',
  crypt('password', gen_salt('bf')),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  NOW(),
  NOW()
);

INSERT INTO venue (id, owner_id, name, slug)
VALUES (
  'a1000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000001',
  'Venue Snapshots Test',
  'venue-snapshots-test'
);

INSERT INTO menu_category (id, venue_id, name)
VALUES (
  'c1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'Categoria Test'
);

-- Precio ACTUAL del menú: 2000. Los snapshots offline traerán 1500.
INSERT INTO menu_item (id, venue_id, category_id, name, price_cents)
VALUES (
  'd1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001',
  'Lomo Saltado',
  2000
);

INSERT INTO dining_table (id, venue_id, label)
VALUES (
  'e1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'Mesa Test'
);

INSERT INTO customer_order (id, venue_id, dining_table_id, status)
VALUES (
  'f1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'sent'
);

-- ── 1-2: INSERT con snapshot del cliente → se respeta (COMA-008, ACID-2) ───

INSERT INTO order_item (
  id, venue_id, order_id, menu_item_id,
  name_snapshot, price_cents_snapshot, quantity
) VALUES (
  '01000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'f1000000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000001',
  'Lomo Saltado (promo)',
  1500,
  1
);

SELECT is(
  (SELECT name_snapshot FROM order_item
   WHERE id = '01000000-0000-0000-0000-000000000001'),
  'Lomo Saltado (promo)',
  'INSERT respeta name_snapshot provisto por el cliente'
);

SELECT is(
  (SELECT price_cents_snapshot FROM order_item
   WHERE id = '01000000-0000-0000-0000-000000000001'),
  1500,
  'INSERT respeta price_cents_snapshot provisto por el cliente'
);

-- ── 3-4: INSERT con name_snapshot vacío → rellena desde menu_item ──────────

INSERT INTO order_item (
  id, venue_id, order_id, menu_item_id,
  name_snapshot, price_cents_snapshot, quantity
) VALUES (
  '01000000-0000-0000-0000-000000000002',
  'a1000000-0000-0000-0000-000000000001',
  'f1000000-0000-0000-0000-000000000001',
  'd1000000-0000-0000-0000-000000000001',
  '',
  0,
  1
);

SELECT is(
  (SELECT name_snapshot FROM order_item
   WHERE id = '01000000-0000-0000-0000-000000000002'),
  'Lomo Saltado',
  'INSERT con snapshot vacío rellena name_snapshot desde menu_item'
);

SELECT is(
  (SELECT price_cents_snapshot FROM order_item
   WHERE id = '01000000-0000-0000-0000-000000000002'),
  2000,
  'INSERT con snapshot vacío rellena price_cents_snapshot desde menu_item'
);

-- ── 5: UPDATE no puede mutar los snapshots (ACID-2 intacto) ─────────────────

UPDATE order_item
SET name_snapshot = 'Hackeado', price_cents_snapshot = 1
WHERE id = '01000000-0000-0000-0000-000000000001';

SELECT is(
  (SELECT name_snapshot || '/' || price_cents_snapshot::text FROM order_item
   WHERE id = '01000000-0000-0000-0000-000000000001'),
  'Lomo Saltado (promo)/1500',
  'UPDATE restaura los snapshots desde OLD (inmutables, ACID-2)'
);

-- ── 6: total_cents recalculado usa el snapshot del cliente (ACID-3) ─────────

SELECT is(
  (SELECT total_cents FROM customer_order
   WHERE id = 'f1000000-0000-0000-0000-000000000001'),
  3500,
  'compute_order_total suma los snapshots respetados (1500 + 2000)'
);

-- ── 7: pedido cerrado sigue bloqueando INSERT de ítems (ACID-4 intacto) ─────

UPDATE customer_order
SET status = 'closed', payment_method = 'cash'
WHERE id = 'f1000000-0000-0000-0000-000000000001';

SELECT throws_ok(
  $$INSERT INTO order_item (
      id, venue_id, order_id, menu_item_id,
      name_snapshot, price_cents_snapshot, quantity
    ) VALUES (
      '01000000-0000-0000-0000-000000000003',
      'a1000000-0000-0000-0000-000000000001',
      'f1000000-0000-0000-0000-000000000001',
      'd1000000-0000-0000-0000-000000000001',
      'Tardío',
      1000,
      1
    )$$,
  'P0001',
  'customer_order f1000000-0000-0000-0000-000000000001 is closed and cannot change items',
  'INSERT sobre pedido cerrado sigue bloqueado (ACID-4)'
);

SELECT * FROM finish();

ROLLBACK;
