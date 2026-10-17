# Preparación del equipo: ejecutar e integrar EV2

Esta guía prepara el trabajo local; no certifica Azure ni AWS. Angular puede ejecutarse localmente en EV2 según la respuesta escrita de la profesora. No se exige publicar el frontend en esta entrega.

## 1. Qué instalar

- Git, si se van a clonar y actualizar los repositorios.
- Docker Desktop con motor de contenedores Linux. Abrirlo y esperar que esté listo.
- PowerShell autorizado para ejecutar los scripts del proyecto; las pruebas de los scripts se realizaron con PowerShell 7.6.
- Navegador para entrar con Cognito y posteriormente con la cuenta Duoc mediante Azure.

No hace falta instalar PostgreSQL, RabbitMQ, Java, Maven ni Node en Windows para ejecutar el stack: están en los contenedores. Para desarrollar o correr pruebas fuera de Docker se probó Node 24.19/npm 11 y un JDK 21 o superior, con el wrapper Maven de cada repositorio.

Si Windows bloquea scripts por política de ejecución, no cambiar políticas globales ni desactivar protecciones. Usar el entorno autorizado del equipo o solicitar ayuda a TI. Windows PowerShell 5.1 bloqueó la ejecución en este PC, por lo que no se afirma que los tests se ejecutaran allí.

## 2. Descargar todo en carpetas hermanas

El equipo usa un flujo inspirado en Gitflow con ramas personales: `matizk` es la rama de trabajo de esta copia y `desarrollo` reúne la integración por PR. Los otros integrantes trabajan en sus propias ramas. `main` conserva la entrega anterior (en Mensajería, solo la base inicial). Desde el 17-10-2026, la antigua rama develop se llama desarrollo; los PR y commits anteriores conservan su historia. Clonar las seis carpetas de componentes en el mismo directorio, conservando estos nombres:

~~~text
carpeta-del-equipo/
  interfaz-rutaexpress/
  ms-rutaexpress-intermediario/
  ms-rutaexpress-catalogo/
  ms-rutaexpress-envios/
  ms-rutaexpress-mensajeria/
  ms-rutaexpress-reportes/
~~~

No mezclar el Compose EV2 con el de EV1 ni poner una carpeta dentro de otra. Este cambio de organización no modifica funciones de Catálogo ni Reportes. Los comandos siguientes descargan la versión de integración para ejecutar el sistema; no son una indicación de que todos deban hacer commits en la rama personal matizk. Usar un directorio nuevo y vacío:

~~~powershell
git clone -b desarrollo https://github.com/matizk/interfaz-rutaexpress.git
git clone -b desarrollo https://github.com/matizk/ms-rutaexpress-intermediario.git
git clone -b desarrollo https://github.com/matizk/ms-rutaexpress-catalogo.git
git clone -b desarrollo https://github.com/matizk/ms-rutaexpress-envios.git
git clone -b desarrollo https://github.com/matizk/ms-rutaexpress-mensajeria.git
git clone -b desarrollo https://github.com/matizk/ms-rutaexpress-reportes.git
~~~

Si ya tienen copias con trabajo propio, NO volver a clonar encima ni resetear: revisar git status/fetch y coordinar la base. Ver [COLABORACION.md](COLABORACION.md). No se ha hecho una entrega ni se debe desplegar automáticamente por publicar código. Las referencias antiguas totalmente integradas se retiran, pero sus commits y PR se conservan como historial.

### Si ya descargaron la antigua rama develop

Ejecutar dentro de CADA repositorio, después de conservar cualquier trabajo propio:

~~~powershell
git status
git fetch origin --prune
~~~

Si no aparece origin/desarrollo porque clonaron una sola rama, ejecutar `git remote set-branches --add origin desarrollo` y `git fetch origin` antes de seguir.

- Si existe una rama local develop y NO existe desarrollo: `git branch -m develop desarrollo`.
- Si nunca tuvieron esa rama local: `git switch --track origin/desarrollo` la crea. Si desarrollo ya existe, usar `git switch desarrollo`.
- Después: `git switch desarrollo`, `git branch --set-upstream-to=origin/desarrollo desarrollo` y `git merge --ff-only origin/desarrollo`.
- Si Git indica cambios pendientes o divergencia, detenerse y conservarlos; no forzar ni borrar la copia. Coordinar el merge normal.

En el PC de Matizk se continúa con `git switch matizk`, actualizando primero desde origin/desarrollo como indica COLABORACION.md. Los compañeros usan SUS ramas para modificar código y PR hacia desarrollo. Para revisar una instalación sin desarrollar basta permanecer en desarrollo.

### Si sus carpetas o enlaces aún tienen los nombres anteriores

Los seis repositorios se renombraron el 17-10-2026 conservando historial y colaboradores. No necesitan descargar todo otra vez si ya tienen una copia; primero guardar su trabajo y detener sus procesos locales.

| Nombre anterior | Nombre vigente de repositorio y carpeta |
| --- | --- |
| interfaz-rutaexpress | interfaz-rutaexpress |
| ms-rutaexpress-intermediario | ms-rutaexpress-intermediario |
| ms-rutaexpress-catalogo | ms-rutaexpress-catalogo |
| ms-rutaexpress-envios | ms-rutaexpress-envios |
| ms-rutaexpress-mensajeria | ms-rutaexpress-mensajeria |
| ms-rutaexpress-reportes | ms-rutaexpress-reportes |

Desde la carpeta que contiene las seis copias, renombrar cada carpeta según la tabla, sin combinarla con otra que ya exista. Por ejemplo: `Rename-Item -LiteralPath './interfaz-rutaexpress' -NewName 'interfaz-rutaexpress'`. Después, dentro de CADA repositorio, ejecutar `git remote set-url origin https://github.com/matizk/NOMBRE-VIGENTE.git`, sustituyendo NOMBRE-VIGENTE por su nombre de la tabla; revisar `git remote -v`, ejecutar `git fetch origin --prune` y actualizar su rama sin forzar. Si hay divergencia, coordinar antes de fusionar.

Mantener las seis carpetas como hermanas: Compose y los scripts ya usan estos nombres. Los enlaces web anteriores redirigen, pero los comandos nuevos utilizan los nombres vigentes. No cambiar nombres internos de contenedores, bases, volúmenes ni rutas de API; esos identificadores conservan compatibilidad con los datos existentes.

No subir .env.ev2, contraseñas, tokens, credenciales AWS, node_modules ni los modelos de transcripción. Cada computador genera sus propias contraseñas locales.

## 3. Primer arranque local

Abrir PowerShell en ms-rutaexpress-envios:

~~~powershell
.\iniciar-ev2.ps1 -SoloConfigurar
.\comprobar-ev2.ps1 -SoloArchivos
.\iniciar-ev2.ps1
~~~

La primera ejecución necesita internet para imágenes y dependencias. El script no sobrescribe .env.ev2 si ya existe, comprueba los archivos y Docker Linux, y espera health UP en frontend y cinco backends antes de indicar que está listo.

Abrir http://localhost:4200. Administración está en /admin; la bandeja del operador está en /operador. Hasta configurar Azure, el acceso institucional aparece pendiente; se puede revisar la funcionalidad con una sesión Cognito Admin válida, identificada como tal.

Si las imágenes ya están construidas:

~~~powershell
.\iniciar-ev2.ps1 -SinConstruir
.\comprobar-ev2.ps1 -EnEjecucion
.\diagnosticar-ev2.ps1 -GuardarInforme
~~~

El diagnóstico es de lectura y muestra estados, no contraseñas, tokens ni datos de destinatarios. El informe está en evidencias/EV2_DIAGNOSTICO_LOCAL.md. Antes de enviarlo, revisarlo igualmente.

## 4. Qué pedir a quien configura Azure

- Tenant ID institucional.
- Client ID de la aplicación frontend SPA.
- Client ID de la aplicación API.
- Nombre del scope delegado, actualmente operator.access.
- Confirmación del consentimiento/permisos, token API v2 y callback SPA http://localhost:4200/auth/azure.

Son identificadores/configuración, no contraseñas ni client secrets. La guía detallada está en interfaz-rutaexpress/docs/AZURE_OPERADOR.md. Configurar desde Envíos con los valores reales:

~~~powershell
.\configurar-azure.ps1 -TenantId 'UUID-TENANT-REAL' -FrontendClientId 'UUID-SPA-REAL' -ApiClientId 'UUID-API-REAL'
.\comprobar-ev2.ps1 -SoloArchivos -ExigirAzure
.\iniciar-ev2.ps1
~~~

Reemplazar los marcadores UUID por los valores del tenant; no ejecutar literalmente esos textos. El script alinea ambos archivos y conserva las contraseñas. ExigirAzure comprueba coherencia local, no que el consentimiento ni el login de Microsoft funcionen.

## 5. Conectar Angular local con la API del equipo

El destino predeterminado es el BFF local. Cuando el equipo entregue su URL oficial HTTPS de API Gateway/API Manager, se puede cambiar el destino sin editar Angular:

~~~powershell
.\configurar-api.ps1 -UrlApi 'https://URL-REAL-DEL-EQUIPO/STAGE-SI-CORRESPONDE'
.\iniciar-ev2.ps1 -SinConstruir
~~~

Reemplazar el ejemplo por la URL exacta. Si la API usa stage, incluirlo; no añadir una ruta concreta como /api/shipments ni credenciales, parámetros o fragmentos. El script guarda FRONTEND_API_UPSTREAM en .env.ev2 y Nginx recreado la aplica.

Solo usar una URL del equipo verificada: allí se reenviarán las solicitudes y sus bearer tokens. El proxy exige HTTPS para destinos externos, valida el certificado y conserva la ruta /api y sus parámetros. No desactivar la validación TLS para evitar errores.

Para volver al stack local:

~~~powershell
.\configurar-api.ps1 -Local
.\iniciar-ev2.ps1 -SinConstruir
~~~

El navegador sigue en localhost:4200 y su callback Azure no cambia. El destino remoto y la configuración institucional deben concordar en scopes, audiencia y emisor. El proxy configurable no demuestra que el gateway remoto ya esté correcto.

## 6. Qué comprobar en AWS y el gateway

- Confirmacion docente del 16-10-2026: API Manager en AWS, Rabbit/servicio en AWS y BD mediante RDS; Azure solo autentica y Angular queda local. El paquete y paso a paso están publicados en [deploy/aws/README.md](deploy/aws/README.md); la publicación del código NO certifica despliegue real. Incluye Compose solo de Angular local para no depender de backends locales al mostrar AWS.
- Confirmar qué servicio de solicitud/respuesta está en EC2 y conectado realmente a RabbitMQ y PostgreSQL/RDS. Las indicaciones de clase piden al menos uno; no asumir que todos estén publicados por ver una captura del frontend.
- Verificar dos nodos RabbitMQ, tres colas y tres DLQ, exchanges direct/topic y el Compose ejecutándose en cloud.
- El gateway debe enrutar /api/operator/shipments y /api/operator/confirmations a los servicios correspondientes y aceptar sus access tokens Azure. Las rutas administrativas conservan Cognito/Admin.
- Mantener tracking público según el diseño existente; no aplicar un authorizer global que lo bloquee por accidente.
- No publicar directamente PostgreSQL, los microservicios internos ni Rabbit Management en internet. Usar gateway/BFF y una red adecuada.
- Probar rechazo sin token o con token inválido y acceso con el token válido del proveedor correspondiente. No basta con revisar una lista de rutas.

Ninguno de esos pasos se ejecuta automáticamente en la cuenta cloud desde estos scripts.

## 7. Pruebas y diagnóstico

~~~powershell
.\tests\probar-configuracion.ps1
.\tests\probar-proxy.ps1
.\probar-ev2.ps1 -SinReinicios
~~~

La primera usa archivos temporales ficticios y no Docker. La segunda necesita la imagen frontend ya construida; solo valida destinos ficticios en contenedores efímeros sin red. La tercera crea datos ficticios y mensajes inválidos en el stack local real: no equivale a login Azure ni a prueba cloud.

Ejecutar probar-ev2.ps1 sin SinReinicios únicamente cuando se quiera demostrar recuperación del broker y persistencia; esa variante detiene/reinicia contenedores EV2. No elimina volúmenes, pero interrumpe temporalmente el sistema. No usarla durante una presentación sin haber planificado ese momento.

| Problema | Qué revisar |
| --- | --- |
| Falta una carpeta/Dockerfile | Descargar el componente faltante con su nombre exacto; no crear carpetas vacías para ocultar el error. |
| Docker no responde | Abrir Docker Desktop, verificar motor Linux y esperar que termine de iniciar. |
| Puerto ocupado | Identificar el proceso o proyecto que lo usa. No cerrar servicios ajenos automáticamente ni borrar volúmenes. |
| Contraseña de base incorrecta | Los volúmenes conservan la contraseña usada al crearlos. Recuperar la configuración original; no regenerar claves ni borrar bases para ocultar el problema. |
| Azure desalineado | Repetir configurar-azure.ps1 con los IDs reales; ejecutar comprobar-ev2.ps1 -SoloArchivos -ExigirAzure. |
| Login funciona pero la API devuelve 401 | Verificar access token de nuestra API, versión v2, tenant, audience, SPA autorizada, scope y consentimiento. No utilizar ID token/Graph ni desactivar JWT. |
| Operador recibe 403 en Catálogo/Rabbit Admin | Es correcto: el operador no tiene privilegios de administrador. |
| Ticket devuelve 404 | Esperar el procesamiento y comprobar un evento ACEPTADO; un envío histórico o solo CREADO puede no tener confirmación. Revisar el diagnóstico y las DLQ. |
| API remota devuelve 404/502 | Revisar URL base/stage, ruta /api, TLS y servicio destino. No confundir frontend /health UP con API remota funcionando. |

## 8. Qué no está terminado todavía

Login Duoc real, permisos Azure, gateway y servicios cloud siguen pendientes de datos/pruebas del equipo. La publicación del frontend es opcional en EV2 y Usuarios independiente corresponde a la etapa posterior. La demostración y evidencias están organizadas en DEMOSTRACION_Y_EVIDENCIAS_EV2.md.
