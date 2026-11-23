-- grants.sql

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'inspector') THEN
        CREATE USER inspector WITH PASSWORD 'NetoSQL2025';
    END IF;
END
$$;

GRANT ALL PRIVILEGES ON SCHEMA andrienko_food TO inspector;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA andrienko_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA andrienko_food TO inspector;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA andrienko_food TO inspector;

GRANT USAGE ON SCHEMA exts TO inspector;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA exts TO inspector;
