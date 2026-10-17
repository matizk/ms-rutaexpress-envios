# AWS EV2: paquete preparado, NO desplegado

Confirmacion escrita de la docente recibida el 16-10-2026: **Angular local, Azure para autenticacion, RabbitMQ/BD/servicio en AWS y API Manager en AWS; BD mediante RDS**. Resumen publicable en [alcance EV2](../../docs/ALCANCE_EV2.md); los originales de clase se conservan fuera de los repositorios publicos. El frontend cloud se exige en la entrega 3, no ahora.

## Arquitectura que propone este paquete

```text
Angular LOCAL :4200 -- login PKCE --> Microsoft Entra/Azure (cuenta Duoc)
       |
       +-- /api via proxy HTTPS --> AWS API Gateway HTTP API
                                      | JWT Azure: /api/operator/...
                                      | JWT Cognito: administracion anterior
                                      | publico: health y tracking limitado
                                      v
                                BFF en EC2
                                  |-- Catalogo ----- RDS catalog_db (rx_catalog)
                                  |-- Envios ------- RDS shipments_db (rx_shipments)
                                  |       | outbox
                                  |       v
                                  |   RabbitMQ x2 --> Mensajeria/tickets
                                  |                      | RDS messaging_db (rx_messaging)
                                  +-- Reportes <--------- Envios
```

La propuesta coloca los cinco backends en una EC2 para evitar repartir llamadas internas entre el PC y la nube. Es una decision de integracion, **no** una afirmacion de que la profesora exija subir todos. Una instancia RDS PostgreSQL puede alojar las tres bases logicas con propietarios distintos. Si el equipo ya tiene un despliegue valido, adaptar sus valores y NO duplicarlo a ciegas.

Dos procesos Rabbit en una EC2 NO constituyen tolerancia a la caida de esa EC2; las colas classic de este ejercicio tampoco replican automaticamente sus mensajes. No vender esta arquitectura como alta disponibilidad.

## Limites y costos: leer antes

Estos archivos no crean EC2, RDS, tenant, usuarios Azure, ALB ni VPC Link. No se ha ejecutado `aws ... deploy`, no se han usado credenciales cloud y los identificadores reales siguen pendientes. El plan de CloudFormation genera **una API HTTP nueva y un grupo de logs**; no modifica automaticamente la API de EV1. Revisar si conviene configurar la API existente manualmente con las mismas rutas.

EC2, RDS, almacenamiento/backups, trafico, API Gateway, logs y, si se elige, ALB pueden consumir saldo; detener una instancia no elimina todos los cargos. Verificar credito/permisos con el responsable de la cuenta. No crear balanceadores ni infraestructura nueva sin su aprobacion. Este paquete no contiene comandos automaticos de provisionamiento o eliminacion cloud.

## 1. Coordinar y obtener valores reales

- Repositorios: cinco backends y frontend como carpetas hermanas, en la versión de integración **desarrollo** tras comprobar la fusión de los PR EV2; no en main. Mensajeria: https://github.com/matizk/ms-rutaexpress-mensajeria. Seguir [descarga EV2](../../PREPARACION_EQUIPO_EV2.md) para clonar las ramas coordinadas. No copiar `.env` al repositorio ni desplegar por el solo hecho de integrar un PR.
- Azure: tenant ID, SPA client ID, API client ID (tres UUID publicos), permiso delegado `operator.access`, API con access tokens v2, consentimiento y callback SPA `http://localhost:4200/auth/azure`. Seguir `frontend-rutaexpress/docs/AZURE_OPERADOR.md`. No usar tokens Graph ni ID tokens, ni pedir que envien tokens/contrasenas por chat.
- AWS: region/cuenta autorizada, EC2 Linux con Docker/Compose v2, capacidad de memoria revisada (limites de estos siete contenedores suman unos 4 GiB, mas SO y construccion Maven), endpoint RDS PostgreSQL, bases/usuarios y ruta de ingreso al BFF. No prometer que cabe o compila en una micro gratuita.
- Cognito anterior: issuer y client ID publicos. Se conserva solo para administracion anterior; no reemplaza Azure en la evaluacion.

## 2. Red de AWS antes de iniciar

RDS **privado**, accesible en 5432 solo desde el security group de EC2; sin regla `0.0.0.0/0`. EC2 necesita salida para RDS, repositorios de imagenes y JWKS de Microsoft/Cognito. SSH solo desde la IP autorizada o SSM segun permisos.

No publicar 5000, 8081, 8082, 8084, 5432, 5672, 15672/15673, 25672 ni 4369 a internet. Los microservicios usan la red Docker. Rabbit Management solo esta enlazado a loopback; para verlo usar tunel SSH autorizado, por ejemplo `ssh -N -L 15672:127.0.0.1:15672 USUARIO@HOST_EC2` (no pegar los marcadores literalmente).

Elegir **una** integracion de API Gateway:

1. `PRIVATE_ALB`: reutilizar ALB interno y VPC Link autorizados, misma cuenta/region; listener HTTP hacia target EC2:8080, health check `/actuator/health`. Poner en `.env.aws` `BFF_BIND_ADDRESS` igual a la **IPv4 privada** de EC2. SG EC2:8080 solo desde SG ALB; SG ALB solo desde SG VPC Link. No abrir 8080 a todo internet. Es trafico HTTP dentro de VPC; API publica y RDS usan TLS. Crear ALB tiene costo y puede no estar permitido en Academy: no hacerlo sin revisar.
2. `PUBLIC_HTTPS`: si YA existe un ingreso HTTPS con DNS/certificado valido hacia el BFF (proxy inverso administrado por el equipo), usar su origen sin ruta; BFF puede seguir en loopback y el proxy local lo alcanza. No crear un endpoint HTTP publico ni desactivar certificados para evitar ALB. El BFF sigue validando todos los JWT aunque alguien llegue directamente al origen. No reenviar a microservicios sin BFF. Si no existe HTTPS ni se permite VPC Link/ALB, detener la decision de red y coordinar permisos; no rebajar seguridad.

## 3. RDS y secretos (en la EC2 autorizada)

Desde `ms-rutaexpress-envios/deploy/aws`, copiar `.env.aws.example` a `.env.aws`. Completar endpoint e IDs. Generar cinco secretos distintos con `openssl rand -hex 24`; escribirlos SOLO en el archivo privado con permisos `chmod 600 .env.aws`. La validacion admite un subconjunto seguro alfanumerico, `_` y `-`; no usar `$`, espacios ni claves de ejemplo. No ejecutar `docker compose config` sin `--quiet`: imprime secretos.

Obtener el bundle de certificados publico de RDS desde el enlace oficial y guardarlo en `certs/global-bundle.pem`:

```bash
curl --fail --show-error --location --proto '=https' --tlsv1.2 \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  --output certs/global-bundle.pem
```

No es una clave privada. JDBC usa `sslmode=verify-full`: verifica CA y nombre DNS. No sustituir por `sslmode=require`, `trust`, IP, `NonValidatingFactory` ni desactivar TLS.

Con cliente `psql` 16+ en EC2, iniciar una shell dedicada y cargar SOLO el `.env.aws` que acabas de crear/revisar; no hacer `source` de archivos descargados de terceros. Exportar temporalmente variables para psql:

```bash
set -a
. ./.env.aws
set +a
export PGHOST="$RDS_HOST" PGPORT=5432 PGDATABASE=postgres
export PGUSER=USUARIO_ADMIN_RDS_REAL PGSSLMODE=verify-full
export PGSSLROOTCERT="$PWD/certs/global-bundle.pem"
psql -X -W -f crear-bases.sql
```

Reemplazar `USUARIO_ADMIN_RDS_REAL`; `-W` pide la clave maestra sin ponerla en el comando. El SQL crea roles `rx_catalog`, `rx_shipments`, `rx_messaging` y bases con esos propietarios solo si no existen. No altera claves/propietarios existentes. Si ya existen, verificar coincidencia; no borrarlos ni rotar claves sin coordinar. Cerrar esta shell al terminar para quitar secretos exportados. **Nunca usar el usuario maestro en las aplicaciones.**

Hibernate crea/actualiza tablas al arrancar (`ddl-auto=update`, limitacion de este ejercicio). No ejecutar los SQL de PostgreSQL local ni copiar volumenes sobre RDS; no hay migracion automatica de datos existentes. Una BD cloud nueva tendra catalogo/envios vacios: registrar un servicio con cupos desde Catalogo antes de crear el envio.

## 4. Validar y arrancar backend

Con PowerShell 7.2+ (probado en 7.6), el responsable puede ejecutar `./comprobar-aws.ps1` para revisar archivos sin iniciar nada. `-SinDocker` omite solo la comprobacion del motor. No prueba credenciales ni conectividad RDS.

En Linux, desde esta carpeta, despues de revisar `.env.aws`, CA, seguridad y capacidad:

```bash
docker compose -p rutaexpress-ev2-aws --env-file .env.aws -f compose.aws.yml config --quiet
docker compose -p rutaexpress-ev2-aws --env-file .env.aws -f compose.aws.yml up -d --build
docker compose -p rutaexpress-ev2-aws --env-file .env.aws -f compose.aws.yml ps
docker compose -p rutaexpress-ev2-aws --env-file .env.aws -f compose.aws.yml exec -T rabbitmq-1 rabbitmqctl cluster_status
curl --fail http://127.0.0.1:8080/actuator/health
bash comprobar-servicios.sh
```

Si BFF esta enlazado a IPv4 privada para ALB, consultar esa IP en el comando curl. `comprobar-servicios.sh` usa un contenedor efimero basado en la imagen BFF ya construida para consultar salud por la red Docker, sin publicar puertos internos ni mostrar cuerpos. Requiere bash/coreutils de la imagen Temurin. Esperar salud real de las cinco APIs; `running` no garantiza arranque JPA ni conexion RDS. Si faltan tablas o falla TLS, revisar logs localmente sin reenviarlos completos: pueden incluir datos/URLs. No mostrar `docker inspect`/env en evidencias. Para detener contenedores de ESTE stack: `docker compose -p rutaexpress-ev2-aws --env-file .env.aws -f compose.aws.yml stop`. **No usar `down -v`.** Los volumenes AWS son distintos de los locales. Rabbit conserva su usuario/password inicial en el volumen: cambiar RABBITMQ_DEFAULT_PASS no rota la clave de un broker existente. No regenerar la cookie ni claves de un stack en uso sin coordinar.

Usar shell limpia: Compose da prioridad a variables exportadas sobre `--env-file`. No exportar overrides de RDS/Azure/secretos antes de iniciar. El comprobador PowerShell rechaza diferencias; el `-p` explicito evita que `COMPOSE_PROJECT_NAME` mezcle este stack con el local.

## 5. API Gateway AWS, sin inventar IDs

Este paquete usa **HTTP API** con JWT authorizers nativos; una REST API antigua no acepta esta plantilla sin adaptar el mecanismo. No borrar ni reemplazar la API existente para cambiar de tipo. Reutilizarla manualmente si el equipo valida su authorizer.

Copiar `api-config.json.example` a `api-config.json`, completar IDs publicos coherentes con `.env.aws` y Angular; elegir modo y destino de red. `spaClientId` se valida en el plan y lo comprueba el backend con `azp`; el authorizer nativo solo tiene issuer/audience/scopes. No poner client secret, password ni tokens en el JSON.

```powershell
./crear-plan-api.ps1
./crear-plan-api.ps1 -Generar
```

Solo el segundo guarda `apigateway.generated.json`, sin conectar a AWS. No sobrescribe un plan existente. Revisar la plantilla antes de importarla/crear el stack manualmente con permisos. Tiene stage `$default`, limites basicos de trafico, logs de 7 dias sin cuerpos/tokens y rutas explicitas:

| Rutas | Authorizer/scopes | Verificacion adicional del BFF |
| --- | --- | --- |
| GET/POST permitidos de `/api/operator/...` | Azure tenant v2, audience UUID API, `operator.access` | firma, tid, aud, azp SPA, oid, scp, exp; solo operador |
| Catalogo, envios administrativos, reportes, receipts y Rabbit Admin | Cognito existente, app client, `openid` | access token y grupo Admin |
| GET `/api/shipments/track/{trackingCode}` | NONE, publico deliberadamente | respuesta limitada sin destinatario/correo |
| GET `/actuator/health` | NONE | sin detalles privados |

No hay `$default` route ni `ANY /{proxy+}` sin autorizacion. CORS exacto `http://localhost:4200`; preflight lo atiende HTTP API. `overwrite:path=$request.path` evita enviar el stage al backend. Conservar `Authorization` original: no mapearlo a mano ni sustituirlo por ID token. El scope Cognito `openid` presupone el flujo OAuth ya utilizado; comprobarlo sin quitar scopes para que pase un ID token. En CLOUD la bandeja operador requiere Azure; la opcion de revision Cognito de esa pantalla es solo para pruebas locales.

## 6. Conectar Angular LOCAL y comprobar

En el PC con los seis repositorios, aplicar los mismos IDs con `configurar-azure.ps1` segun la guia Azure. Desde `ms-rutaexpress-envios`:

```powershell
./configurar-api.ps1 -UrlApi 'https://ID-REAL.execute-api.REGION-REAL.amazonaws.com'
# Si el frontend del stack local ocupa 4200, detener SOLO ese componente:
docker compose --env-file .env.ev2 -f compose.ev2.yml stop frontend
# Este Compose levanta unicamente Angular/Nginx LOCAL hacia la API de AWS:
docker compose -p rutaexpress-ev2-frontend-cloud --env-file .env.ev2 -f deploy/aws/compose.frontend-cloud.yml up -d --build
```

Reemplazar la URL por la salida REAL de API Gateway, sin slash final (stage opcional si no es `$default`). Este proxy local envia `/api` al gateway HTTPS, no a `localhost:8080`. No requiere iniciar los backends locales; los que ya estuvieran activos no se detienen automaticamente. Cambiar solo la URL no demuestra que la ruta remota este funcionando. No publicar Angular para esta entrega. Para volver al modo local, detener solo el frontend-cloud con su Compose (sin `-v`), ejecutar `configurar-api.ps1 -Local` e `iniciar-ev2.ps1`.

Pruebas HTTP de solo lectura, sin pegar tokens en argumentos/historial:

```powershell
./deploy/aws/probar-api-aws.ps1 -UrlApi 'https://ID-REAL.execute-api.REGION-REAL.amazonaws.com'
./deploy/aws/probar-api-aws.ps1 -UrlApi 'https://ID-REAL.execute-api.REGION-REAL.amazonaws.com' -ConOperador
```

El probe pide el access token en entrada oculta solo con `-ConOperador`; lo envia exclusivamente al dominio execute-api HTTPS validado, sin seguir redirecciones ni mostrar cuerpos/tokens. No exportar credenciales del navegador por automatizacion ni enviar ese token al chat. En la demostracion normal usar Angular; el probe es opcional para evidencia HTTP. Si las politicas de la institucion no permiten copiar tokens, usar DevTools localmente sin capturarlos.

Recorrido manual obligatorio: login Cognito Admin -> crear servicio con cupos -> crear envio CREADO -> login institucional Azure en `/operador` -> aceptar -> esperar ticket real ACEPTADO -> descargar ticket -> tracking publico. Revisar reportes con Admin y Rabbit/topologia por tunel o API autorizada. El ticket NO acredita entrega; notificaciones son registros internos, no correos externos.

Ejecutar `verificar-rds.sql` en cada base con su usuario: debe verse `ssl=true`, TLS y tablas/conteos. Reiniciar SOLO el contenedor de aplicacion autorizado y verificar persistencia del envio/ticket. Preparar evidencia de API Gateway rechazando JWT ausente/invalido y admitiendo el valido; dos nodos; tres colas y tres DLQ; direct/topic; mensaje invalido hacia DLQ y logs sin datos personales. No ejecutar la prueba local `probar-ev2.ps1` contra produccion: esta disena datos/reinicios del stack LOCAL.

## Fuentes tecnicas oficiales

- [JWT authorizers HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html)
- [Integracion privada, ALB y VPC Link](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-desarrollo-integrations-private.html)
- [Mapeo de rutas y headers reservados](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-parameter-mapping.html)
- [TLS y certificados de RDS PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html)

Estas referencias sustentan el diseno. Las pruebas de archivos locales NO certifican que AWS, Azure, RDS, DNS o permisos del equipo esten listos.

## Pruebas del paquete (sin cuenta AWS)

Desde la raiz del repositorio Envio, PowerShell 7.2+:

```powershell
./tests/probar-aws.ps1 -ConDocker
./tests/probar-aws-archivos.ps1
./tests/probar-aws-sql.ps1
```

La primera valida reglas/plantillas y renderiza Compose con valores ficticios; no inicia backend. La segunda usa archivos efimeros, comprueba rechazo/aceptacion y no sobrescritura del generador. La tercera usa `postgres:16-alpine` ya descargado, sin puertos ni red, prueba creacion/idempotencia/permisos SQL y elimina SOLO ese contenedor temporal. No prueba RDS/TLS real. Evidencia y limites en `../../evidencias/EV2_PAQUETE_AWS_2026-10-16.md`.
