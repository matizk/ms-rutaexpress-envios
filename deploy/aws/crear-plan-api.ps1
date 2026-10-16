#Requires -Version 7.2
[CmdletBinding()]
param([string]$Configuracion=(Join-Path $PSScriptRoot 'api-config.json'), [switch]$Generar)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/Aws.Deployment.psm1') -Force -DisableNameChecking
try {
    $config = Get-Content -LiteralPath $Configuracion -Raw | ConvertFrom-Json -ErrorAction Stop
} catch { throw 'No se pudo leer api-config.json. Copiar y completar api-config.json.example; nunca agregar secretos.' }
$validation=Test-AwsApiConfiguration $config
if (-not $validation.Ready) { $validation.Errors | Write-Output; throw 'Plan incompleto: no se creo ningun recurso ni archivo de salida.' }
if (-not $Generar) {
    'Configuracion API valida localmente. No se consulto ni modifico AWS. Usar -Generar para guardar la plantilla.'
    return
}
$target=Join-Path $PSScriptRoot 'apigateway.generated.json'
if (Test-Path -LiteralPath $target) { throw 'Ya existe apigateway.generated.json; conservarlo o renombrarlo antes de generar otro plan.' }
$template=New-AwsApiTemplate $config
[IO.File]::WriteAllText($target, ($template | ConvertTo-Json -Depth 25), [Text.UTF8Encoding]::new($false))
'Plantilla apigateway.generated.json creada LOCALMENTE. No se desplego; revisar costos, red, permisos y rutas antes de usarla.'
