-- EJECUCION MANUAL contra RDS, despues de revisar el destino y obtener permiso.
-- psql 16+, conectado a postgres con usuario administrador, TLS verify-full.
-- No borra datos ni cambia claves/propietarios de recursos existentes.
\set ON_ERROR_STOP on
\set ECHO none
\getenv catalog_password CATALOG_DB_PASSWORD
\getenv shipments_password SHIPMENTS_DB_PASSWORD
\getenv messaging_password MESSAGING_DB_PASSWORD
SELECT length(:'catalog_password') >= 24 AND length(:'shipments_password') >= 24
    AND length(:'messaging_password') >= 24 AS passwords_ok \gset
\if :passwords_ok
\else
    \echo 'ERROR: faltan claves privadas de minimo 24 caracteres. No se creo nada.'
    \quit 3
\endif
-- Para roles existentes, verificar por separado que la clave configurada coincida.
SELECT format('CREATE ROLE rx_catalog LOGIN PASSWORD %L', :'catalog_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rx_catalog') \gexec
SELECT format('CREATE ROLE rx_shipments LOGIN PASSWORD %L', :'shipments_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rx_shipments') \gexec
SELECT format('CREATE ROLE rx_messaging LOGIN PASSWORD %L', :'messaging_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rx_messaging') \gexec
SELECT 'CREATE DATABASE catalog_db OWNER rx_catalog'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'catalog_db') \gexec
SELECT 'CREATE DATABASE shipments_db OWNER rx_shipments'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'shipments_db') \gexec
SELECT 'CREATE DATABASE messaging_db OWNER rx_messaging'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'messaging_db') \gexec
SELECT datname, pg_get_userbyid(datdba) AS owner
FROM pg_database WHERE datname IN ('catalog_db', 'shipments_db', 'messaging_db');
