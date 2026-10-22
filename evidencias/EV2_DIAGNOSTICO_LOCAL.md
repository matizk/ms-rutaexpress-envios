# Diagnostico EV2 (solo lectura)

Fecha: 2026-10-15T19:47:32.4525399-03:00
No se incluyen valores de variables, tokens, datos personales, URLs cloud ni logs de aplicaciones.

- OK: Carpeta hermana y Dockerfile: frontend-rutaexpress
- OK: Carpeta hermana y Dockerfile: ms-rutaexpress-bff
- OK: Carpeta hermana y Dockerfile: ms-rutaexpress-catalog
- OK: Carpeta hermana y Dockerfile: ms-rutaexpress-shipments
- OK: Carpeta hermana y Dockerfile: ms-rutaexpress-messaging
- OK: Carpeta hermana y Dockerfile: ms-rutaexpress-report
- OK: compose.ev2.yml presente
- OK: .env.ev2 legible, sin variables duplicadas
- OK: Variable CATALOG_DB_PASSWORD definida sin marcador de ejemplo, minimo 16 caracteres (valor oculto)
- OK: Variable SHIPMENTS_DB_PASSWORD definida sin marcador de ejemplo, minimo 16 caracteres (valor oculto)
- OK: Variable MESSAGING_DB_PASSWORD definida sin marcador de ejemplo, minimo 16 caracteres (valor oculto)
- OK: Variable RABBITMQ_PASSWORD definida sin marcador de ejemplo, minimo 16 caracteres (valor oculto)
- OK: Variable RABBITMQ_ERLANG_COOKIE definida sin marcador de ejemplo, minimo 16 caracteres (valor oculto)
- OK: Emisor Cognito con formato de User Pool; no certifica acceso remoto
- OK: App Client publico de Cognito configurado; no se requieren client secrets
- OK: Destino API: BFF local o HTTPS sin credenciales, query ni fragmento; URL no mostrada
- OK: azure-config.json legible con enabled booleano
- PENDIENTE: Login institucional no habilitado; la revision local Cognito no acredita Azure
- Contenedor bff: running / Up 49 minutes
- Contenedor catalog: running / Up 2 hours
- Contenedor catalog-db: running / Up 2 hours (healthy)
- Contenedor frontend: running / Up 4 minutes
- Contenedor messaging: running / Up 49 minutes
- Contenedor messaging-db: running / Up 2 hours (healthy)
- Contenedor rabbitmq-1: running / Up 2 hours (healthy)
- Contenedor rabbitmq-2: running / Up 2 hours (healthy)
- Contenedor report: running / Up 2 hours
- Contenedor shipments: running / Up 44 minutes
- Contenedor shipments-db: running / Up 2 hours (healthy)
- OK: frontend y cinco backends con health UP.

Pendiente de evidencia externa: login Duoc real, permisos Azure, API Manager y servicios EC2/RDS/RabbitMQ cloud.
