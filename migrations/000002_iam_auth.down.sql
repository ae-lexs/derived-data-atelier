DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dda_app') THEN
    DROP OWNED BY dda_app;
    DROP USER dda_app;
  END IF;
END $$;
