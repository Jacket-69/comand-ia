BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(4);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'pending_op'
  ),
  'pending_op no existe en Supabase porque es local-only'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'staff_pin'
      AND cmd = 'SELECT'
  ),
  'staff_pin no tiene policy SELECT'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    JOIN pg_class pc ON pc.relname = c.table_name
    JOIN pg_namespace pn ON pn.oid = pc.relnamespace
    WHERE pn.nspname = 'public'
      AND c.column_name = 'venue_id'
      AND pc.relrowsecurity = FALSE
  ),
  'toda tabla public con venue_id tiene RLS habilitada'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.column_name = 'venue_id'
      AND c.table_name <> 'staff_pin'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_policies p
        WHERE p.schemaname = 'public'
          AND p.tablename = c.table_name
      )
  ),
  'toda tabla public con venue_id tiene policies'
);

SELECT * FROM finish();

ROLLBACK;
