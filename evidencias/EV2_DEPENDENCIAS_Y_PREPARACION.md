# EV2: actualización de dependencias y preparación local

Fecha de comprobación: 15-10-2026, zona America/Santiago.

## Dependencias frontend

- Antes: npm audit reportó 9 alertas (2 moderadas, 4 altas y 3 críticas), incluida Angular Router y herramientas de desarrollo.
- Después: npm audit y npm audit --omit=dev reportaron 0 alertas conocidas.
- Angular common/compiler/core/forms/platform-browser/router, compiler-cli, CLI y build: 22.2.3, misma versión mayor.
- MSAL Browser se conserva en 5.25.1. El lockfile nuevo también resuelve revisiones compatibles de dependencias existentes, entre ellas Amplify 6.22.2, TypeScript 6.0.3 y Vitest 4.1.12.
- Entorno host comprobado: Node 24.19.0, npm 11.17.0 y PowerShell 7.6.5. La imagen Docker Node 24 también instaló mediante npm ci y compiló correctamente.
- Se regeneró el lockfile en un directorio aislado porque npm intentaba conservar peers Angular 22.1.6 incompatibles con la actualización. Se guardó una copia del lockfile anterior localmente en .tools, sin borrar cambios del usuario, sin force ni legacy-peer-deps.
- SHA-256 del package-lock.json verificado: 54C3294562378010C800F8AA1A4801C25A539F008EE5FE68CD1DED2A7DBEF372.

Pasaron las 15 pruebas Angular y el build de producción. La imagen frontend se reconstruyó, nginx -t pasó y el tracking real atravesó el proxy de localhost:4200 con respuesta 200 y estado ACEPTADO.

Cero alertas conocidas en npm no equivale a una auditoría completa de seguridad de Java, Docker, red o cloud. Repetir la auditoría antes de la entrega y al cambiar dependencias.

## Arranque y configuración

- iniciar-ev2.ps1 conserva la configuración existente, verifica archivos y Docker Linux, y espera health UP antes de anunciar que el stack está listo.
- comprobar-ev2.ps1 revisa las seis carpetas, configuración, secretos de plantilla, coherencia Azure, callback y destino API. ExigirAzure no acepta Azure deshabilitado.
- diagnosticar-ev2.ps1 muestra estado de los contenedores y salud sin imprimir valores secretos, tokens, destinatarios ni logs de aplicaciones.
- configurar-api.ps1 permite elegir la API HTTPS oficial del equipo o volver al BFF local, conservando otras variables y contraseñas.
- Nginx usa una plantilla, mantiene ruta/query y stage del destino, valida TLS con SNI y rechaza configuración insegura antes de iniciar. No se configuró ni contactó una API cloud en esta revisión.
- .env y .env.* se excluyeron además del contexto de construcción Docker.

Pruebas nuevas ejecutadas: 43 de configuración en archivos ficticios y 12 del validador de proxy en contenedores efímeros sin red. Esos archivos/contenedores de prueba se limpian sin eliminar datos del proyecto. Se comprobó el arranque idempotente con SinConstruir.

Windows PowerShell 5.1 bloqueó ejecutar scripts por su política local. No se alteró ni eludió esa política; no se afirma una ejecución de esas pruebas bajo 5.1.

## Integración local repetida

probar-ev2.ps1 -SinReinicios pasó con PostgreSQL y RabbitMQ reales: creación, aceptación, consumidores, idempotencia, tres DLQ, tracking y rechazo de tokens ausentes/inválidos. Código ficticio de la pasada: RX-EV2-20261015194347848. El informe generado está en EV2_PRUEBA_LOCAL.md.

El diagnóstico posterior mostró los once contenedores activos, frontend y cinco backends con health UP. No se reiniciaron las bases ni RabbitMQ en esta pasada. La prueba anterior de recuperación/persistencia se conserva como antecedente, no se vuelve a afirmar como ejecutada aquí.

## Documentación lista

- PREPARACION_EQUIPO_EV2.md: requisitos, carpetas, arranque, Azure, conexión API, diagnóstico y problemas habituales.
- DEMOSTRACION_Y_EVIDENCIAS_EV2.md: guion de ocho minutos, evidencias y mapa del código.
- Frontend README, AZURE_OPERADOR.md y EV2_LOCAL.md actualizados.

Siguen pendientes login Duoc real, consentimiento Azure, gateway y EC2/RDS/RabbitMQ cloud del equipo. El frontend puede permanecer local en EV2. Cambios locales: no se hizo commit/push ni se modificaron cuentas AWS/Azure.

Referencias primarias: [aviso de Angular Router](https://github.com/angular/angular/security/advisories/GHSA-ff3f-86qr-9cv3), [compatibilidad Angular](https://angular.dev/reference/versions), [proxy y validación TLS en Nginx](https://nginx.org/en/docs/http/ngx_http_proxy_module.html), [plantillas de la imagen oficial Nginx](https://hub.docker.com/_/nginx).
