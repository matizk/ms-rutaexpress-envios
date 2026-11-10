# Reportería de RutaExpress para la EV3

Envíos publica en Kafka cuando se crea una solicitud o cambia su estado. Reportes recibe esos eventos, actualiza su tabla en PostgreSQL y responde los KPI que consulta Angular. Kafka Admin es un microservicio independiente para administrar tópicos y sus configuraciones. Mensajería sigue recibiendo por RabbitMQ los eventos que usa para los tickets y las notificaciones.

## Arranque en Windows

Requiere Docker Desktop con contenedores Linux y PowerShell 7. Los siete repositorios del equipo deben estar en carpetas hermanas, incluido `ms-rutaexpress-kafka-admin`. Desde la raíz de Envíos, ejecuta:

```powershell
.\iniciar-ev3.ps1
```

El script crea la configuración local si todavía no existe. Docker usa el proyecto `rutaexpress-ev3` con volúmenes propios. La variante `-SoloReportes` omite Angular y el BFF. Usa `-SinConstruir` cuando ya tienes las imágenes de la versión que quieres probar.

| Componente | Acceso local |
|---|---|
| Angular | http://localhost:4200/reportes |
| Kafka UI | http://localhost:18089 |
| Prometheus | http://localhost:19090/targets |
| Grafana | http://localhost:3000/d/rutaexpress-ev3/rutaexpress-ev3 |
| Salud de Reportes | http://localhost:8082/actuator/health |
| Salud de Kafka Admin | http://localhost:8085/actuator/health |

Para ver el dashboard dentro de Angular, entra a Reportes con Cognito Admin y autentícate también en Grafana usando **Abrir Grafana**. En la instalación local, el usuario de Grafana es `admin` y la clave inicial está en la variable `GRAFANA_ADMIN_PASSWORD` de `.env.ev3.local`. Abre ambos sitios con el nombre `localhost` para que el navegador conserve la sesión dentro del iframe.

## Comprobación de punta a punta

```powershell
.\tests\probar-kafka-ev3.ps1
```

La prueba usa la instalación local con los puertos y el tópico por defecto. Crea un servicio y un envío ficticios, verifica su cambio a ENTREGADO en `report_db` y comprueba los KPI. Reenvía la creación para confirmar que el estado conserva la entrega. Crea un tópico de prueba, cambia su retención y sus particiones, y lo elimina. También comprueba que Prometheus puede consultar Reportes.

En Kafka UI, el tópico `rutaexpress.shipments.report.v1` muestra los eventos con el código RX como clave. La tabla `shipment_report_outbox` de Envíos conserva los eventos pendientes o publicados. `report_shipments`, en `report_db`, guarda una fila por código RX. En Grafana se ven los envíos por estado, los eventos procesados y la disponibilidad de Reportes.

El BFF mantiene la ruta `/api/report/kafka/topics` y la dirige a Kafka Admin. Exige Cognito Admin para listar, consultar o administrar tópicos desde la aplicación. Las escrituras se limitan a `rutaexpress.demo.` para proteger los tópicos usados por el sistema.

## Demostración con las cuentas del proyecto

1. El cliente se registra o inicia sesión con Cognito y crea una solicitud. Anota el código RX y comprueba que el estado inicial sea CREADO.
2. El administrador abre Reportes. Comprueba que subió el conteo de CREADO en el panel de Grafana y que el evento del mismo código llegó al tópico de Kafka.
3. El operador acepta la solicitud y el administrador la avanza a EN_BODEGA o EN_RUTA desde la aplicación. En Grafana, el envío pasa al nuevo estado y el total de envíos se conserva.

La prueba local automatizada comprueba el recorrido de los eventos y los KPI. La demostración con las cuentas reales incluye el registro del cliente y el dashboard embebido.

## Acceso del cliente

Desde **Acceder**, elige **Crear cuenta de cliente** en la tarjeta Cliente si todavía no tienes una cuenta. El botón abre directamente el formulario de Cognito. Regístrate con un correo distinto al de administrador. Si ya tienes cuenta, elige **Ingresar como cliente**. Cognito asigna el acceso administrativo mediante el grupo `Admin`. Si devuelve una cuenta que no coincide con el perfil seleccionado, la app bloquea ese acceso y permite usar la cuenta correspondiente. En **Mis pedidos** puedes crear una solicitud y consultar el estado de tus pedidos. Usa una ventana privada para probar con el cliente mientras mantienes la cuenta Admin en una ventana normal.

La API del cliente permite `GET /api/customer/services` para ver los servicios y `GET` y `POST /api/customer/shipments` para consultar y crear pedidos. Envíos registra la propiedad con el identificador `sub` del token de Cognito. Los envíos previos y los creados desde Administración se conservan en su flujo habitual. Los nuevos pedidos del cliente entran al mismo flujo de Envíos, RabbitMQ y Kafka.

El arranque local toma el pool y el cliente de Cognito de `cognito-settings.json` y el acceso del operador de `azure-config.json`. Para AWS, configura esos mismos valores en el BFF, Envíos y los autorizadores de API Gateway. Habilita el registro de autoservicio del pool y verifica el inicio de sesión de una cuenta nueva. El grupo `Admin` se asigna solo a las cuentas autorizadas. Si el Gateway tiene rutas explícitas, agrega los tres métodos del cliente con el autorizador de Cognito.

## Preparación de AWS

La profesora indicó en el audio de Kafka (2:09–2:20) que, si RabbitMQ ya está en la EC2 actual, se debe levantar otra instancia para Kafka. El [paso a paso para dos EC2](deploy/aws/EV3_DESPLIEGUE.md) separa los brokers y Kafka UI del BFF y los microservicios. Incluye los valores que hay que configurar, el orden de arranque y las rutas que se agregan al Gateway existente.

## Pendientes de la pauta

- Verificar en el pool de Cognito el registro de una cuenta de cliente y probar su pedido con el BFF y el dashboard de la demo.
- Validar el despliegue de la EV3 en EC2 y RDS, y el iframe desde Angular con las cuentas de la demo.
- Integrar las ramas del equipo, comprobar la participación y el acceso de la profesora a los repositorios de backend.
- Preparar la demostración de hasta 10 minutos desde el miércoles 18 de noviembre. El video de ejecución corresponde al Examen Final.
