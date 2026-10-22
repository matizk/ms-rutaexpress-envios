# Alcance EV2 confirmado y limites de esta rama

Confirmacion escrita de la docente recibida el 16-10-2026, contrastada con pautas y clases:

- Angular se ejecuta localmente; su despliegue se solicitara en la entrega 3.
- Azure/Microsoft Entra autentica al operador con cuenta academica. No supone alojar Angular o todos los servicios en Azure.
- RabbitMQ, el servicio del caso y la BD se despliegan en AWS; BD mediante RDS y servicio en EC2.
- API Manager tambien corresponde a AWS, exponiendo endpoints y validando JWT.
- Pauta: cluster RabbitMQ de dos nodos, tres colas con DLQ, direct/topic, productores/consumidores y API administradora.
- Aclaracion oral: al menos uno de los servicios de solicitud/respuesta en EC2; el paquete propone alojar los cinco backends juntos para simplificar la integracion, no como requisito adicional.
- Usuarios independiente queda para la etapa de registro de clientes posterior, segun la explicacion de clase. No se cambia retrospectivamente la entrega anterior.

No se suben capturas de conversaciones, material docente, audios ni documentos de clase a los repositorios publicos. Los originales se conservan fuera de Git; este resumen recoge solo el alcance tecnico necesario.

Estado al 21-10-2026: el integrante completó el caso RX-1792623980566 con Azure Duoc, aceptación, ticket descargado y tracking público ACEPTADO. Daniel confirmó la solicitud/outbox en RDS y las tres recepciones de dominio del evento de aceptación; se atribuye a él esa inspección privada. La revisión repitió consultas públicas de salud, tracking y rechazo sin JWT. Ver [fuentes y pendientes de cierre](../evidencias/EV2_VERIFICACION_INTEGRADA_2026-10-21.md).

La respuesta posterior de la docente permite conservar Admin con Cognito; en EV2 revisa Operador con Azure. No es necesario migrar ambos perfiles a Azure ni crear otro microservicio para resolver la autenticación.

Falta cerrar la revisión/integración del frontend, contrastar todas las evidencias de la pauta, preparar informe/presentación y aprobar la entrega estable. Un check verde de CI no acredita por sí solo esas actividades. El ticket de aceptación no demuestra entrega del envío; las notificaciones son registros internos, no correos enviados.
