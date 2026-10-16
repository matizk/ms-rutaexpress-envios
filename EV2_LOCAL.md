# EV2 local: PostgreSQL y RabbitMQ

Este stack es independiente del anterior: proyecto `rutaexpress-ev2`, volúmenes nuevos y contraseñas locales aleatorias. Se conservan los volúmenes anteriores. Requiere las seis carpetas de componentes hermanas, incluida la nueva `ms-rutaexpress-messaging`.

## Arrancar

Abrir Docker Desktop con contenedores Linux. Desde esta carpeta, en PowerShell:

```powershell
.\iniciar-ev2.ps1
```

El script genera .env.ev2 si no existe, comprueba carpetas/configuración y Docker Linux, y construye las imágenes. Solo anuncia que está listo después de health UP en frontend y cinco backends. La primera ejecución necesita Internet para imágenes y dependencias. No hace falta instalar Java, Maven ni Node para ejecutar los contenedores. Con imágenes existentes se puede usar iniciar-ev2.ps1 -SinConstruir.

Antes de arrancar: comprobar-ev2.ps1 -SoloArchivos. Para comprobar el sistema ya activo: comprobar-ev2.ps1 -EnEjecucion. El diagnóstico de solo lectura se obtiene con diagnosticar-ev2.ps1 -GuardarInforme; no muestra valores secretos. La guía completa para el equipo está en PREPARACION_EQUIPO_EV2.md.

- Frontend: `http://localhost:4200/`; Operación: `http://localhost:4200/admin`.
- BFF: puerto 8080; Catálogo: 8081; Envíos: 5000; Reportes: 8082; Mensajería: 8084.
- PostgreSQL: Catálogo 15432, Envíos 15433, Mensajería 15434; usuario `rutaexpress`; bases `catalog_db`, `shipments_db`, `messaging_db`. Las contraseñas están en `.env.ev2`.
- RabbitMQ Management: puertos 15672 y 15673; usuario `rutaexpress`, contraseña `RABBITMQ_PASSWORD` en `.env.ev2`.

Los puertos están enlazados a localhost. Este archivo Compose es para la prueba local: el despliegue EC2 requiere coordinar red, URL públicas, API Manager y autenticación institucional con el equipo.

## Qué cambió

Al crear un envío o cambiar su estado se guarda también un registro en `shipment_outbox`, dentro de la misma transacción. El publicador intenta enviarlo a RabbitMQ y espera confirms; un fallo conserva el evento pendiente. El nuevo servicio procesa tres colas y conserva resultados idempotentes en PostgreSQL. El panel de Operación muestra la actividad y permite descargar comprobantes como texto.

La mensajería se habilita con `MESSAGING_ENABLED=true`. El valor predeterminado es false para mantener la ejecución anterior mientras se configura RabbitMQ. No se publican correos ni direcciones de destinatarios. Las notificaciones son internas; no se envía email.

La administración conserva Cognito. La integración Azure ya está preparada en código para `/operador`, con MSAL y validación JWT independiente en BFF, Envíos y Mensajería; sigue deshabilitada hasta obtener los identificadores y permiso del tenant. No se ha probado una cuenta Duoc real. La guía está en `frontend-rutaexpress/docs/AZURE_OPERADOR.md` y la configuración coordinada se genera con `configurar-azure.ps1`. Usuarios independiente queda para la siguiente etapa según la aclaración docente.

## Probar de extremo a extremo

```powershell
.\probar-ev2.ps1
```

La prueba crea un servicio y envíos ficticios. Verifica:

1. Salud de los cinco backends, dos nodos RabbitMQ y topología de tres colas más tres DLQ.
2. Tres resultados persistidos al crear el envío y otros tres al aceptarlo.
3. Reenviar un evento no duplica resultados.
4. Los mensajes inválidos llegan a las tres DLQ, donde quedan para inspección.
5. Tracking público por BFF y rechazo de solicitudes privadas sin JWT o con token inválido.
6. Detener RabbitMQ conserva un envío nuevo en el outbox; al recuperarlo, se procesa.
7. Reiniciar las tres bases conserva los datos.

La evidencia se genera en `evidencias/EV2_PRUEBA_LOCAL.md`, sin contraseñas ni datos personales reales. Durante la prueba se reinician exclusivamente los contenedores del proyecto EV2. Para omitir los reinicios: `.\probar-ev2.ps1 -SinReinicios`.

## Detener y volver a arrancar

```powershell
docker compose --env-file .env.ev2 -f compose.ev2.yml stop
docker compose --env-file .env.ev2 -f compose.ev2.yml start
```

Estas operaciones conservan los volúmenes. No es necesario borrar bases para repetir la prueba. Cada ejecución usa códigos de envío diferentes y deja mensajes inválidos de demostración en las DLQ.

## Pruebas automatizadas

Con JDK 21 o superior: `.\mvnw.cmd verify`. Hay pruebas de creación/cambio de estado, publicador con confirms y devoluciones, y transacción conjunta de envío y outbox. La prueba de base embebida valida rollback; `probar-ev2.ps1` comprueba el comportamiento real en PostgreSQL.

Para más detalle del nuevo componente, consultar `README.md` en la carpeta hermana `ms-rutaexpress-messaging`.

## Conexión con el trabajo cloud del equipo

Angular puede seguir local en EV2. configurar-api.ps1 permite apuntar su proxy a la URL HTTPS oficial de API Gateway/API Manager, conservando el stage si corresponde. No cambia Azure ni crea recursos cloud. configurar-api.ps1 -Local vuelve al BFF del Compose. Ambas opciones necesitan recrear el frontend con iniciar-ev2.ps1 -SinConstruir. Nunca usar URLs de terceros no autorizados, pues el proxy reenvía bearer tokens. Ver PREPARACION_EQUIPO_EV2.md y DEMOSTRACION_Y_EVIDENCIAS_EV2.md.

Pruebas adicionales: tests/probar-configuracion.ps1 (43 casos aislados) y tests/probar-proxy.ps1 (12 casos en contenedores efímeros sin red). Se ejecutaron con PowerShell 7; Windows PowerShell 5.1 está bloqueado por la política del equipo y no se cambió esa política.
