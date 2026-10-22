param(
    [switch]$SoloArchivos,
    [switch]$ExigirAzure,
    [switch]$EnEjecucion,
    [ValidateRange(5,600)][int]$TiempoEsperaSegundos=30
)
$ErrorActionPreference = 'Stop'
if ($SoloArchivos -and $EnEjecucion) { throw 'SoloArchivos y EnEjecucion son opciones excluyentes.' }
Import-Module (Join-Path $PSScriptRoot 'scripts\Ev2.Configuration.psm1') -Force -DisableNameChecking
$result = Test-Ev2Configuration -ShipmentsDirectory $PSScriptRoot -RequireAzure:$ExigirAzure
foreach ($check in $result.Checks) { Write-Output ("{0}: {1}" -f $check.State, $check.Message) }
if (-not $result.Ready) { throw 'Corrige los errores anteriores antes de iniciar. No se modifico ninguna configuracion.' }
if (-not $SoloArchivos) {
    $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerCommand) { throw 'Instala Docker Desktop y vuelve a abrir PowerShell.' }
    $dockerPath = $dockerCommand.Source
    $engine = & $dockerPath info --format '{{.OSType}}' 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Abre Docker Desktop y espera que su motor Linux este listo.' }
    if ($engine -ne 'linux') { throw 'El stack requiere contenedores Linux en Docker Desktop.' }
    $null = & $dockerPath compose version 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Se requiere Docker Compose v2 o posterior (docker compose).' }
    $null = & $dockerPath compose -p rutaexpress-ev2 --env-file (Join-Path $PSScriptRoot '.env.ev2') -f (Join-Path $PSScriptRoot 'compose.ev2.yml') config --quiet 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose rechazo la configuracion. Revisa los archivos localmente sin compartir contrasenas.' }
    Write-Output 'OK: Docker Linux, Compose y configuracion del stack disponibles.'
    if ($EnEjecucion) {
        Wait-Ev2HttpServices -TimeoutSeconds $TiempoEsperaSegundos
        Write-Output 'OK: Frontend y cinco backends responden health UP. Esto no prueba login ni despliegue cloud.'
    }
}
Write-Output 'Comprobacion local terminada sin mostrar secretos ni cambiar contenedores.'
