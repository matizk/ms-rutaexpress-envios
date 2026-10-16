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

Implementado localmente: solicitud, aceptacion, outbox, consumidores/ACK/DLQ, tickets, PostgreSQL y preparacion Azure. Faltan IDs/consentimiento reales, despliegue AWS, pruebas integradas cloud y evidencia final. Un check verde de CI no acredita esos pasos. El ticket de aceptacion no demuestra entrega del envio; notificaciones son registros internos, no correos enviados.
