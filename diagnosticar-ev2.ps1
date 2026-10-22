param([switch]$GuardarInforme)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'scripts\Ev2.Configuration.psm1') -Force -DisableNameChecking
$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add('# Diagnostico EV2 (solo lectura)')
$lines.Add('')
$lines.Add('Fecha: ' + (Get-Date -Format o))
$lines.Add('No se incluyen valores de variables, tokens, datos personales, URLs cloud ni logs de aplicaciones.')
$lines.Add('')
$result = Test-Ev2Configuration -ShipmentsDirectory $PSScriptRoot
foreach ($check in $result.Checks) { $lines.Add('- ' + $check.State + ': ' + $check.Message) }
$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCommand) {
    $dockerPath = $dockerCommand.Source
    $null = & $dockerPath info --format '{{.ServerVersion}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $result.Ready) {
        $argsCompose = @('compose','-p','rutaexpress-ev2','--env-file',(Join-Path $PSScriptRoot '.env.ev2'),'-f',(Join-Path $PSScriptRoot 'compose.ev2.yml'))
        $statuses = & $dockerPath @argsCompose ps -a --format json 2>$null
        if ($LASTEXITCODE -eq 0) {
            $rows = @($statuses | ForEach-Object { $_ | ConvertFrom-Json })
            foreach ($row in $rows) { $lines.Add('- Contenedor ' + $row.Service + ': ' + $row.State + ' / ' + $row.Status) }
        } else { $lines.Add('- ERROR: no se pudo consultar el estado del stack.') }
        try { Wait-Ev2HttpServices -TimeoutSeconds 10; $lines.Add('- OK: frontend y cinco backends con health UP.') }
        catch { $lines.Add('- ERROR: ' + $_.Exception.Message) }
    } else { $lines.Add('- PENDIENTE: Docker sin respuesta o archivos con errores; no se consultaron contenedores.') }
} else { $lines.Add('- PENDIENTE: comando docker no disponible.') }
$lines.Add('')
$lines.Add('Pendiente de evidencia externa: login Duoc real, permisos Azure, API Manager y servicios EC2/RDS/RabbitMQ cloud.')
$lines.ToArray() | Write-Output
if ($GuardarInforme) {
    $folder = Join-Path $PSScriptRoot 'evidencias'
    $null = New-Item -ItemType Directory -Path $folder -Force
    $target = Join-Path $folder 'EV2_DIAGNOSTICO_LOCAL.md'
    [IO.File]::WriteAllLines($target, $lines.ToArray(), (New-Object Text.UTF8Encoding $false))
    Write-Output 'Informe local guardado en evidencias/EV2_DIAGNOSTICO_LOCAL.md.'
}
