# ms-rutaexpress-envios

> Versión de integración EV2: `desarrollo`, mediante el [PR #2](https://github.com/matizk/ms-rutaexpress-envios/pull/2). `main` conserva EV1 hasta una entrega validada. [Descarga](PREPARACION_EQUIPO_EV2.md), [pendientes del equipo](CONTINUAR_EV2_EQUIPO.md), [Gitflow](COLABORACION.md) y [AWS](deploy/aws/README.md). Cloud/login institucional pendientes de verificación real.

Microservicio de envíos de RutaExpress para DSY1107. EV2 agrega aceptación del operador y outbox transaccional; los apartados de EV1 se conservan como antecedente, no como despliegue EV2 verificado.

## Responsabilidad

- Crear y consultar envíos.
- Cambiar el estado de un envío.
- Filtrar envíos por estado y fecha de creación.

## Endpoints definidos por el caso

- `POST /api/shipments`
- `GET /api/shipments/{id}`
- `PUT /api/shipments/{id}/status`
- `GET /api/shipments?status=...&from=...&to=...`
- `POST /api/users` para registrar un usuario de Cognito en la tabla `usuarios`

Los estados permitidos son `CREADO`, `ACEPTADO`, `EN_BODEGA`, `EN_RUTA`,
`ENTREGADO` y `CANCELADO`.

El registro administrativo de usuario no recibe contraseñas. Ejemplo:

```json
{
  "cognitoSub": "sub-real-de-cognito",
  "email": "usuario@ejemplo.cl",
  "rut": "12.345.678-9",
  "nombre": "Nombre",
  "apellido": "Apellido",
  "rol": "Admin"
}
```

El flujo controlado es:

`CREADO → ACEPTADO → EN_BODEGA → EN_RUTA → ENTREGADO`

Un envío puede cancelarse antes de terminar. No se permiten saltos: en particular,
un envío no puede pasar a `EN_RUTA` sin haber sido aceptado y enviado previamente a bodega.

## Ejemplo de creación

```json
{
  "codigoSeguimiento": "RX-0001",
  "nombreDestinatario": "Ana Pérez",
  "emailDestinatario": "ana@example.com",
  "direccionOrigen": "Santiago",
  "direccionDestino": "Valparaíso",
  "pesoKg": 2.50,
  "servicioId": 1
}
```

`servicioId` debe ser el ID real de un servicio con cupos creado en Catálogo; `1` es solo un ejemplo. En EV2 el cupo se descuenta al aceptar el envío, no al crearlo. El navegador envía las operaciones por el BFF, no directamente al puerto interno del microservicio.

Para cambiar el estado se envía, por ejemplo, `PUT /api/shipments/1/status`:

```json
{ "estado": "ACEPTADO" }
```

## Estado

Implementado con Spring Boot, Java 21, Spring Web, Spring Data JPA, Validation y PostgreSQL Driver.
La entidad `Shipment` se persiste en la base `shipments_db` mediante JPA.

Las reglas de negocio se prueban sin base de datos con pruebas unitarias de `ShipmentService`.

La configuración de PostgreSQL se mantiene fuera de Git. Usar
`src/main/resources/application-postgresql.properties.example` como plantilla para crear
`application-local.properties` con las credenciales locales.

## PostgreSQL y Docker para desarrollo local

La base de datos local está definida en `compose.local.yml`. Las contraseñas no se
versionan: primero copia `.env.example` como `.env` y reemplaza `SHIPMENTS_DB_PASSWORD`.

Con Docker Desktop instalado, inicia PostgreSQL y el microservicio con:

```powershell
docker compose -f compose.local.yml up --build
```

Para levantar la integración completa en contenedores, desde esta
carpeta y con los cinco repositorios ubicados como carpetas hermanas, usa
`compose.stack.yml`. Primero agrega `CATALOG_DB_PASSWORD`, `SHIPMENTS_DB_PASSWORD`,
`COGNITO_ISSUER_URI` y `COGNITO_CLIENT_ID` al `.env`. Luego ejecuta:

```powershell
docker compose -f compose.stack.yml up --build
```

Este Compose inicia PostgreSQL, Catálogo, Envíos, Reportes, BFF y frontend usando
nombres de servicio internos (`catalog-db`, `shipments-db`, `catalog`, `shipments`, `report`). Detén
primero los procesos locales que ocupen los puertos 4200, 5000, 8080, 8081 y 8082.
Los servicios Spring tienen healthchecks en `/actuator/health`, por lo que Compose
espera a que cada dependencia esté saludable antes de continuar.

Los contenedores de desarrollo usan `spring.jpa.hibernate.ddl-auto=update` para crear
las tablas desde las entidades. En un ambiente compartido o de despliegue se debe ejecutar
`database/01-create-shipments.sql` en `shipments_db` con el usuario `rutaexpress` y usar
`spring.jpa.hibernate.ddl-auto=validate`.
La tabla de usuarios alineada con Cognito está en `database/02-create-users.sql` y
se crea automáticamente en un volumen PostgreSQL nuevo. El frontend registra el
`cognito_sub` real al entrar al panel Admin, sin guardar contraseñas.

La API queda disponible en `http://localhost:5000`.

## Verificacion de salud

El endpoint `GET /actuator/health` confirma que la aplicacion esta en ejecucion.
Es el endpoint que usaremos para comprobar el servicio en Docker y posteriormente
como evidencia de despliegue en AWS:

```powershell
Invoke-RestMethod http://localhost:5000/actuator/health
```

La respuesta esperada es:

```json
{ "status": "UP" }
```

## Avance EV2: PostgreSQL y RabbitMQ

El stack nuevo, sus pruebas y comandos están en [EV2_LOCAL.md](EV2_LOCAL.md). Ejecutar `iniciar-ev2.ps1` con las seis carpetas de componentes hermanas. Usa un proyecto Compose y volúmenes separados, agrega outbox transaccional y el servicio `ms-rutaexpress-mensajeria`. `probar-ev2.ps1` produce evidencia de datos persistentes, ACK/DLQ, duplicados y recuperación. El login institucional Azure sigue pendiente de integrar con la configuración del equipo.

## Preparacion AWS EV2 (16-10-2026)

La docente confirmo Angular local, Azure para autenticacion y API Manager/Rabbit/servicio/BD en AWS (RDS para BD). El [paquete AWS](deploy/aws/README.md) contiene Compose separado sin Postgres local, JDBC con TLS verify-full, roles/bases RDS, generador LOCAL de plantilla HTTP API con JWT Azure/Cognito, comprobadores y Compose de frontend local hacia AWS. Está preparado para integración en `desarrollo`; no se ha desplegado en cloud ni se ha cambiado `main`.

Pruebas offline: `./tests/probar-aws.ps1`; agregar `-ConDocker` para validar Compose con datos ficticios sin iniciar contenedores. El SQL antiguo de EV1 descrito arriba no crea el outbox EV2; no aplicarlo como migracion de este paquete. Seguir la guia AWS, que declara ddl-auto=update como limitacion de laboratorio y preserva bases existentes.

## Gitflow y descarga de EV2

Ver [COLABORACION.md](COLABORACION.md) y [PREPARACION_EQUIPO_EV2.md](PREPARACION_EQUIPO_EV2.md). La funcionalidad se revisa mediante PR a desarrollo. CI compila Java 21 y prueba scripts/SQL aislados, sin desplegar ni usar secretos AWS/Azure. main mantiene la entrega anterior; una entrega requiere integracion y evidencia cloud real. El [alcance EV2](docs/ALCANCE_EV2.md) separa requisitos, implementacion y pendientes.

Los cuatro PR originales están en [PUBLICACION_GITFLOW_2026-10-16.md](evidencias/PUBLICACION_GITFLOW_2026-10-16.md), un registro histórico de la publicación inicial. El estado actual se comprueba en esos PR y en [la guía de continuación](CONTINUAR_EV2_EQUIPO.md). No confundir una fusión a `desarrollo` con una entrega ni con una prueba cloud.
