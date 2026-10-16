# Preparacion AWS EV2 - evidencia local del 16-10-2026

## Alcance y fuentes

Se prepararon archivos locales a partir de la confirmacion escrita de la docente: Angular local, Azure autentica, servicio/Rabbit/BD/API Manager en AWS, base mediante RDS. Las capturas y sus hashes estan en el inventario de materiales; analisis en `revision-materiales/ACLARACION_AWS_2026-10-16.md` de la carpeta general EV2.

No hubo llamadas a cuentas AWS/Azure ni despliegue. No se configuraron IDs reales, credenciales RDS, API Gateway real o consentimiento Duoc. No hubo commit/push y Mensajeria sigue sin remoto propio. No se genero `.env.aws`, `api-config.json` ni plan para un destino real. El frontend y los backends de aplicacion no se iniciaron en esta pasada.

## Archivos entregables

- `deploy/aws/compose.aws.yml`: cinco backends + dos nodos RabbitMQ, Angular fuera de EC2, RDS con tres bases/propietarios y JDBC TLS verify-full; solo BFF con bind privado/loopback y management Rabbit loopback.
- `deploy/aws/compose.frontend-cloud.yml`: solo Angular/Nginx en PC hacia API Gateway HTTPS, sin backends locales necesarios.
- `.env.aws.example`, `api-config.json.example`, `scripts/Aws.Deployment.psm1`, generador CloudFormation LOCAL y comprobador de configuracion. Registros/roles Azure no se inventan.
- SQL de creacion no destructiva de roles/bases y verificacion solo lectura de TLS/tablas/conteos.
- `probar-api-aws.ps1`: GETs por HTTPS execute-api, sin redirecciones ni salida de cuerpos/tokens; prueba positiva requiere access token institucional real mediante entrada oculta. No se ejecuto contra un destino real.
- `comprobar-servicios.sh`: consultas internas de salud sin publicar puertos; se comprobo sintaxis externa e interna, no salud de EC2 real.
- Guia de red, costos, RDS, rutas/JWT, Angular local, pruebas y limites. Se actualizaron READMEs/plan/evidencias y se resolvio la duda anterior de proveedor del API Manager.
- Git ignora configuracion privada/certificados/planes generados; Docker excluye tambien secretos anidados y claves; shell/SQL/YAML usan LF para Linux.

## Pruebas ejecutadas

| Prueba | Resultado |
| --- | --- |
| `tests/probar-aws.ps1 -ConDocker` | **74 correctas**: entrada/JWT/rutas, publicas limitadas, scopes, audience API, CORS exacto, rutas sin stage, modos de red, URL destino, errores sin secretos, Compose AWS + frontend local. Renderiza con valores ficticios, no levanta el backend. |
| `tests/probar-aws-archivos.ps1` | **10 correctas**: scripts reales en carpetas temporales, generacion/validacion, no sobreescritura, no secreto impreso, rechazo de destino de token no AWS, env/CA ausentes o corruptos, CA publica aceptada sin pedir clave privada y override heredado rechazado. |
| `tests/probar-aws-sql.ps1` | **6 correctas** contra PostgreSQL 16 efimero: no crear sin claves, roles/propietarios, idempotencia sin rotar passwords ni perder datos, DDL del propietario, SQL de verificacion y rechazo de lectura entre usuarios. |
| Regresion `tests/probar-configuracion.ps1` | **43 correctas**, sin modificar archivos reales/servicios. El sandbox bloqueo un rename del fixture; pasada final fuera de esa restriccion correcta. |
| Regresion `tests/probar-proxy.ps1` | **12 correctas**, contenedores sin red; no contacto con dominios externos. |
| CloudFormation, modos privado y HTTPS publico | **cfn-lint 1.57.2: exit 0**, dos plantillas ficticias, sin AWS. |
| PowerShell y Bash | Sintaxis valida en scripts/modulos PowerShell; `bash -n` del wrapper y de su payload interno en imagen BFF existente, sin red. |
| Revision Git | `git diff --check` correcto; archivos privados ignorados y plantillas .example no ignoradas. |

Total de esta pasada: **145 casos correctos (90 nuevos + 55 de regresion)**, ademas del lint de dos plantillas y analisis de sintaxis. No se repitieron las suites Java/Angular porque no se modifico su codigo en esta tarea; sus resultados anteriores permanecen historicos, no se suman como nuevas ejecuciones.

Docker Desktop estaba detenido; se inicio para las pruebas. Los contenedores PostgreSQL y validadores temporales se detuvieron/eliminaron al terminar, sin tocar volumenes existentes. Solo se descartaron datos ficticios de esos fixtures, que se regeneran con sus scripts. No se encendio el stack completo de la aplicacion.

### Identificadores de fixtures de lint (no infraestructura real)

- Plantilla privada SHA256: `E9F70B4CAE6EBB45CF6BD6EB191D12477A0D162D90ABDFC30677289AD485F995`.
- Plantilla HTTPS publica SHA256: `5F9EFE919DE0D7FCC553B29F9AA6E29DBAE762406237342E27B3D7C3B7D669BA`.

Herramienta cfn-lint instalada solo en `.tools/aws-lint`, ignorada por Git; runtime local PowerShell 7.6.5. No se certifica ejecucion en Windows PowerShell 5.1 ni se modifico su politica de ejecucion.

## Limites importantes

Los tests SQL usan acceso local del contenedor aislado: **no prueban autenticacion RDS, TLS remoto, CA de AWS ni red VPC**. El validador PEM comprueba formato, no que un certificado pertenezca a AWS. El bundle real debe obtenerse del truststore oficial y JDBC verify-full debe completar una conexion real.

CloudFormation lint comprueba estructura/esquema, no existencia del ALB/VPC Link, permisos Academy, costo ni disponibilidad de servicios. El modo privado propone reutilizar recursos autorizados; ALB puede tener costo y restricciones. La alternativa publica exige HTTPS/DNS/certificado valido ya preparado, no rebajar a HTTP publico.

El API Manager nativo comprueba issuer/audience/scopes; el BFF conserva la comprobacion de access token y de Admin Cognito, y en Azure tenant/azp/oid/scope/exp. En cloud las rutas operador usan Azure; una sesion Cognito solo sirve para las APIs administrativas, no para acreditar la identidad institucional.

## Lo que falta para cerrar EV2

1. Publicar/coordinar los repositorios y commits correctos cuando el alumno lo autorice; no asumir que ya esta en main.
2. Obtener IDs reales Azure y consentimiento/callback/API v2; probar login Duoc.
3. Responsable AWS: revisar recursos existentes, costos/permisos y red; configurar RDS/usuarios/certificado, desplegar backends/Rabbit y API Gateway con sus authorizers.
4. Conectar Angular local a la URL real y probar recorrido completo, JWT ausente/invalido/valido, permisos, colas/DLQ, ticket y persistencia RDS; guardar evidencia cloud real sin secretos.

Guia operativa: [paquete AWS](../deploy/aws/README.md).
