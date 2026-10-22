-- SOLO LECTURA. Ejecutar por separado en cada DB con su usuario de aplicacion.
\set ON_ERROR_STOP on
SELECT current_database() AS database, current_user AS application_user;
SELECT ssl, version AS tls_version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();
SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;
-- Conteos de tablas existentes, sin mostrar destinatarios, correos, tokens ni claves.
SELECT format('SELECT %L AS table_name, count(*) AS records FROM %I.%I',
    tablename, schemaname, tablename)
FROM pg_tables WHERE schemaname='public' ORDER BY tablename \gexec
