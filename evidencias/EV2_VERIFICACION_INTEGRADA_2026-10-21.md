# EV2: verificación integrada y pendientes de cierre

Fecha: 21 de octubre de 2026, hora de Chile. Registro sanitizado para revisión del equipo; no declara terminada la evaluación.

## 1. Fuentes y límites

Se distinguen tres fuentes: la prueba realizada por el integrante con su cuenta académica, las consultas públicas de solo lectura repetidas durante esta revisión y la confirmación técnica del responsable de infraestructura, Daniel. Esta revisión documental no entró en las consolas privadas de AWS, RDS ni Entra y no vuelve a presentar las comprobaciones de Daniel como una inspección independiente.

No se adjuntan conversaciones, material docente, capturas con identidad, credenciales ni el archivo TXT original. De la descarga se conserva una captura local del contenido. Los identificadores de solicitud y evento permiten correlacionar la evidencia sin publicar nombre o correo del integrante.

## 2. Caso funcional completado

| Dato | Resultado |
| --- | --- |
| Solicitud | `RX-1792623980566` |
| Servicio y ruta | Express, 1 kg; Santiago → Valparaíso |
| Estado inicial | `CREADO` |
| Estado posterior | `ACEPTADO` |
| Evento de aceptación | `d88da0d8-4f06-42b0-9f6d-03c7916052c1` |
| Ticket | `TK-d88da0d8-4f06-42b0-9f6d-03c7916052c1` |

El integrante inició sesión con su cuenta Duoc mediante Microsoft Entra ID, seleccionó la solicitud preparada por Daniel, la aceptó y descargó la confirmación TXT. Las capturas muestran la sesión institucional, el cambio de estado y el ticket. También se comprobó el cierre de sesión visible de operador en una prueba anterior; esto no significa que todo token emitido quede revocado inmediatamente ni que se cierren otras sesiones de Microsoft.

El tracking del mismo código se comprobó desde Angular sin sesión y por el endpoint público. El ticket acredita aceptación de la solicitud, no entrega física del envío. Las notificaciones de esta implementación son registros internos, no correos enviados.

## 3. Consultas públicas repetidas en esta revisión

Gateway: https://awnqdvxvd9.execute-api.us-east-1.amazonaws.com

| Consulta GET sin credenciales | Resultado observado |
| --- | --- |
| `/actuator/health` | HTTP 200, `status=UP` |
| `/api/shipments/track/RX-1792623980566` | HTTP 200, código coincidente y `estado=ACEPTADO` |
| `/api/operator/shipments` | HTTP 401 |
| `/api/catalog/services` | HTTP 401 |

No se envió otra aceptación ni se crearon datos, recursos o sesiones. Los 401 demuestran rechazo sin JWT en esas consultas; no sustituyen una prueba con JWT inválido ni de separación de permisos con tokens válidos.

## 4. Verificación interna comunicada por Daniel

Daniel confirmó para este mismo caso:

- `shipments_db`: solicitud en `ACEPTADO` y outbox con `shipment.status_changed` publicado sin error.
- RabbitMQ: consumidores activos en auditoría, notificaciones y tickets, sin mensajes listos ni no confirmados; las tres DLQ vacías en la inspección.
- `messaging_db`: recepciones `AUDIT`, `NOTIFICATION` y `TICKET` para el evento de aceptación de la tabla anterior.
- El identificador del ticket coincide con el evento persistido.

La correlación entre solicitud, evento y recepciones respalda el procesamiento informado. Una cola vacía, por sí sola, no demuestra entrega ni ACK. Una DLQ vacía durante el caso exitoso tampoco demuestra qué ocurre ante un mensaje inválido.

Según el traspaso de infraestructura, AWS ejecuta BFF, Catálogo, Envíos, Mensajería y Reportes, dos nodos RabbitMQ y PostgreSQL en RDS; el ingreso usa HTTP API Gateway, VPC Link y ALB interno. Conservar capturas sanitizadas y resultados fechados de esas comprobaciones para el informe. No afirmar alta disponibilidad o replicación de mensajes solo por ver dos nodos: las colas del paquete son classic.

## 5. Identidad y configuración vigente

- Angular se ejecuta en `http://localhost:4200`; utiliza el Gateway HTTPS, no la IP pública de EC2.
- Operador: Azure/Microsoft Entra ID. Administrador: Cognito y grupo exacto `Admin`. La respuesta docente permite mantener Admin y centra la revisión EV2 en el operador Azure.
- El directorio de proyecto es single-tenant. Una cuenta académica válida también necesita acceso a ese directorio; la invitación externa aceptada permitió completar la prueba. No hace falta reconstruir AWS, relajar JWT ni cambiar a multitenant para resolver ese caso.
- Tenant: `6289a099-2080-4d8e-84ef-8c98e42b2599`.
- SPA: `55e07a0c-c96a-4e1b-95d2-7c3b06117828`.
- API: `fc461744-8d40-4e06-b5f9-7530c9f19d2b`.
- Scope: `api://fc461744-8d40-4e06-b5f9-7530c9f19d2b/operator.access`.
- Callback: `http://localhost:4200/auth/azure`.

Son identificadores públicos, no contraseñas. Las autorizaciones concretas del directorio se revisan con su responsable, sin compartir tokens o credenciales.

## 6. Estado Git observado al revisar

- Frontend [PR #7](https://github.com/matizk/frontend-rutaexpress/pull/7): ya integrado en `desarrollo`; configura proxy y los identificadores actuales. No volver a tratarlo como pendiente.
- Frontend [PR #8](https://github.com/matizk/frontend-rutaexpress/pull/8): abierto de `matizk` hacia `desarrollo`, commit funcional revisado `bb72f0ed4e5c9cca79f4b44a845db1223806baa3`; comprobación `angular` aprobada. La revisión técnica de esta pasada no es una aprobación humana independiente ni autoriza un merge.
- En esta pasada se repitieron las 26 pruebas del frontend en ocho archivos y la compilación Angular; ambas validaciones aprobaron. Las correcciones posteriores solo cambian Markdown, no código, dependencias o configuración de ejecución.
- Las correcciones documentales de esta pasada se revisan desde `matizk` mediante PR hacia `desarrollo`. Su publicación no implica que estén integradas; consultar los PR y sus commits antes de continuar. No se fusionan automáticamente ni modifican `main`.
- `main` conserva EV1 en los repositorios anteriores; en Mensajería conserva la base inicial. No representa todavía el cierre EV2.
- La profesora ya figuraba como colaboradora en cinco repositorios. El propietario envió la invitación que faltaba en Mensajería; la captura aportada muestra aceptación pendiente. También estaba pendiente la invitación de otro integrante a ese repositorio. Comprobar el estado vivo antes de reenviar invitaciones.

## 7. Pendientes concretos

| Pendiente | Responsable propuesto | Criterio de cierre |
| --- | --- | --- |
| Revisar e integrar PR #8 | Equipo y propietario | Aprobación explícita, CI vigente, integración a `desarrollo` y prueba posterior |
| Revisar e integrar documentación actualizada | Propietario y revisores | PR sin secretos, enlaces correctos y textos sin pendientes históricos presentados como actuales |
| Reunir evidencia técnica AWS | Daniel | Capturas/consultas sanitizadas del mismo caso: RDS, outbox, tres recepciones, clúster y Gateway |
| Contrastar errores y administración con la pauta | Daniel y equipo | Evidencia identificada de inválido → DLQ con log, idempotencia, API administradora válida/inválida y autorización; indicar claramente si la prueba es local o cloud |
| Informe y arquitectura | Daniel: AWS; integrante: frontend/Azure | Documento coherente con la implementación y sus límites, con fuentes y evidencias |
| Presentación y ensayo | Equipo | Recorrido y reparto de intervenciones dentro del tiempo docente; respaldo sanitizado si falla una demo |
| Colaboradores y participación Git | Propietario y equipo | Invitaciones atendidas y contribuciones reales visibles, sin inventar autoría |
| Entrega estable | Propietario, con revisión del equipo | Última prueba aprobada, preparación coordinada de release y PR hacia `main`; sin push directo ni fusión automática |

Las pruebas locales históricas de DLQ/duplicados no desaparecen, pero no se convierten en evidencia cloud por actualizar esta tabla. No inyectar errores en AWS, purgar colas ni reiniciar servicios compartidos para obtener capturas sin coordinar y autorizar el procedimiento.
