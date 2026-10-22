# RutaExpress EV2: punto de entrada para continuar en equipo

Actualizado: 21-10-2026 con el caso integrado `RX-1792623980566`. El integrante completó Azure Duoc → aceptación → ticket → tracking; Daniel confirmó el mismo evento en RDS y RabbitMQ. Las consultas públicas de salud, tracking y rechazo sin JWT se repitieron por separado. Fuentes, límites y pendientes en [la verificación integrada](evidencias/EV2_VERIFICACION_INTEGRADA_2026-10-21.md). **El flujo principal funciona; faltan revisión Git, evidencia completa de pauta e informe/presentación.** No reconstruir infraestructura ya operativa.

## 1. Qué pide esta entrega

La aclaración escrita de la profesora establece: **Angular local; Azure/Microsoft Entra para autenticación institucional; servicio y RabbitMQ en AWS; PostgreSQL en RDS; API Manager en AWS.** No hay que publicar Angular ni migrar todos los servicios a Azure en EV2. Resumen del alcance: [docs/ALCANCE_EV2.md](docs/ALCANCE_EV2.md).

Mostrar solicitud, aceptación del operador y respuesta/ticket; dos nodos RabbitMQ, tres colas y sus tres DLQ, exchanges direct/topic, productores/consumidores, ACK/errores, API administradora y JWT. Usuarios independiente se retoma en la etapa siguiente según la aclaración de clase; no agregarlo ahora para reemplazar la integración pendiente.

## 2. Qué tenemos y cómo funciona

| Componente | Responsabilidad |
| --- | --- |
| frontend-rutaexpress | Angular local :4200. Inicio y tracking públicos, Operación/Catálogo/Reportes administrativos, bandeja /operador y panel de mensajería. |
| ms-rutaexpress-bff | Puerta de entrada :8080. Enruta y valida tokens/permisos; el navegador no llama directamente a microservicios. |
| ms-rutaexpress-catalogo | Servicios, tarifas y cupos. Un envío necesita un servicio existente con cupos. |
| ms-rutaexpress-envios | Solicitudes/envíos, cambios de estado y outbox transaccional. Incluye el módulo de usuarios anterior, no un microservicio independiente. También reúne Compose, scripts y guías del sistema. |
| ms-rutaexpress-mensajeria | Nuevo servicio: notificaciones internas, tickets y auditoría en PostgreSQL; tres consumidores y API administradora RabbitMQ. |
| ms-rutaexpress-reportes | Indicadores calculados desde Envíos. No tiene una cuarta base propia. |

El administrador Cognito registra un servicio con cupos y una solicitud **CREADO**. El operador entra con Azure, revisa y acepta: queda **ACEPTADO**. Envíos guarda el cambio y el evento pendiente en la misma transacción; el publicador espera confirmación de RabbitMQ y reintenta. Cada consumidor persiste su resultado y después hace ACK; deduplica por dominio/evento. Contratos inválidos o errores agotados van a DLQ. Angular espera el ticket real de aceptación y permite descargarlo. Tracking público consulta el mismo código sin sesión.

No confundir el comprobante CREADO con aceptación ni la aceptación con entrega. Notificaciones son registros internos, no correos enviados. Dos nodos en una EC2 y colas classic NO acreditan alta disponibilidad ni replicación de mensajes.

## 3. Dónde está el avance y dónde trabajar

Los seis repositorios son públicos bajo https://github.com/matizk. La rama coordinada de integración es **desarrollo**, no main. **matizk** es nuestra rama personal de trabajo; cada compañero conserva/utiliza la suya y abre PR hacia desarrollo. La antigua rama develop se renombró, sin reescribir commits. Se conservan los PR originales del 16-10-2026; sus nombres anteriores son historia, no instrucciones para recrear esas ramas:

- [Frontend #1](https://github.com/matizk/frontend-rutaexpress/pull/1).
- [BFF #2](https://github.com/matizk/ms-rutaexpress-bff/pull/2).
- [Envíos #2](https://github.com/matizk/ms-rutaexpress-envios/pull/2).
- [Mensajería #1](https://github.com/matizk/ms-rutaexpress-mensajeria/pull/1).

Los cuatro PR originales quedaron fusionados; su base histórica puede mostrar el nombre anterior. Consultar los Comprobaciones y la rama desarrollo para el estado actual. Catálogo y Reportes no necesitaron cambios funcionales EV2; el ajuste de ramas sí actualiza su documentación. `main` conserva la entrega estable anterior; Mensajería main contiene su base inicial. **No hay entrega final EV2 todavía.** Las guías/evidencias antiguas que dicen “sin push” o “PR borrador” documentan aquella pasada, no el estado vivo de GitHub. [Registro del cambio de ramas](evidencias/CAMBIO_DE_RAMAS_2026-10-17.md).

El frontend [PR #7](https://github.com/matizk/frontend-rutaexpress/pull/7) ya integró la configuración AWS/Azure/Cognito. El [PR #8](https://github.com/matizk/frontend-rutaexpress/pull/8), acceso centralizado por perfil, sigue abierto desde `matizk` hacia `desarrollo`; no se fusiona sin aprobación. Las actualizaciones documentales de esta pasada se preparan en la rama personal y no implican una entrega a `main`.

Para consumir el AWS existente basta instalar Git y Node 24, descargar el frontend con la rama coordinada y ejecutar `npm ci` y `npm start` desde su carpeta. Abrir exactamente `http://localhost:4200`. El proxy ya apunta a https://awnqdvxvd9.execute-api.us-east-1.amazonaws.com con validación HTTPS. No se requiere Docker, Java ni una segunda copia del backend en el PC para este modo.

Para el laboratorio completamente local, instalar también Docker Desktop (motor Linux) y PowerShell 7 y descargar las seis carpetas hermanas: [PREPARACION_EQUIPO_EV2.md, secciones 1–3](PREPARACION_EQUIPO_EV2.md). Ejecutar ese laboratorio con Docker evita instalar Java, Maven, PostgreSQL o RabbitMQ en Windows. No confundirlo con la prueba contra AWS.

Si ya tienen código propio, revisar `git status`, conservarlo y coordinar antes de actualizar; no clonar encima ni hacer reset. Público permite leer/clonar, no hacer push: quien vaya a contribuir necesita permisos del propietario o el flujo de fork acordado. No se han concedido permisos nuevos ni activado protección de ramas automáticamente.

## 4. Verificación local reproducible, separada de AWS

En la carpeta ms-rutaexpress-envios, PowerShell:

```powershell
./iniciar-ev2.ps1 -SoloConfigurar
./comprobar-ev2.ps1 -SoloArchivos
./iniciar-ev2.ps1
./comprobar-ev2.ps1 -EnEjecucion
./probar-ev2.ps1 -SinReinicios
```

Abrir http://localhost:4200. El primer arranque genera `.env.ev2` con secretos locales aleatorios, no lo sobrescribe si existe. El smoke crea datos FICTICIOS, deja mensajes de demostración en DLQ y comprueba PostgreSQL/RabbitMQ reales. La variante sin `-SinReinicios` también interrumpe temporalmente el broker y las tres bases **locales** para probar recuperación y persistencia: acordar ese momento, no usarla en AWS ni durante una presentación improvisadamente.

El frontend compartido ya tiene Azure habilitado con los IDs reales integrados por PR #7. Un laboratorio nuevo debe mantener sus variables backend alineadas; sus valores por defecto no acreditan acceso institucional. Una revisión con Cognito Admin o RSA/JWKS de laboratorio no sustituye login Duoc. Detalle local: [EV2_LOCAL.md](EV2_LOCAL.md); evidencia histórica de descarga limpia: [evidencias/INTEGRACION_LIMPIA_2026-10-16.md](evidencias/INTEGRACION_LIMPIA_2026-10-16.md).

## 5. Trabajo del responsable de Azure

**Situación actual:** aplicaciones y scope ya configurados; la cuenta del integrante pudo entrar y cerrar sesión tras aceptar la invitación externa al directorio del proyecto. Las instrucciones siguientes sirven para revisar o reproducir la configuración, no para crear otro tenant o volver a registrar las aplicaciones. IDs públicos y límites en [el registro vigente](evidencias/EV2_VERIFICACION_INTEGRADA_2026-10-21.md). En el acceso centralizado del PR #8, usar **Acceder → Soy operador · Cuenta Duoc**.

1. Revisar lo ya creado en el tenant del proyecto; no duplicar registros a ciegas. Verificar Tenant ID, SPA Client ID y API Client ID contra la configuración vigente: son tres UUID con funciones distintas y SPA/API son aplicaciones diferentes.
2. Seguir [frontend-rutaexpress/docs/AZURE_OPERADOR.md](https://github.com/matizk/frontend-rutaexpress/blob/desarrollo/docs/AZURE_OPERADOR.md). SPA con callback exacto `http://localhost:4200/auth/azure`; API con access tokens v2, URI `api://UUID-API`, scope delegado `operator.access` y permiso concedido al frontend.
3. Verificar consentimiento y políticas del tenant. Si requiere administrador institucional, pedir autorización; no comprar Premium ni eludir controles. No se exige inventar usuarios o grupos nuevos.
4. Pasar al equipo los tres IDs y el nombre del scope, NO contraseña, client secret ni tokens. En Envíos ejecutar con los UUID reales:

```powershell
./configurar-azure.ps1 -TenantId 'UUID-TENANT-REAL' -FrontendClientId 'UUID-SPA-REAL' -ApiClientId 'UUID-API-REAL'
./comprobar-ev2.ps1 -SoloArchivos -ExigirAzure
./iniciar-ev2.ps1
```

5. Probar inicio de sesión Duoc, retorno a /operador, listado/aceptación/ticket y cierre de sesión. Debe obtener access token de NUESTRA API, no ID token ni token Graph. Azure solo concede operador, no Catálogo/Reportes/Rabbit Admin. Copiar los mismos IDs al backend AWS y a su authorizer.

Los textos UUID son marcadores: reemplazarlos, no ejecutarlos literalmente. Si la API está en AWS, completar también las secciones siguientes; health local no demuestra autenticación remota.

## 6. Trabajo del responsable de AWS

**Situación actual:** Daniel informó servicios, RabbitMQ y RDS operativos y confirmó el caso integrado. Gateway vigente: https://awnqdvxvd9.execute-api.us-east-1.amazonaws.com. Conservar evidencias del despliegue existente y contrastarlas con la pauta; la lista siguiente es una guía de mantenimiento/reproducción, no una orden para crear recursos duplicados. La revisión documental no accedió a las consolas privadas.

**Paso a paso técnico:** [deploy/aws/README.md](deploy/aws/README.md). Antes de ejecutar comandos, inventariar EC2, RDS, API Gateway, red, región y crédito/permisos existentes. No borrar ni reemplazar recursos anteriores ni crear ALB/VPC Link sin aprobación del dueño de la cuenta. Detener EC2 no elimina todos los costos.

Orden de trabajo:

1. Descargar/actualizar `desarrollo` coordinado; revisar capacidad de EC2 y Docker Compose Linux. El paquete propone cinco backends y dos Rabbit en EC2 para facilitar las llamadas internas, NO afirma que la profesora obligue a subir todos. Si se usa otra distribución, documentar y probar todas las conexiones necesarias.
2. RDS PostgreSQL privado: puerto 5432 solo desde SG de EC2; obtener CA oficial y usar TLS `verify-full`. `crear-bases.sql` prepara tres bases/propietarios separados sin borrar existentes; las aplicaciones no usan el usuario maestro. Bases nuevas no contienen el catálogo de otro computador.
3. Crear `.env.aws` privado desde el ejemplo, completar RDS/IDs Azure/Cognito y secretos propios distintos. No enviar el archivo al chat/GitHub. Respetar claves ya asociadas a volúmenes Rabbit y bases existentes.
4. Revisar Compose AWS, arrancar según la guía y comprobar salud REAL de cinco APIs y conexión a RDS. Rabbit debe mostrar dos nodos, tres colas funcionales, tres DLQ y direct/topic. Los microservicios/DB/Management no se abren a internet.
5. Definir ingreso al BFF compatible con permisos y presupuesto: ALB/VPC Link privado autorizado o ingreso HTTPS válido existente. Si ninguno está disponible, resolverlo con el dueño de la cuenta; no abrir HTTP inseguro para “hacerlo funcionar”.
6. Configurar API Manager en AWS: rutas explícitas, Azure v2 para las cuatro rutas del operador, Cognito/Admin para administración y tracking público deliberado. El generador local produce una plantilla **HTTP API**; no importar sobre una REST API ni borrar la API de EV1 sin adaptar/revisar. Preservar Authorization; no usar authorizer genérico que bloquee tracking ni dejar un catch-all anónimo.
7. Entregar URL HTTPS oficial de API Gateway y stage si tiene, estado de servicios y evidencia redactada. Una lista de recursos o `running` no basta: verificar JWT ausente/inválido rechazado y válido aceptado, con permisos correctos.

No enviar SSH keys, contraseñas, tokens, cookies ni credenciales cloud. No hacer `docker compose config` sin `--quiet` al compartir pantalla: puede imprimir secretos. No ejecutar `down -v`, migraciones destructivas, rotaciones ni purgas para ocultar un error.

## 7. Conectar y probar entre todos

Para `npm start`, el proxy del frontend ya usa el Gateway compartido; no ejecutar scripts de configuración ni iniciar un stack local solo para repetir la prueba institucional. Si se elige expresamente la alternativa Docker/Nginx de frontend local, configurar su destino desde Envíos:

```powershell
./configurar-api.ps1 -UrlApi 'https://awnqdvxvd9.execute-api.us-east-1.amazonaws.com'
```

Usar solo el dominio oficial verificado del equipo: recibirá bearer tokens. Seguir la sección 6 de la guía AWS para esa alternativa con `compose.frontend-cloud.yml`, sin depender de los backends del PC. No iniciar dos frontends en 4200. Reconstruir la imagen tras modificar `public/azure-config.json`.

Recorrido de aceptación, con datos ficticios:

- Cognito Admin: crear servicio con cupos y solicitud CREADO.
- Azure/Duoc: entrar a /operador, consultar esa solicitud, aceptarla una vez y obtener ticket ACEPTADO descargable.
- Tracking del mismo código sin sesión; no exponer nombre/correo del destinatario.
- Notificación, ticket y auditoría persistidos; mensaje repetido sin resultados adicionales; inválido hacia DLQ. Hacer las pruebas de errores en entorno acordado, no pegar comandos locales contra AWS.
- Gateway: falta de JWT y JWT inválido rechazados; Azure válido accede al operador pero no a administración; Cognito Admin conserva sus rutas.
- RDS: tablas/conteos y TLS real, persistencia tras reinicio planificado de aplicación. No mostrar filas personales ni password.
- Repetir desde otro PC/origen localhost autorizado para descubrir dependencias ocultas del PC original.

Guardar capturas/resultado con fecha y entorno: login institucional sin secretos, routes/authorizers, Compose ps EC2, cluster_status/topología cloud, RDS/TLS/conteos y el flujo visible. [DEMOSTRACION_Y_EVIDENCIAS_EV2.md](DEMOSTRACION_Y_EVIDENCIAS_EV2.md) contiene guion y mapa del código. **No sustituir evidencias cloud por Docker Desktop.**

## 8. Cerrar Gitflow y entrega

Trabajo nuevo: actualizar la rama personal desde desarrollo → trabajar en `matizk` en esta copia (los compañeros usan las suyas) → commits propios reales → PR a desarrollo → revisión y CI → confirmación de fusión. Se deja de crear ramas con el prefijo anterior. No atribuir commits a otros ni usar force-push. Cambiar un `.env` privado no exige inventar un commit; sí documentar configuración reproducible sin secretos.

Cuando el recorrido institucional/cloud y las evidencias estén aprobados, crear la rama `release/<version-acordada>`, revisar PR a main, fusionar y sincronizar desarrollo. Una corrección urgente usa `hotfix/<descripcion>`. No etiquetar una versión como terminada mientras falten estas pruebas. Revisar acceso de la profesora a los repositorios y enlaces de entrega con el equipo.

## 9. Mensaje inicial para la IA de quien continúe

> Continúa RutaExpress EV2 sin reescribir lo que funciona. Lee CONTINUAR_EV2_EQUIPO.md, evidencias/EV2_VERIFICACION_INTEGRADA_2026-10-21.md, docs/ALCANCE_EV2.md y DEMOSTRACION_Y_EVIDENCIAS_EV2.md de matizk/ms-rutaexpress-envios; además frontend-rutaexpress/docs/AZURE_OPERADOR.md. Primero comprueba la rama y los PR: esta corrección documental se prepara en matizk y puede no estar integrada aún en desarrollo. Mantén los seis repositorios con sus nombres actuales y conserva cualquier cambio propio. Angular queda local, Azure autentica al operador y Cognito conserva Admin; AWS aloja los servicios, RabbitMQ, RDS y API Gateway ya existentes. El caso RX-1792623980566 ya completó Azure Duoc, aceptación, descarga de ticket y tracking público ACEPTADO. Daniel confirmó el evento d88da0d8-4f06-42b0-9f6d-03c7916052c1 en RDS/outbox y AUDIT, NOTIFICATION, TICKET; atribuye a él esa inspección privada. El PR frontend #7 ya está integrado; #8 sigue abierto para revisión y autorización explícita. No repetir el diagnóstico antiguo de IDs ausentes, reconstruir AWS, relajar JWT/TLS, cambiar a multitenant ni generar costos. No borrar datos, purgar colas, reiniciar servicios compartidos ni usar force-push. Trabaja en la rama personal acordada, matizk para el propietario y la propia para cada compañero, con PR a desarrollo; no crees otras ramas innecesarias. Completa auditoría de evidencias de pauta, documentación, informe y presentación. Distingue prueba local de error, consulta pública y verificación privada comunicada por el responsable. No integres en desarrollo o main sin la autorización correspondiente ni inventes autoría o resultados.
