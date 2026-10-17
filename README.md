# ms-rutaexpress-envios

> **Estás viendo main: versión estable de EV1.** El avance de EV2 y las instrucciones actuales para descargar las seis carpetas están en [desarrollo](https://github.com/matizk/ms-rutaexpress-envios/tree/desarrollo) y en la [guía central del equipo](https://github.com/matizk/ms-rutaexpress-envios/blob/desarrollo/CONTINUAR_EV2_EQUIPO.md). Esta actualización de main solo cambia documentos; no publica la implementación EV2 ni acredita despliegue cloud.

Los componentes de dominio usan nombres en español; frontend-rutaexpress y ms-rutaexpress-bff conservan sus nombres técnicos originales. Ver [COLABORACION.md](COLABORACION.md) para el flujo `matizk → desarrollo → release → main`. Las instrucciones EV1 que siguen son antecedentes de esta versión, no la configuración del sistema EV2 con los nuevos nombres. Para ejecutar la integración actual, seguir exclusivamente la guía de desarrollo.

Microservicio de envíos de RutaExpress para la Entrega 1 de DSY1107.

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
  "pesoKg": 2.50
}
```

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
