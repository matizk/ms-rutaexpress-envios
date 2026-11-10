# RutaExpress EV3 en dos EC2

Mantén el proyecto de Docker Compose que ya usa EV2 en la EC2 de aplicaciones. Allí quedan RabbitMQ, Envíos, BFF, Reportes, Kafka Admin y los otros servicios de la aplicación. En una segunda EC2 de la misma VPC, levanta ZooKeeper, dos brokers y Kafka UI.

## Código para el despliegue

Usa `main` en los siete repositorios para desplegar la versión publicada de la EV3. En la EC2 de aplicaciones, los repositorios de BFF, Envíos, Catálogo, Mensajería, Reportes y Kafka Admin deben estar en carpetas hermanas. En la EC2 de Kafka basta con Envíos. En el PC de la demo necesitas Envíos y el frontend como carpetas hermanas.

Si ya existe una copia de un repositorio, verifica con `git status` que esté limpia, cámbiate a `main` y actualízala con `git pull --ff-only origin main`. Para una copia nueva, clona con `git clone --branch main` y la URL de su repositorio.

## EC2 de Kafka

Desde la raíz del repositorio Envíos, crea un archivo privado `deploy/aws/.env.kafka.aws` con `KAFKA_PRIVATE_IP` igual a la IPv4 privada de la EC2 de Kafka. El grupo de seguridad de esa EC2 debe permitir TCP 9092 y 9093 desde el grupo de seguridad de la EC2 de aplicaciones. ZooKeeper y los listeners internos de Docker no requieren puertos de entrada. Kafka UI se queda en loopback y se puede consultar con un túnel SSH autorizado.

```bash
docker compose -p rutaexpress-kafka-aws --env-file deploy/aws/.env.kafka.aws \
  -f compose.kafka.yml -f deploy/aws/compose.kafka.aws.yml config --quiet
docker compose -p rutaexpress-kafka-aws --env-file deploy/aws/.env.kafka.aws \
  -f compose.kafka.yml -f deploy/aws/compose.kafka.aws.yml up -d --wait
```

Los clientes de la otra EC2 reciben la IP privada anunciada por los brokers. Kafka UI y la comunicación entre brokers usan los nombres internos de Docker.

## EC2 de aplicaciones y RDS

1. Actualiza las revisiones coordinadas de Envíos, BFF y Reportes y clona `ms-rutaexpress-kafka-admin` como carpeta hermana. Conserva el nombre de proyecto y el archivo privado que ya utiliza EV2.
2. Crea `report_db` y el usuario `rx_report` con [crear-base-reportes.sql](crear-base-reportes.sql) según las instrucciones del archivo. Deja el certificado de RDS en `deploy/aws/certs/global-bundle.pem`. Reportes usa TLS con `verify-full`.
3. En `deploy/aws/.env.ev3.aws` agrega `KAFKA_BOOTSTRAP_SERVERS` con ambos destinos privados, por ejemplo `10.0.2.15:9092,10.0.2.15:9093`. Agrega `REPORT_DB_PASSWORD` y `GRAFANA_ADMIN_PASSWORD` con claves del despliegue. Kafka Admin recibe la misma lista de brokers que Envíos y Reportes. Su puerto HTTP queda dentro de Docker.
4. Desde `deploy/aws`, valida e inicia el Compose combinado. Sustituye `rutaexpress-ev2-aws` si el proyecto existente usa otro nombre.

```bash
docker compose -p rutaexpress-ev2-aws --env-file .env.aws --env-file .env.ev3.aws \
  -f compose.aws.yml -f compose.ev3.aws.yml config --quiet
docker compose -p rutaexpress-ev2-aws --env-file .env.aws --env-file .env.ev3.aws \
  -f compose.aws.yml -f compose.ev3.aws.yml up -d --build
```

El arranque genera los tópicos de Reportes si hacen falta. Si hay que importar envíos anteriores, activa `REPORT_KAFKA_BACKFILL=true` en un arranque de Envíos, valida las filas en `report_db` y devuelve la variable a `false`.

## API Gateway y prueba final

Conserva el Gateway y su integración con el BFF. Agrega las siguientes rutas con el autorizador JWT de Cognito y el scope de acceso vigente. El BFF aplica el grupo `Admin` para Kafka y verifica la identidad del cliente para sus pedidos. La herramienta `crear-plan-api.ps1` incluye estas rutas como referencia para revisar la configuración existente.

| Métodos | Ruta |
|---|---|
| GET, POST | `/api/report/kafka/topics` |
| GET, PUT | `/api/report/kafka/topics/{topic}/retention` |
| GET, PUT | `/api/report/kafka/topics/{topic}/partitions` |
| DELETE | `/api/report/kafka/topics/{topic}` |
| GET | `/api/customer/services` |
| GET, POST | `/api/customer/shipments` |

## Angular para la demo contra AWS

Desde Envíos en el PC de la demo, prepara `.env.ev2` y apunta el proxy de Angular al API Gateway oficial. Sustituye la URL de ejemplo por la del equipo. Deja libre el puerto local 4200 antes del arranque.

```powershell
.\iniciar-ev2.ps1 -SoloConfigurar
.\configurar-api.ps1 -UrlApi 'https://tu-api.execute-api.us-east-1.amazonaws.com'
docker compose --env-file .env.ev2 -f deploy/aws/compose.frontend-cloud.yml `
  -f deploy/aws/compose.ev3.frontend-cloud.yml up -d --build
```

Abre `http://localhost:4200`, el origen registrado en Cognito y Azure para la demo. El Compose usa el panel de Grafana en `http://localhost:3000`. Abre un túnel SSH hacia el puerto 3000 de la EC2 de aplicaciones, inicia sesión en Grafana y entra a Reportes como Admin. Si la demo usa un origen HTTPS, ajusta `grafanaBaseUrl` en un archivo de configuración y señala su ruta con `REPORTES_CONFIG_FILE`.

Comprueba que un Admin pueda consultar y gestionar un tópico descartable `rutaexpress.demo.*`, que un cliente reciba un rechazo de esa API y que los KPI sigan funcionando. Crea un pedido con un cliente de prueba, revisa el evento en Kafka UI y valida que Reportes actualice la proyección en RDS y el dashboard de Grafana.
