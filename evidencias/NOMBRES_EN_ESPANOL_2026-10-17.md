# Nombres públicos en español: 17-10-2026

Se renombraron los seis repositorios y carpetas conservando identidad, historial, colaboradores y ramas personales. La tabla de equivalencias y los pasos para actualizar copias existentes están en [PREPARACION_EQUIPO_EV2.md](../PREPARACION_EQUIPO_EV2.md).

La guía de colaboración se llama COLABORACION.md. Las futuras ramas de entrega/corrección usan entrega/... y correccion/.... Los commits y PR anteriores conservan sus textos históricos; no se ha reescrito la historia compartida.

## Alcance comprobado localmente

- 48 casos de configuración, 69 casos de planificación AWS y 10 casos de archivos temporales: correctos (127 en total).
- YAML de cuatro flujos de verificación y enlaces locales de las guías activas: correctos.
- Contextos de construcción de los cuatro Compose actualizados y existentes.
- Sin cambios en Java, TypeScript, dependencias, Dockerfiles, nombres internos de servicios, rutas de API, puertos, volúmenes ni configuración privada.

Docker estaba apagado y no se arrancó para esta revisión. No se repitió la demostración funcional ni se certifica Azure, EC2, RDS o API Gateway reales. Las pruebas funcionales anteriores conservan su fecha y alcance.

main recibe únicamente mantenimiento documental desde una corrección basada en su propia versión. La implementación EV2 sigue en desarrollo hasta la validación institucional/cloud; la traducción no equivale a entrega final.

Los resultados de verificación remota y las fusiones se consultan en las solicitudes de integración y en las acciones de cada repositorio. No se simula una aprobación humana de otro integrante.
