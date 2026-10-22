# EV2 - evidencia de prueba local

Fecha: 2026-10-15T19:44:47.0669121-03:00

Proyecto Docker: rutaexpress-ev2. Datos de demostracion, sin correos reales ni envio externo de mensajes.

- OK: Los cinco backends responden con health UP.
- OK: Cluster RabbitMQ de dos nodos: rabbit@rabbitmq-1, rabbit@rabbitmq-2
- OK: Existen tres colas funcionales, tres DLQ y exchanges direct/topic.
- OK: Creacion real RX-EV2-20261015194347848: notificacion, comprobante y auditoria persistidos en PostgreSQL.
- OK: El cambio a ACEPTADO produce otros tres resultados de procesamiento.
- OK: Reenviar el mismo evento no duplica notificaciones, comprobantes ni auditoria.
- OK: Un contrato invalido termina en cada una de las tres DLQ; los mensajes quedan disponibles para inspeccion.
- OK: APIs de operador protegidas en BFF, Envios y Mensajeria; un ticket de aceptacion real persistido.
- OK: Tracking publico por BFF operativo; APIs privadas rechazan ausencia de JWT y JWT invalido.

Pendiente: login institucional Azure, JWT real de ese tenant y despliegue cloud. Estas pruebas no certifican esos componentes.

Las DLQ conservan mensajes invalidos intencionales de esta prueba. No se eliminaron datos o volumenes anteriores.
