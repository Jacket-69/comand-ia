-- ============================================================
-- COMAND-IA · Seed · Datos de desarrollo
-- ============================================================

-- Usuarios Auth de ejemplo. En Supabase local el seed corre con privilegios
-- suficientes para poblar auth.users y poder satisfacer las FK del schema.
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    'b0000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'owner@comandia.local',
    crypt('password', gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Duenio Demo"}',
    NOW(),
    NOW()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b0000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'carlos@comandia.local',
    crypt('password', gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Carlos"}',
    NOW(),
    NOW()
  );

-- Venue de ejemplo
INSERT INTO venue (id, owner_id, name, slug, timezone, currency)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'Restaurante El Fogon',
  'el-fogon',
  'America/Santiago',
  'CLP'
);

-- Usuarios de aplicacion
INSERT INTO app_user (id, venue_id, email, display_name, role) VALUES
  (
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'owner@comandia.local',
    'Duenio Demo',
    'owner'
  ),
  (
    'b0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000001',
    'carlos@comandia.local',
    'Carlos',
    'staff'
  );

-- PIN demo: Carlos / 1234
INSERT INTO staff_pin (venue_id, app_user_id, pin_hash)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000002',
  crypt('1234', gen_salt('bf'))
);

-- Categorias del menu
INSERT INTO menu_category (id, venue_id, name, icon, color, sort_order) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Entradas', 'salad', '#4285F4', 1),
  ('c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Almuerzos', 'plate', '#FF9800', 2),
  ('c0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Parrilladas', 'grill', '#D32F2F', 3),
  ('c0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'Bebidas', 'drink', '#9C27B0', 4),
  ('c0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'Postres', 'cake', '#E91E63', 5),
  ('c0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'Cafe', 'coffee', '#E65100', 6);

-- Items del menu. Precios en centavos CLP: 2500 CLP => 250000.
INSERT INTO menu_item (
  id,
  venue_id,
  category_id,
  name,
  description,
  price_cents,
  sort_order
) VALUES
  ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Empanada de Pino', 'Empanada al horno rellena de pino', 250000, 1),
  ('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Tabla de Quesos', 'Seleccion de quesos con frutos secos', 850000, 2),
  ('d0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Pastel de Choclo', 'Clasico pastel de choclo con pino', 950000, 1),
  ('d0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Cazuela de Vacuno', 'Cazuela tradicional con papas y zapallo', 800000, 2),
  ('d0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'Lomo Vetado 300g', 'Lomo a la parrilla con chimichurri', 1500000, 1),
  ('d0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'Costillar BBQ', 'Costillar de cerdo con salsa BBQ', 1800000, 2),
  ('d0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', 'Pisco Sour', 'Pisco sour clasico chileno', 550000, 1),
  ('d0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', 'Limonada Natural', 'Limonada con menta fresca', 300000, 2),
  ('d0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', 'Leche Asada', 'Postre tradicional de leche asada', 450000, 1),
  ('d0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000006', 'Cafe Espresso', 'Espresso simple', 200000, 1);

-- Mesas del local
INSERT INTO dining_table (id, venue_id, label, capacity, sort_order)
SELECT
  ('e0000000-0000-0000-0000-' || LPAD(n::TEXT, 12, '0'))::UUID,
  'a0000000-0000-0000-0000-000000000001',
  'Mesa ' || n,
  CASE WHEN n <= 10 THEN 4 ELSE 6 END,
  n
FROM generate_series(1, 20) AS n;

-- Pedidos demo para KDS y analitica
INSERT INTO customer_order (
  id,
  venue_id,
  dining_table_id,
  status,
  opened_by,
  opened_at,
  notes
) VALUES
  (
    'f0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'e0000000-0000-0000-0000-000000000001',
    'sent',
    'b0000000-0000-0000-0000-000000000002',
    NOW() - INTERVAL '35 minutes',
    'Sin cebolla'
  ),
  (
    'f0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000001',
    'e0000000-0000-0000-0000-000000000003',
    'sent',
    'b0000000-0000-0000-0000-000000000002',
    NOW() - INTERVAL '2 hours',
    NULL
  );

INSERT INTO order_item (venue_id, order_id, menu_item_id, name_snapshot, price_cents_snapshot, quantity, comments) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', '', 0, 2, 'Bien calientes'),
  ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000008', '', 0, 2, NULL),
  ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000003', '', 0, 1, NULL),
  ('a0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000007', '', 0, 2, NULL);

UPDATE customer_order
SET status = 'closed',
    payment_method = 'card',
    closed_at = NOW() - INTERVAL '90 minutes'
WHERE id = 'f0000000-0000-0000-0000-000000000002';
