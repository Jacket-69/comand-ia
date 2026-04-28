-- ============================================================
-- COMAND-IA · Seed · Datos de desarrollo
-- ============================================================

-- ─── Venue de ejemplo ─────────────────────────────────────────
INSERT INTO venue (id, name, slug, timezone, currency)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'Restaurante El Fogón',
  'el-fogon',
  'America/Santiago',
  'CLP'
);

-- ─── Categorías del menú ──────────────────────────────────────
INSERT INTO menu_category (id, venue_id, name, icon, color, sort_order) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Entradas', '🥗', '#4285F4', 1),
  ('c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Almuerzos', '🍽️', '#FF9800', 2),
  ('c0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Parrilladas', '🥩', '#D32F2F', 3),
  ('c0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'Bebidas', '🍹', '#9C27B0', 4),
  ('c0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'Postres', '🍰', '#E91E63', 5),
  ('c0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'Café', '☕', '#E65100', 6);

-- ─── Ítems del menú ───────────────────────────────────────────
INSERT INTO menu_item (venue_id, category_id, name, description, price, sort_order) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Empanada de Pino', 'Empanada al horno rellena de pino', 2500, 1),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Tabla de Quesos', 'Selección de quesos con frutos secos', 8500, 2),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Pastel de Choclo', 'Clásico pastel de choclo con pino', 9500, 1),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Cazuela de Vacuno', 'Cazuela tradicional con papas y zapallo', 8000, 2),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'Lomo Vetado 300g', 'Lomo a la parrilla con chimichurri', 15000, 1),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'Costillar BBQ', 'Costillar de cerdo con salsa BBQ', 18000, 2),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', 'Pisco Sour', 'Pisco sour clásico chileno', 5500, 1),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', 'Limonada Natural', 'Limonada con menta fresca', 3000, 2),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000005', 'Leche Asada', 'Postre tradicional de leche asada', 4500, 1),
  ('a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000006', 'Café Espresso', 'Espresso simple', 2000, 1);

-- ─── Mesas del local (20 mesas) ──────────────────────────────
INSERT INTO dining_table (venue_id, number, capacity, status)
SELECT
  'a0000000-0000-0000-0000-000000000001',
  n,
  CASE WHEN n <= 10 THEN 4 ELSE 6 END,
  'available'
FROM generate_series(1, 20) AS n;
