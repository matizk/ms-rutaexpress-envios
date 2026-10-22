# Demostración y evidencias de EV2

Guion sugerido de ocho minutos, ajustable a la indicación docente de presentación. No presentar una prueba local o un token de laboratorio como evidencia de Microsoft/AWS reales. Angular puede permanecer local según la aclaración escrita de la docente.

Actualización 21-10-2026: ya se completó el caso RX-1792623980566 con cuenta Duoc, aceptación, descarga del ticket y tracking público. Daniel confirmó el evento correspondiente en RDS/RabbitMQ; [fuentes y pendientes](evidencias/EV2_VERIFICACION_INTEGRADA_2026-10-21.md). Reutilizar esa evidencia y completar la auditoría de la pauta, no reconstruir el entorno. La presentación final y su ensayo siguen pendientes.

Confirmacion adicional recibida el 16-10-2026: **API Manager en AWS, Rabbit/servicio en AWS, BD en RDS**. El despliegue preparado y pruebas HTTP estan en [deploy/aws/README.md](deploy/aws/README.md). La bandeja operador cloud exige Azure; la revision Cognito del operador es solo para demostracion local, no login institucional.

## Antes de presentar

- Para la demostración contra AWS, ejecutar solo Angular local con `npm start` y verificar el Gateway existente. No iniciar otro backend ni Docker Desktop por esta guía. Si se elige mostrar el laboratorio local por separado, usar comprobar-ev2.ps1 -EnEjecucion e identificarlo como local, sin borrar bases ni volúmenes.
- Comprobar el login institucional real y el destino de la API del equipo antes de grabar.
- Tener un servicio de catálogo con cupos y una solicitud ficticia identificable. No usar nombres, correos ni direcciones de personas reales.
- Tener las capturas cloud proporcionadas por el equipo: no se pueden obtener de los contenedores locales.
- Ocultar contraseñas, tokens, códigos de acceso, secretos, cookies y datos personales. No mostrar .env.ev2 ni copiar bearer tokens al PPT.

## Recorrido sugerido

| Tiempo | Qué mostrar | Qué explica |
| --- | --- | --- |
| 0:00-0:45 | Arquitectura: Angular local, identidad Azure, API Manager/BFF, servicios, PostgreSQL y RabbitMQ | El frontend no es el servicio cloud ni el proveedor de identidad. |
| 0:45-1:45 | Login real con cuenta Duoc y bandeja del operador | Azure autentica; el token de acceso autoriza únicamente las rutas del operador. |
| 1:45-3:15 | Solicitud CREADO registrada desde Operación; revisión y aceptación desde Operador | La solicitud y su confirmación son pasos distintos; el registro actual usa administración Cognito, no un portal nuevo de clientes. |
| 3:15-4:00 | Ticket ACEPTADO y descarga; tracking del mismo código | La respuesta es real y persistida. Aceptación no significa entrega. |
| 4:00-5:15 | Broker real: dos nodos, direct/topic, tres colas y tres DLQ; productor/consumidor/log | Cómo se enruta y procesa el evento; ACK después de guardar. |
| 5:15-6:15 | Error controlado hacia DLQ e idempotencia, con evidencia de la prueba | Un mensaje inválido queda inspeccionable; un evento repetido no duplica resultados. |
| 6:15-7:15 | API administradora: operación válida y rechazo de entrada inválida/sin autorización | Configuración separada, servicio dedicado y validación. Usar recursos de demostración vacíos, nunca borrar recursos funcionales. |
| 7:15-8:00 | PostgreSQL y evidencias de EC2/RDS/API Manager; resumen de límites | Qué corre realmente en AWS y qué se está mostrando localmente. |

El escenario de recuperación del broker se puede grabar por separado con probar-ev2.ps1. No detenerlo improvisadamente durante el recorrido de usuario.

## Lista de evidencias

| Evidencia | Cómo obtenerla | Estado que se puede afirmar |
| --- | --- | --- |
| Salud y contenedores locales | diagnosticar-ev2.ps1 -GuardarInforme | Verificados localmente, no cloud. |
| Creación, eventos, duplicados, tres DLQ, tracking y 401 | probar-ev2.ps1 -SinReinicios; evidencias/EV2_PRUEBA_LOCAL.md | Prueba local real con PostgreSQL/RabbitMQ. |
| Recuperación/persistencia | Pasada completa de probar-ev2.ps1, planificada | Mostrar fecha y stack de la ejecución; no fingirla desde un conteo de contenedores. |
| Dependencias y build frontend | npm ci, npm audit, npm audit --omit=dev, npm test -- --watch=false, npm run build | Cero alertas conocidas en la auditoría del 15-10-2026; no garantía universal de seguridad. |
| Login Microsoft y consentimiento | Prueba con cuenta Duoc, registros reales y scope | Login y logout visibles comprobados por el integrante; conservar las capturas locales y sanitizar antes de publicar. |
| API Manager: rutas, emisor, audience y 401/403 | Capturas y llamadas al gateway real | Salud/tracking 200 y rutas administrativa/operador sin JWT 401 repetidos; reunir evidencia de authorizers y matriz de permisos/JWT inválido. |
| EC2 y RabbitMQ cloud | Compose ps y cluster_status ejecutados en esa instancia, más topología real | Daniel informó dos nodos y consumidores activos; adjuntar evidencia sanitizada. No sustituir por Docker Desktop ni dar por probado un error → DLQ a partir de DLQ vacías. |
| PostgreSQL/RDS | Conexión real, tablas y consulta de datos ficticios, ocultando credenciales | Daniel confirmó ACEPTADO, outbox y AUDIT/NOTIFICATION/TICKET del mismo evento; adjuntar consultas sanitizadas y evidencia TLS. |

## Dónde está el código que pueden preguntar

Los nombres son relativos a cada repositorio; conservar las carpetas hermanas para encontrarlos fácilmente.

| Tema | Archivo o carpeta |
| --- | --- |
| Login Azure y configuración | Frontend: src/app/core/auth/azure.config.ts y azure-session.service.ts; public/azure-config.json |
| Separación de tokens Azure/Cognito | Frontend: src/app/core/auth/auth.interceptor.ts |
| Bandeja, aceptación y ticket | Frontend: src/app/features/operator/ y core/operator/operator-api.service.ts |
| Solicitud y cambio de estado | Envíos: service/ShipmentService.java y controller/OperatorController.java |
| Atomicidad y publicación de eventos | Envíos: messaging/OutboxRecorder.java y OutboxPublisher.java |
| Topología y nombres centralizados | Mensajería: application.yml y config/RabbitTopology.java |
| Consumidores separados | Mensajería: notifications/, tickets/ y audit/ |
| ACK, errores y reintentos | Mensajería: events/EventHandler.java |
| Resultados idempotentes y confirmación | Mensajería: receipts/ReceiptStore.java y OperatorConfirmationController.java |
| API administradora y DTO | Mensajería: admin/RabbitAdminController.java y RabbitAdminService.java |
| Validación de JWT y permisos | BFF: config/SecurityConfig.java y AzureTokenPolicy.java; Envíos/Mensajería: security/ |
| Clúster y persistencia local | Envíos: compose.ev2.yml y rabbitmq/rabbitmq.conf |

## Explicación breve para responder preguntas

Un envío se guarda junto con su evento pendiente dentro de la misma transacción. El publicador espera confirmación de RabbitMQ y reintenta si falla. Los consumidores guardan un resultado por dominio/evento y después hacen ACK. Si el evento se repite, no repiten el resultado; si es inválido o agota los reintentos de base, va a DLQ. El operador acepta la solicitud y espera el ticket de ese estado, no el de creación.

Hay dos nodos RabbitMQ, pero las colas actuales son classic: no afirmar replicación de mensajes ni alta disponibilidad solo por mostrar el clúster. Las notificaciones son internas, no correos enviados. Los tokens de pruebas RSA locales no son tokens reales de Azure. Usuarios independiente no se exige en esta entrega.
