$ErrorActionPreference = 'Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Ev2.Configuration.psm1') -Force -DisableNameChecking
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('rutaexpress-config-tests-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $sandbox
$utf8 = New-Object Text.UTF8Encoding $false
$script:passed = 0
$script:fixtureNumber = 0
$script:testSecret = 'Fictitious_Test_Secret_Not_For_Real_Use_456'

function Assert-Test([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function New-Fixture {
    $script:fixtureNumber++
    $directory = Join-Path $sandbox $script:fixtureNumber
    foreach ($repo in @('frontend-rutaexpress','ms-rutaexpress-bff','ms-rutaexpress-catalogo',
            'ms-rutaexpress-envios','ms-rutaexpress-mensajeria','ms-rutaexpress-reportes')) {
        $folder = Join-Path $directory $repo
        $null = New-Item -ItemType Directory -Path $folder -Force
        [IO.File]::WriteAllText((Join-Path $folder 'Dockerfile'), '# disposable test fixture', $utf8)
    }
    $shipments = Join-Path $directory 'ms-rutaexpress-envios'
    [IO.File]::WriteAllText((Join-Path $shipments 'compose.ev2.yml'), 'name: rutaexpress-ev2', $utf8)
    $envFile = Join-Path $shipments '.env.ev2'
    $settings = @(
        ('CATALOG_DB_PASSWORD=' + $script:testSecret), ('SHIPMENTS_DB_PASSWORD=' + $script:testSecret),
        ('MESSAGING_DB_PASSWORD=' + $script:testSecret), ('RABBITMQ_PASSWORD=' + $script:testSecret),
        ('RABBITMQ_ERLANG_COOKIE=' + $script:testSecret),
        'COGNITO_ISSUER_URI=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_ExamplePool',
        'COGNITO_CLIENT_ID=abcdefghijklmnopqrstuvw123', 'AZURE_ENABLED=false'
    )
    [IO.File]::WriteAllLines($envFile, $settings, $utf8)
    $public = Join-Path (Join-Path $directory 'frontend-rutaexpress') 'public'
    $null = New-Item -ItemType Directory -Path $public
    $json = Join-Path $public 'azure-config.json'
    [IO.File]::WriteAllText($json, '{"enabled":false}', $utf8)
    return [pscustomobject]@{Root=$directory;Shipments=$shipments;Env=$envFile;Json=$json}
}
function Set-FixtureEnv($Fixture, [string]$Name, [string]$Value) {
    $lines = @([IO.File]::ReadAllLines($Fixture.Env) | Where-Object { $_ -notmatch ('^' + [regex]::Escape($Name) + '=') })
    $lines += $Name + '=' + $Value
    [IO.File]::WriteAllLines($Fixture.Env, $lines, $utf8)
}
function Enable-FixtureAzure($Fixture) {
    $config = [ordered]@{
        enabled=$true; tenantId='11111111-1111-4111-8111-111111111111'
        clientId='22222222-2222-4222-8222-222222222222'; apiClientId='33333333-3333-4333-8333-333333333333'
        scope='operator.access'; redirectPath='/auth/azure'
    }
    Set-FixtureEnv $Fixture 'AZURE_ENABLED' 'true'
    Set-FixtureEnv $Fixture 'AZURE_TENANT_ID' $config.tenantId
    Set-FixtureEnv $Fixture 'AZURE_SPA_CLIENT_ID' $config.clientId
    Set-FixtureEnv $Fixture 'AZURE_API_CLIENT_ID' $config.apiClientId
    Set-FixtureEnv $Fixture 'AZURE_OPERATOR_SCOPE' $config.scope
    [IO.File]::WriteAllText($Fixture.Json, ($config | ConvertTo-Json), $utf8)
    return $config
}
function Run-Test([string]$Name, [scriptblock]$Body) {
    $fixture = New-Fixture
    & $Body $fixture
    $script:passed++
    Write-Output ('OK: ' + $Name)
}
try {
    Run-Test 'Azure deshabilitado permite revision local sin certificar identidad' {
        param($f)
        $r = Test-Ev2Configuration $f.Shipments
        Assert-Test $r.Ready 'La configuracion local valida fue rechazada'
        Assert-Test (-not $r.AzureConfigured) 'Se simulo Azure'
        Assert-Test (@($r.Checks | Where-Object State -eq 'PENDIENTE').Count -eq 1) 'Falta aviso de Azure pendiente'
    }
    Run-Test 'ExigirAzure no acepta modo solo local' {
        param($f)
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments -RequireAzure).Ready) 'No se exigio Azure'
    }
    Run-Test 'Detecta carpeta faltante sin tocar repositorios reales' {
        param($f)
        $null = Rename-Item -LiteralPath (Join-Path $f.Root 'ms-rutaexpress-reportes') -NewName 'report-missing'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'No detecto el repo ausente'
    }
    Run-Test 'Detecta env ausente' {
        param($f)
        $null = Rename-Item -LiteralPath $f.Env -NewName '.env.missing'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'No detecto env ausente'
    }
    Run-Test 'Rechaza variables duplicadas sin revelar valores' {
        param($f)
        [IO.File]::AppendAllText($f.Env, [Environment]::NewLine + 'RABBITMQ_PASSWORD=' + $script:testSecret, $utf8)
        $r = Test-Ev2Configuration $f.Shipments
        Assert-Test (-not $r.Ready) 'Se acepto variable duplicada'
        Assert-Test (($r | ConvertTo-Json -Depth 5) -notlike ('*' + $script:testSecret + '*')) 'Se filtro una contrasena'
    }
    Run-Test 'Rechaza una linea env malformada' {
        param($f)
        [IO.File]::AppendAllText($f.Env, [Environment]::NewLine + 'invalid entry', $utf8)
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto linea invalida'
    }
    foreach ($name in @('CATALOG_DB_PASSWORD','SHIPMENTS_DB_PASSWORD','MESSAGING_DB_PASSWORD','RABBITMQ_PASSWORD','RABBITMQ_ERLANG_COOKIE')) {
        Run-Test ("Detecta variable vacia: " + $name) {
            param($f)
            Set-FixtureEnv $f $name ''
            Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto variable vacia'
        }
    }
    Run-Test 'Detecta contrasena debil' {
        param($f)
        Set-FixtureEnv $f 'RABBITMQ_PASSWORD' 'short'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto contrasena demasiado corta'
    }
    Run-Test 'Detecta marcador de ejemplo' {
        param($f)
        Set-FixtureEnv $f 'CATALOG_DB_PASSWORD' 'CAMBIAR_POR_PASSWORD_REAL'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto marcador de plantilla'
    }
    Run-Test 'Rechaza emisor Cognito no configurado' {
        param($f)
        Set-FixtureEnv $f 'COGNITO_ISSUER_URI' 'https://untrusted.example/pool'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto emisor incorrecto'
    }
    Run-Test 'Rechaza App Client de ejemplo' {
        param($f)
        Set-FixtureEnv $f 'COGNITO_CLIENT_ID' 'TU_APP_CLIENT_ID'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto client de ejemplo'
    }
    foreach ($badJson in @('{broken', '{"enabled":"false"}', '{}')) {
        Run-Test 'Rechaza JSON o enabled mal tipado' {
            param($f)
            [IO.File]::WriteAllText($f.Json, $badJson, $utf8)
            Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto JSON invalido'
        }
    }
    Run-Test 'Rechaza Azure habilitado solo en frontend' {
        param($f)
        [IO.File]::WriteAllText($f.Json, '{"enabled":true}', $utf8)
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'No detecto desalineacion frontend'
    }
    Run-Test 'Rechaza Azure habilitado solo en backend' {
        param($f)
        Set-FixtureEnv $f 'AZURE_ENABLED' 'true'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'No detecto desalineacion backend'
    }
    Run-Test 'Acepta Azure coherente sin afirmar login remoto' {
        param($f)
        $null = Enable-FixtureAzure $f
        $r = Test-Ev2Configuration $f.Shipments -RequireAzure
        Assert-Test ($r.Ready -and $r.AzureConfigured) 'Se rechazo Azure coherente'
    }
    Run-Test 'Rechaza tenant distinto entre archivos' {
        param($f)
        $null = Enable-FixtureAzure $f
        Set-FixtureEnv $f 'AZURE_TENANT_ID' '44444444-4444-4444-8444-444444444444'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'No detecto tenant distinto'
    }
    Run-Test 'Rechaza UUID vacio' {
        param($f)
        $c = Enable-FixtureAzure $f
        $c.clientId = [guid]::Empty.ToString()
        [IO.File]::WriteAllText($f.Json, ($c | ConvertTo-Json), $utf8)
        Set-FixtureEnv $f 'AZURE_SPA_CLIENT_ID' $c.clientId
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto UUID vacio'
    }
    Run-Test 'Rechaza scope distinto' {
        param($f)
        $null = Enable-FixtureAzure $f
        Set-FixtureEnv $f 'AZURE_OPERATOR_SCOPE' 'another.permission'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'No detecto scope distinto'
    }
    Run-Test 'Rechaza callback externo o incorrecto' {
        param($f)
        $c = Enable-FixtureAzure $f
        $c.redirectPath = 'https://untrusted.example/'
        [IO.File]::WriteAllText($f.Json, ($c | ConvertTo-Json), $utf8)
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto callback incorrecto'
    }
    Run-Test 'No permite client secret en frontend publico' {
        param($f)
        [IO.File]::WriteAllText($f.Json, '{"enabled":false,"clientSecret":"test-only"}', $utf8)
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto secreto publico'
    }
    Run-Test 'No requiere credenciales AWS en el stack local' {
        param($f)
        Set-FixtureEnv $f 'AWS_SECRET_ACCESS_KEY' 'fictitious-test-value'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto credencial innecesaria'
    }
    Run-Test 'Rechaza override de claves Azure en arranque estandar' {
        param($f)
        Set-FixtureEnv $f 'AZURE_JWK_SET_URI' 'http://localhost/test-keys'
        Assert-Test (-not (Test-Ev2Configuration $f.Shipments).Ready) 'Se acepto override de pruebas'
    }
    Run-Test 'Lee comillas y trata codigo env como texto, sin ejecutarlo' {
        param($f)
        Set-FixtureEnv $f 'EXTRA_TEST_VALUE' "'literal text'"
        $settings = Read-Ev2Settings $f.Env
        Assert-Test ($settings.EXTRA_TEST_VALUE -eq 'literal text') 'No retiro comillas'
        Set-FixtureEnv $f 'EXTRA_TEST_VALUE' ('$' + '(throw "must not execute")')
        $settings = Read-Ev2Settings $f.Env
        Assert-Test ($settings.EXTRA_TEST_VALUE.StartsWith('$')) 'No conservo texto literal'
    }
    Run-Test 'Script Azure alinea configuracion y conserva contrasenas; es idempotente' {
        param($f)
        $source = Split-Path -Parent $PSScriptRoot
        $scriptsFolder = Join-Path $f.Shipments 'scripts'
        $null = New-Item -ItemType Directory -Path $scriptsFolder
        foreach ($name in @('configurar-azure.ps1','comprobar-ev2.ps1')) {
            Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $f.Shipments $name)
        }
        Copy-Item -LiteralPath (Join-Path $source 'scripts\Ev2.Configuration.psm1') -Destination $scriptsFolder
        $configure = Join-Path $f.Shipments 'configurar-azure.ps1'
        $argsAzure = @{ TenantId='11111111-1111-4111-8111-111111111111'; FrontendClientId='22222222-2222-4222-8222-222222222222'; ApiClientId='33333333-3333-4333-8333-333333333333' }
        $beforeEnv = (Get-FileHash -LiteralPath $f.Env).Hash
        $beforeJson = (Get-FileHash -LiteralPath $f.Json).Hash
        $null = & $configure @argsAzure -SoloValidar
        Assert-Test ($beforeEnv -eq (Get-FileHash -LiteralPath $f.Env).Hash -and $beforeJson -eq (Get-FileHash -LiteralPath $f.Json).Hash) 'SoloValidar modifico archivos'
        $null = & $configure @argsAzure
        $settings = Read-Ev2Settings $f.Env
        Assert-Test ($settings.CATALOG_DB_PASSWORD -eq $script:testSecret) 'Se cambio contrasena existente'
        Assert-Test (Test-Ev2Configuration $f.Shipments -RequireAzure).Ready 'No quedo configuracion coherente'
        $hash = (Get-FileHash -LiteralPath $f.Env).Hash
        $null = & $configure @argsAzure
        Assert-Test ($hash -eq (Get-FileHash -LiteralPath $f.Env).Hash) 'La repeticion no fue idempotente'
    }
    Run-Test 'Destino API local predeterminado valido' {
        param($f)
        Assert-Test (Test-Ev2ApiUpstream 'http://bff:8080') 'Se rechazo el BFF local'
    }
    foreach ($url in @('https://api.example.test', 'https://api.example.test/prod', 'https://api.example.test:443/prod/v1')) {
        Run-Test 'Admite origen API HTTPS y stage sin hacer llamadas externas' {
            param($f)
            Set-FixtureEnv $f 'FRONTEND_API_UPSTREAM' $url
            Assert-Test (Test-Ev2Configuration $f.Shipments).Ready 'Se rechazo destino HTTPS valido'
        }
    }
    foreach ($url in @('http://api.example.test', 'https://name:password@api.example.test',
            'https://api.example.test?key=secret', 'https://api.example.test/#fragment',
            'https://api.example.test/', 'https://api.example.test;injection',
            'https://api.example.test/$variable', ('https://api.example.test' + [Environment]::NewLine))) {
        Run-Test 'Rechaza API externa insegura o con parametros/inyeccion' {
            param($f)
            Assert-Test (-not (Test-Ev2ApiUpstream $url)) 'Se acepto un destino API inseguro'
        }
    }
    Run-Test 'Script de conexion API conserva secretos y permite volver al BFF local' {
        param($f)
        $source = Split-Path -Parent $PSScriptRoot
        $scriptsFolder = Join-Path $f.Shipments 'scripts'
        $null = New-Item -ItemType Directory -Path $scriptsFolder
        Copy-Item -LiteralPath (Join-Path $source 'scripts\Ev2.Configuration.psm1') -Destination $scriptsFolder
        Copy-Item -LiteralPath (Join-Path $source 'configurar-api.ps1') -Destination $f.Shipments
        $configure = Join-Path $f.Shipments 'configurar-api.ps1'
        $before = (Get-FileHash -LiteralPath $f.Env).Hash
        $null = & $configure -UrlApi 'https://api.example.test/prod/' -SoloValidar
        Assert-Test ($before -eq (Get-FileHash -LiteralPath $f.Env).Hash) 'SoloValidar cambio el destino'
        $null = & $configure -UrlApi 'https://api.example.test/prod/'
        $settings = Read-Ev2Settings $f.Env
        Assert-Test ($settings.FRONTEND_API_UPSTREAM -eq 'https://api.example.test/prod') 'No normalizo el stage'
        Assert-Test ($settings.RABBITMQ_PASSWORD -eq $script:testSecret) 'Se cambio una contrasena'
        $null = & $configure -Local
        Assert-Test ((Read-Ev2Settings $f.Env).FRONTEND_API_UPSTREAM -eq 'http://bff:8080') 'No restauro el BFF local'
    }
    $parseErrors = $null; $parseTokens = $null
    $smokeAst = [Management.Automation.Language.Parser]::ParseFile(
        (Join-Path (Split-Path -Parent $PSScriptRoot) 'probar-ev2.ps1'), [ref]$parseTokens, [ref]$parseErrors)
    Assert-Test ($parseErrors.Count -eq 0) 'Error de sintaxis en prueba local'
    # Exercise the real parameter binder without executing Docker or the smoke body.
    $projectBinder = [scriptblock]::Create($smokeAst.ParamBlock.Extent.Text + "`nreturn `$Proyecto")
    foreach ($project in @('rutaexpress-ev2','rutaexpress-ev2-prueba-limpia')) {
        Run-Test 'Smoke admite solamente el stack local o un proyecto de prueba explicito' {
            param($f)
            Assert-Test ((& $projectBinder -Proyecto $project) -eq $project) 'Proyecto local valido rechazado'
        }
    }
    foreach ($project in @('rutaexpress-ev2-aws','otro-proyecto','rutaexpress-ev2;injection')) {
        Run-Test 'Smoke rechaza proyectos AWS, ajenos o con inyeccion antes de ejecutar Docker' {
            param($f)
            $rejected = $false
            try { $null = & $projectBinder -Proyecto $project } catch { $rejected = $true }
            Assert-Test $rejected 'Proyecto peligroso aceptado'
        }
    }
    Write-Output ("Pruebas de configuracion: {0} correctas. No se modificaron archivos reales ni servicios." -f $script:passed)
} finally {
    # Only remove the exact disposable directory created above, after validating its parent/name.
    $resolved = [IO.Path]::GetFullPath($sandbox)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ((Split-Path -Parent $resolved).TrimEnd([IO.Path]::DirectorySeparatorChar) -eq $tempRoot -and
            (Split-Path -Leaf $resolved) -match '^rutaexpress-config-tests-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    } else { throw 'No se borro el directorio temporal: su ruta no paso la validacion de seguridad.' }
}
exit 0
