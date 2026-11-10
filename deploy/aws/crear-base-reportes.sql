-- Ejecutar con psql conectado a postgres del RDS, con TLS verify-full.
-- La clave se lee desde el entorno del proceso psql.
\set ON_ERROR_STOP on
\set ECHO none
\getenv report_password REPORT_DB_PASSWORD
SELECT length(:'report_password') >= 24 AS password_ok \gset
\if :password_ok
\else
    \echo 'ERROR: falta la clave de Reportes de al menos 24 caracteres.'
    \quit 3
\endif
SELECT format('CREATE ROLE rx_report LOGIN PASSWORD %L', :'report_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rx_report') \gexec
SELECT 'CREATE DATABASE report_db OWNER rx_report'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'report_db') \gexec
SELECT datname, pg_get_userbyid(datdba) AS owner FROM pg_database WHERE datname = 'report_db';
