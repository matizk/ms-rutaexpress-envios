param([switch]$SinReinicios)
$ErrorActionPreference = 'Stop'
$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
$dockerPath = if ($dockerCommand) { $dockerCommand.Source } else { 'C:\Users\Matizk\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe' }
$envFile = Join-Path $PSScriptRoot '.env.ev2'
if (-not (Test-Path -LiteralPath $envFile)) { throw 'Ejecuta iniciar-ev2.ps1 primero.' }
$composeArgs = @('compose', '--env-file', $envFile, '-f', (Join-Path $PSScriptRoot 'compose.ev2.yml'))
$stackInfo = & $dockerPath @composeArgs config --format json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $stackInfo.name -ne 'rutaexpress-ev2') { throw 'La prueba solo admite el proyecto aislado rutaexpress-ev2.' }
$ev2Settings = @{}
Get-Content -LiteralPath $envFile | ForEach-Object {
    if ($_ -match '^([A-Z_]+)=(.*)$') { $ev2Settings[$Matches[1]] = $Matches[2] }
}
$rabbitHeaders = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('rutaexpress:' + $ev2Settings['RABBITMQ_PASSWORD'])) }
$evidence = New-Object 'System.Collections.Generic.List[string]'
function Pass([string]$text) { Write-Output "OK: $text"; $evidence.Add("- OK: $text") }
function Assert-True([bool]$condition, [string]$message) { if (-not $condition) { throw $message } }
function Invoke-Db([string]$service, [string]$database, [string]$sql) {
    $value = & $dockerPath @composeArgs exec -T $service psql -U rutaexpress -d $database -Atq -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) { throw "Fallo de consulta en $service" }
    return ($value -join "`n").Trim()
}
function Wait-For([scriptblock]$check, [string]$message, [int]$attempts = 80) {
    for ($step = 0; $step -lt $attempts; $step++) {
        try { if (& $check) { return } } catch { }
        Start-Sleep -Milliseconds 500
    }
    throw "Tiempo agotado: $message"
}
function Wait-Health([int]$port) {
    Wait-For { (Invoke-RestMethod "http://localhost:$port/actuator/health" -TimeoutSec 3).status -eq 'UP' } "salud del puerto $port"
}
function Http-Status([string]$url, [hashtable]$headers = @{}) {
    try { return [int](Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 5).StatusCode }
    catch {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        throw
    }
}
function Rabbit-Get([string]$resource) { return Invoke-RestMethod -Uri "http://localhost:15672/api/$resource" -Headers $rabbitHeaders -TimeoutSec 5 }
function Publish-Message([string]$exchange, [string]$key, [string]$payload, [string]$id) {
    $body = @{ routing_key = $key; payload = $payload; payload_encoding = 'string'; properties = @{ content_type = 'application/json'; delivery_mode = 2; message_id = $id } } | ConvertTo-Json -Depth 5
    $result = Invoke-RestMethod -Method Post -Uri "http://localhost:15672/api/exchanges/%2F/$exchange/publish" -Headers $rabbitHeaders -ContentType 'application/json' -Body $body
    Assert-True $result.routed "Mensaje sin ruta en $exchange"
}
function Receipt-Count([string]$code) { return [int](Invoke-Db 'messaging-db' 'messaging_db' "SELECT count(*) FROM message_receipts WHERE tracking_code='$code'") }
function New-DemoShipment([string]$code, [long]$serviceId) {
    Assert-True ($code -match '^RX-[A-Z0-9-]+$') 'Codigo de prueba invalido'
    $body = @{ codigoSeguimiento=$code; nombreDestinatario='Prueba EV2'; emailDestinatario='ev2-demo@example.test'; direccionOrigen='Santiago'; direccionDestino='Valparaiso'; pesoKg=1.5; servicioId=$serviceId } | ConvertTo-Json
    return Invoke-RestMethod -Method Post -Uri 'http://localhost:5000/api/shipments' -ContentType 'application/json' -Body $body
}

foreach ($port in @(8081, 5000, 8084, 8080, 8082)) { Wait-Health $port }
Pass 'Los cinco backends responden con health UP.'
$cluster = & $dockerPath @composeArgs exec -T rabbitmq-1 rabbitmqctl cluster_status --formatter json | ConvertFrom-Json
Assert-True ($LASTEXITCODE -eq 0 -and $cluster.running_nodes.Count -eq 2) 'No se encontraron dos nodos RabbitMQ activos'
Pass ('Cluster RabbitMQ de dos nodos: ' + ($cluster.running_nodes -join ', '))

$queueNames = @('rutaexpress.notifications', 'rutaexpress.tickets', 'rutaexpress.audit', 'rutaexpress.notifications.dlq', 'rutaexpress.tickets.dlq', 'rutaexpress.audit.dlq')
$queues = @(Rabbit-Get 'queues/%2F')
foreach ($name in $queueNames) { Assert-True ($name -in $queues.name) "Falta la cola $name" }
$exchanges = @(Rabbit-Get 'exchanges/%2F')
Assert-True (@($exchanges | Where-Object { $_.name -eq 'rutaexpress.events' -and $_.type -eq 'topic' }).Count -eq 1) 'Falta exchange topic'
Assert-True (@($exchanges | Where-Object { $_.name -eq 'rutaexpress.commands' -and $_.type -eq 'direct' }).Count -eq 1) 'Falta exchange direct'
Pass 'Existen tres colas funcionales, tres DLQ y exchanges direct/topic.'

$demoCode = 'RX-EV2-' + (Get-Date -Format 'yyyyMMddHHmmssfff')
$catalogBody = @{ nombre='EV2 Express'; descripcion='Servicio de prueba automatizada'; precio=3500; cantidadDisponible=20 } | ConvertTo-Json
$service = Invoke-RestMethod -Method Post -Uri 'http://localhost:8081/api/catalog/services' -ContentType 'application/json' -Body $catalogBody
$shipment = New-DemoShipment $demoCode $service.id
Wait-For { (Receipt-Count $demoCode) -eq 3 } 'tres consumidores para el envio creado'
Pass "Creacion real ${demoCode}: notificacion, comprobante y auditoria persistidos en PostgreSQL."

$null = Invoke-RestMethod -Method Put -Uri "http://localhost:5000/api/shipments/$($shipment.id)/status" -ContentType 'application/json' -Body '{"estado":"ACEPTADO"}'
Wait-For { (Receipt-Count $demoCode) -eq 6 } 'tres consumidores para el cambio de estado'
Pass 'El cambio a ACEPTADO produce otros tres resultados de procesamiento.'

$payload = Invoke-Db 'shipments-db' 'shipments_db' "SELECT payload FROM shipment_outbox WHERE payload::jsonb->>'trackingCode'='$demoCode' AND event_type='shipment.created'"
$eventId = ($payload | ConvertFrom-Json).eventId
Publish-Message 'rutaexpress.events' 'shipment.created' $payload $eventId
Publish-Message 'rutaexpress.commands' 'ticket.generate' $payload $eventId
Start-Sleep -Seconds 2
Wait-For { @((Rabbit-Get 'queues/%2F') | Where-Object { $_.name -in $queueNames[0..2] -and ($_.messages -gt 0) }).Count -eq 0 } 'consumo del duplicado'
Assert-True ((Receipt-Count $demoCode) -eq 6) 'El duplicado genero registros adicionales'
Pass 'Reenviar el mismo evento no duplica notificaciones, comprobantes ni auditoria.'

$beforeDlq = @{}
foreach ($name in $queueNames[3..5]) { $beforeDlq[$name] = [int](Rabbit-Get "queues/%2F/$name").messages }
Publish-Message 'rutaexpress.events' 'shipment.created' '{"schemaVersion":99}' "invalid-$demoCode"
Publish-Message 'rutaexpress.commands' 'ticket.generate' '{"schemaVersion":99}' "invalid-$demoCode"
foreach ($name in $queueNames[3..5]) {
    Wait-For { [int](Rabbit-Get "queues/%2F/$name").messages -gt $beforeDlq[$name] } "mensaje invalido en $name"
}
Pass 'Un contrato invalido termina en cada una de las tres DLQ; los mensajes quedan disponibles para inspeccion.'

Assert-True ((Http-Status 'http://localhost:8080/api/messaging/summary') -eq 401) 'El BFF permitio acceso anonimo'
Assert-True ((Http-Status 'http://localhost:8084/api/rabbitmq/topology') -eq 401) 'La administracion permitio acceso anonimo'
Assert-True ((Http-Status 'http://localhost:8084/api/rabbitmq/topology' @{Authorization='Bearer invalid-token'}) -eq 401) 'Se acepto un token invalido'
foreach ($operatorUrl in @('http://localhost:8080/api/operator/shipments', 'http://localhost:5000/api/operator/shipments',
        "http://localhost:8084/api/operator/confirmations/$demoCode")) {
    Assert-True ((Http-Status $operatorUrl) -eq 401) 'Una API del operador permitio acceso anonimo'
    Assert-True ((Http-Status $operatorUrl @{Authorization='Bearer invalid-token'}) -eq 401) 'Una API del operador acepto un token invalido'
}
Assert-True ((Invoke-Db 'messaging-db' 'messaging_db' "SELECT count(*) FROM message_receipts WHERE tracking_code='$demoCode' AND domain='TICKET' AND event_type='shipment.status_changed' AND status='ACEPTADO'") -eq '1') 'No existe un unico ticket real de aceptacion'
Pass 'APIs de operador protegidas en BFF, Envios y Mensajeria; un ticket de aceptacion real persistido.'
$tracking = Invoke-RestMethod "http://localhost:8080/api/shipments/track/$demoCode"
Assert-True ($tracking.estado -eq 'ACEPTADO') 'El tracking publico no coincide'
Pass 'Tracking publico por BFF operativo; APIs privadas rechazan ausencia de JWT y JWT invalido.'

if (-not $SinReinicios) {
    & $dockerPath @composeArgs stop -t 15 rabbitmq-1 rabbitmq-2 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo detener el cluster de prueba' }
    try {
        $recoveryCode = $demoCode + '-R'
        $null = New-DemoShipment $recoveryCode $service.id
        $pending = Invoke-Db 'shipments-db' 'shipments_db' "SELECT count(*) FROM shipment_outbox WHERE payload::jsonb->>'trackingCode'='$recoveryCode' AND published_at IS NULL"
        Assert-True ([int]$pending -eq 1) 'El evento no quedo pendiente en el outbox'
        Assert-True ((Receipt-Count $recoveryCode) -eq 0) 'Se proceso un evento mientras el broker estaba detenido'
    } finally {
        & $dockerPath @composeArgs start rabbitmq-1 rabbitmq-2 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo reiniciar el cluster de prueba' }
    }
    Wait-For { (Receipt-Count $recoveryCode) -eq 3 } 'recuperacion tras reiniciar RabbitMQ' 150
    Wait-For { [int](Invoke-Db 'shipments-db' 'shipments_db' "SELECT count(*) FROM shipment_outbox WHERE payload::jsonb->>'trackingCode'='$recoveryCode' AND published_at IS NULL") -eq 0 } 'confirmacion del outbox'
    Pass "RabbitMQ detenido: envio aceptado con outbox pendiente; al volver, $recoveryCode se procesa sin perdida."

    & $dockerPath @composeArgs restart catalog-db shipments-db messaging-db | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron reiniciar las bases de prueba' }
    foreach ($port in @(8081, 5000, 8084)) { Wait-Health $port }
    Assert-True ((Receipt-Count $demoCode) -eq 6 -and (Receipt-Count $recoveryCode) -eq 3) 'No persistieron los comprobantes'
    $persisted = Invoke-Db 'shipments-db' 'shipments_db' "SELECT estado FROM shipments WHERE codigo_seguimiento='$demoCode'"
    Assert-True ($persisted -eq 'ACEPTADO') 'No persistio el envio'
    $persistedCatalog = Invoke-Db 'catalog-db' 'catalog_db' "SELECT count(*) FROM catalogo WHERE id=$($service.id)"
    Assert-True ([int]$persistedCatalog -eq 1) 'No persistio el catalogo'
    Pass 'Reinicio de las tres bases PostgreSQL: catalogo, envios y comprobantes conservan los datos.'
}

$evidenceDirectory = Join-Path $PSScriptRoot 'evidencias'
$null = New-Item -ItemType Directory -Path $evidenceDirectory -Force
$report = @('# EV2 - evidencia de prueba local', '', ('Fecha: ' + (Get-Date -Format o)), '', 'Proyecto Docker: rutaexpress-ev2. Datos de demostracion, sin correos reales ni envio externo de mensajes.', '')
$report += $evidence.ToArray()
$report += @('', 'Pendiente: login institucional Azure, JWT real de ese tenant y despliegue cloud. Estas pruebas no certifican esos componentes.', '', 'Las DLQ conservan mensajes invalidos intencionales de esta prueba. No se eliminaron datos o volumenes anteriores.')
[IO.File]::WriteAllLines((Join-Path $evidenceDirectory 'EV2_PRUEBA_LOCAL.md'), $report, (New-Object Text.UTF8Encoding $false))
Write-Output 'Prueba EV2 completada. Evidencia guardada en evidencias/EV2_PRUEBA_LOCAL.md.'
