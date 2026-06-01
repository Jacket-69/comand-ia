BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(5);

SELECT has_column(
  'public',
  'customer_order',
  'tip_cents',
  'customer_order tiene columna tip_cents'
);

SELECT col_type_is(
  'public',
  'customer_order',
  'tip_cents',
  'integer',
  'tip_cents es de tipo integer'
);

SELECT col_not_null(
  'public',
  'customer_order',
  'tip_cents',
  'tip_cents es NOT NULL'
);

SELECT col_default_is(
  'public',
  'customer_order',
  'tip_cents',
  '0',
  'tip_cents tiene DEFAULT 0'
);

SELECT col_has_check(
  'public',
  'customer_order',
  'tip_cents',
  'tip_cents tiene constraint CHECK'
);

SELECT * FROM finish();

ROLLBACK;
