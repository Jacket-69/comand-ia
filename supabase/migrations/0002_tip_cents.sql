-- COMA-014: propina del cierre de cuenta. Separada de total_cents (ACID-3):
-- total_cents = SUM de ítems; tip_cents NO entra al total. La decide el comensal.
ALTER TABLE customer_order
  ADD COLUMN tip_cents INT NOT NULL DEFAULT 0 CHECK (tip_cents >= 0);
