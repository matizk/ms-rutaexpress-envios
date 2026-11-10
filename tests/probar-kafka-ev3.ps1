# Prueba local de punta a punta. Crea un envío ficticio y un tópico descartable.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compose = @('-p', 'rutaexpress-ev3',
    '--env-file', (Join-Path $root '.env.ev2'), '--env-file', (Join-Path $root '.env.ev3.local'),
    '-f', (Join-Path $root 'compose.ev2.yml'), '-f', (Join-Path $root 'compose.kafka.yml'),
    '-f', (Join-Path $root 'compose.ev3.yml'))
$topic = 'rutaexpress.shipments.report.v1'
$report = 'http://127.0.0.1:8082'
$kafkaAdmin = 'http://127.0.0.1:8085'
$shipments = 'http://127.0.0.1:5000/api/shipments'
$catalog = 'http://127.0.0.1:8081/api/catalog/services'
$prometheus = 'http://127.0.0.1:19090'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 12)
$code = "RX-EV3-$suffix".ToUpperInvariant()

function Await-Result([string]$Description, [scriptblock]$Probe) {
    $until = (Get-Date).AddSeconds(30)
    do {
        if (& $Probe) { return }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $until)
    throw "No se comprobó a tiempo: $Description"
}

function Report-State {
    $sql = "SELECT status FROM report_shipments WHERE tracking_code = '$code';"
    $status = docker compose @compose exec -T report-db psql -X -U rutaexpress_report -d report_db -Atc $sql
    if ($LASTEXITCODE -ne 0) { throw 'Falló la consulta a report_db.' }
    return $status
}

foreach ($url in @("$report/actuator/health", "$kafkaAdmin/actuator/health", 'http://127.0.0.1:5000/actuator/health')) {
    if ((Invoke-RestMethod -Uri $url -TimeoutSec 8).status -ne 'UP') {
        throw "El servicio local aún no está listo: $url"
    }
}

$topicsUrl = "$kafkaAdmin/api/report/kafka/topics"
$topics = Invoke-RestMethod -Uri $topicsUrl -TimeoutSec 8
if ($topic -notin $topics) { throw 'El tópico de Reportes aún no está disponible.' }
if ((Invoke-WebRequest -Uri "$report/api/report/kafka/topics" -SkipHttpErrorCheck -TimeoutSec 8).StatusCode -ne 404) {
    throw 'Reportes sigue respondiendo en la ruta que pertenece a Kafka Admin.'
}
if ((Invoke-WebRequest -Uri 'http://127.0.0.1:8080/api/report/kafka/topics' -SkipHttpErrorCheck -TimeoutSec 8).StatusCode -ne 401) {
    throw 'El BFF no está exigiendo autenticación para la administración de Kafka.'
}
$invalidTopic = Invoke-WebRequest -Method Post -Uri $topicsUrl -SkipHttpErrorCheck -ContentType 'application/json' -Body (
    @{ name = "fuera-de-demo-$suffix"; partitions = 1; retentionHours = 24 } | ConvertTo-Json -Compress)
if ($invalidTopic.StatusCode -ne 400) { throw 'Kafka Admin no bloqueó la creación fuera del prefijo de prueba.' }

$service = Invoke-RestMethod -Method Post -Uri $catalog -ContentType 'application/json' -Body (
    @{ nombre = "Servicio EV3 $suffix"; descripcion = 'Validación local'; precio = 2000; cantidadDisponible = 1 } |
        ConvertTo-Json -Compress)
$shipment = Invoke-RestMethod -Method Post -Uri $shipments -ContentType 'application/json' -Body (
    @{ codigoSeguimiento = $code.ToLowerInvariant(); nombreDestinatario = 'Prueba EV3'; emailDestinatario = 'ev3@example.test';
        direccionOrigen = 'Santiago'; direccionDestino = "Destino EV3 $suffix"; pesoKg = 1; servicioId = $service.id } |
        ConvertTo-Json -Compress)
if ($shipment.codigoSeguimiento -cne $code) { throw 'Envíos no conservó el formato acordado para el código.' }
Await-Result 'creación reflejada en PostgreSQL de Reportes' { (Report-State) -eq 'CREADO' }

foreach ($status in @('ACEPTADO', 'EN_BODEGA', 'EN_RUTA', 'ENTREGADO')) {
    $null = Invoke-RestMethod -Method Put -Uri "$shipments/$($shipment.id)/status" -ContentType 'application/json' -Body (
        @{ estado = $status } | ConvertTo-Json -Compress)
}
Await-Result 'entrega reflejada en PostgreSQL de Reportes' { (Report-State) -eq 'ENTREGADO' }
Await-Result 'comprobante y actividad de aceptación procesados por RabbitMQ' {
    $sql = "SELECT count(DISTINCT domain) FROM message_receipts WHERE tracking_code = '$code' AND status = 'ACEPTADO' AND domain IN ('AUDIT', 'NOTIFICATION', 'TICKET');"
    $count = docker compose @compose exec -T messaging-db psql -X -U rutaexpress -d messaging_db -Atc $sql
    if ($LASTEXITCODE -ne 0) { throw 'Falló la consulta a messaging_db.' }
    $count -eq '3'
}
$kpis = Invoke-RestMethod -Uri "$report/api/report/kpis?range=last24h"
if ($kpis.deliveredShipments -lt 1) { throw 'La entrega no figura en los KPI.' }

# Reenviar el mensaje de creación debe dejar la última fila en ENTREGADO.
$query = "SELECT tracking_code || '|' || payload FROM shipment_report_outbox WHERE tracking_code = '$code' ORDER BY created_at LIMIT 1;"
$event = docker compose @compose exec -T shipments-db psql -X -U rutaexpress -d shipments_db -Atc $query
if ($LASTEXITCODE -ne 0 -or -not $event) { throw 'No se pudo recuperar el evento inicial de la prueba.' }
$metricUrl = "$report/actuator/prometheus"
function Ignored-Events {
    $metrics = (Invoke-WebRequest -Uri $metricUrl -TimeoutSec 5).Content
    $match = [regex]::Match($metrics, '(?m)^rutaexpress_report_events_total\{result="duplicate_or_stale",?\}\s+(\d+)')
    if (-not $match.Success) { throw 'No se encontró la métrica de mensajes repetidos.' }
    return [int]$match.Groups[1].Value
}
$previousIgnored = Ignored-Events
$event | docker compose @compose exec -T kafka-1 kafka-console-producer --bootstrap-server kafka-1:29092 --topic $topic --property parse.key=true --property 'key.separator=|'
if ($LASTEXITCODE -ne 0) { throw 'Kafka no recibió el evento repetido.' }
Await-Result 'descarte del evento anterior' { (Ignored-Events) -gt $previousIgnored }
if ((Report-State) -ne 'ENTREGADO') { throw 'El evento anterior hizo retroceder el estado.' }

$demoTopic = "rutaexpress.demo.$suffix"
$null = Invoke-RestMethod -Method Post -Uri $topicsUrl -ContentType 'application/json' -Body (
    @{ name = $demoTopic; partitions = 2; retentionHours = 24 } | ConvertTo-Json -Compress)
try {
    $retention = "$topicsUrl/$demoTopic/retention"
    $null = Invoke-RestMethod -Method Put -Uri $retention -ContentType 'application/json' -Body '{"retentionHours":48}'
    Await-Result 'retención del tópico de prueba' {
        (Invoke-RestMethod -Uri $retention -TimeoutSec 6).retentionMillis -eq 172800000
    }
    $partitions = "$topicsUrl/$demoTopic/partitions"
    $null = Invoke-RestMethod -Method Put -Uri $partitions -ContentType 'application/json' -Body '{"partitions":3}'
    Await-Result 'particiones del tópico de prueba' {
        (Invoke-RestMethod -Uri $partitions -TimeoutSec 6).partitions -eq 3
    }
} finally {
    $null = Invoke-RestMethod -Method Delete -Uri "$topicsUrl/$demoTopic"
}
Await-Result 'eliminación del tópico de prueba' { $demoTopic -notin (Invoke-RestMethod -Uri $topicsUrl) }

$promQuery = [Uri]::EscapeDataString('up{job="rutaexpress-reportes"}')
Await-Result 'scrape de Prometheus' {
    $samples = (Invoke-RestMethod -Uri "$prometheus/api/v1/query?query=$promQuery" -TimeoutSec 5).data.result
    $samples.Count -gt 0 -and $samples[0].value[1] -eq '1'
}
Write-Output "Verificado: $code recorrió Envíos, Kafka y PostgreSQL, llegó a ENTREGADO y apareció en los KPI."
Write-Output 'Verificado: RabbitMQ procesó auditoría, notificación y comprobante de aceptación.'
Write-Output 'Verificado: Kafka Admin separado de Reportes, BFF exige autenticación y la API protege el prefijo de prueba.'
Write-Output 'Verificado: evento anterior ignorado, creación, edición y eliminación del tópico de prueba y captura en Prometheus.'
