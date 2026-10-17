#Requires -Version 7.2
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('rutaexpress-aws-files-'+[guid]::NewGuid().ToString('N'))
$base=Join-Path $temporary 'ms-rutaexpress-envios'
$aws=Join-Path $base 'deploy/aws'
$null=New-Item -ItemType Directory -Path $aws,(Join-Path $base 'scripts'),(Join-Path $aws 'certs') -Force
$script:passed=0
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Test([string]$Name,[scriptblock]$Body) { & $Body;$script:passed++;"OK: $Name" }
function Execute([string]$File,[string[]]$Arguments=@()) {
    $output=& (Get-Process -Id $PID).Path -NoProfile -File (Join-Path $aws $File) @Arguments 2>&1
    return [pscustomobject]@{Code=$LASTEXITCODE;Text=($output -join "`n")}
}
try {
    foreach ($script in @('crear-plan-api.ps1','comprobar-aws.ps1','probar-api-aws.ps1')) {
        Copy-Item -LiteralPath (Join-Path $repo "deploy/aws/$script") -Destination (Join-Path $aws $script)
    }
    foreach ($module in @('Aws.Deployment.psm1','Ev2.Configuration.psm1')) {
        Copy-Item -LiteralPath (Join-Path $repo "scripts/$module") -Destination (Join-Path $base "scripts/$module")
    }
    $config=Get-Content (Join-Path $repo 'deploy/aws/api-config.json.example') -Raw | ConvertFrom-Json
    $config.tenantId='11111111-1111-4111-8111-111111111111'
    $config.apiClientId='22222222-2222-4222-8222-222222222222'
    $config.spaClientId='33333333-3333-4333-8333-333333333333'
    $config.cognitoIssuer='https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool'
    $config.cognitoClientId='abcdefghijklmnopqrstuvw123'
    $config.vpcLinkId='abc123'
    $config.listenerArn='arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/test/123abc/456def'
    $configPath=Join-Path $aws 'api-config.json'
    [IO.File]::WriteAllText($configPath,($config | ConvertTo-Json))
    Test 'Generador sin switch solo valida, no escribe plantilla' {
        $r=Execute 'crear-plan-api.ps1'
        Assert ($r.Code -eq 0 -and -not (Test-Path (Join-Path $aws 'apigateway.generated.json'))) 'Validacion genero archivo/fallo'
    }
    Test 'Generador produce JSON CloudFormation sin llamar AWS' {
        $r=Execute 'crear-plan-api.ps1' @('-Generar')
        Assert ($r.Code -eq 0) 'No genero plan'
        $saved=Get-Content (Join-Path $aws 'apigateway.generated.json') -Raw | ConvertFrom-Json
        Assert ($saved.AWSTemplateFormatVersion -eq '2010-09-09') 'Formato incorrecto'
    }
    Test 'Generador protege plan existente de sobreescritura' {
        $before=(Get-FileHash (Join-Path $aws 'apigateway.generated.json')).Hash
        $r=Execute 'crear-plan-api.ps1' @('-Generar')
        Assert ($r.Code -ne 0 -and (Get-FileHash (Join-Path $aws 'apigateway.generated.json')).Hash -eq $before) 'Sobreescritura'
    }
    Test 'JSON con secreto no se imprime ni admite' {
        $config | Add-Member NoteProperty password 'PRIVATE_DO_NOT_PRINT_123456789'
        [IO.File]::WriteAllText($configPath,($config | ConvertTo-Json))
        $r=Execute 'crear-plan-api.ps1'
        Assert ($r.Code -ne 0 -and $r.Text -notmatch 'PRIVATE_DO_NOT_PRINT') 'Secreto admitido/impreso'
    }
    Test 'Probe rechaza URL no AWS antes de una llamada HTTP' {
        $r=Execute 'probar-api-aws.ps1' @('-UrlApi','https://not-an-aws-api.invalid')
        Assert ($r.Code -ne 0 -and $r.Text -match 'No se envio ningun token') 'Destino no rechazado'
    }
    Test 'Comprobador exige env privado, no inventa credenciales' {
        $r=Execute 'comprobar-aws.ps1' @('-SinDocker')
        Assert ($r.Code -ne 0 -and -not (Test-Path (Join-Path $aws '.env.aws'))) 'Creo archivo privado'
    }
    $settings=@(
        'RDS_HOST=fixture.abcdefgh.us-east-1.rds.amazonaws.com','BFF_BIND_ADDRESS=127.0.0.1',
        'CATALOG_DB_PASSWORD=CAT_012345678901234567890123456789','SHIPMENTS_DB_PASSWORD=SHP_012345678901234567890123456789',
        'MESSAGING_DB_PASSWORD=MSG_012345678901234567890123456789','RABBITMQ_PASSWORD=RAB_012345678901234567890123456789',
        'RABBITMQ_ERLANG_COOKIE=CKE_012345678901234567890123456789',
        'AZURE_TENANT_ID=11111111-1111-4111-8111-111111111111','AZURE_API_CLIENT_ID=22222222-2222-4222-8222-222222222222',
        'AZURE_SPA_CLIENT_ID=33333333-3333-4333-8333-333333333333','AZURE_OPERATOR_SCOPE=operator.access',
        'COGNITO_ISSUER_URI=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool','COGNITO_CLIENT_ID=abcdefghijklmnopqrstuvw123'
    )
    [IO.File]::WriteAllLines((Join-Path $aws '.env.aws'),$settings)
    Test 'Comprobador exige CA, no rebaja TLS' {
        $r=Execute 'comprobar-aws.ps1' @('-SinDocker')
        Assert ($r.Code -ne 0 -and $r.Text -match 'Falta certificado CA') 'CA ausente aceptada'
    }
    [IO.File]::WriteAllText((Join-Path $aws 'certs/global-bundle.pem'),'NOT_A_CERTIFICATE')
    Test 'Comprobador rechaza CA corrupta sin mostrar secretos' {
        $r=Execute 'comprobar-aws.ps1' @('-SinDocker')
        Assert ($r.Code -ne 0 -and $r.Text -match 'PEM valido' -and $r.Text -notmatch 'CAT_0123') 'CA corrupta/secreto'
    }
    $key=[Security.Cryptography.RSA]::Create(2048)
    try {
        $request=[Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=LOCAL_FIXTURE_NOT_AWS',$key,
            [Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $cert=$request.CreateSelfSigned([DateTimeOffset]::Now.AddMinutes(-1),[DateTimeOffset]::Now.AddDays(1))
        try { [IO.File]::WriteAllText((Join-Path $aws 'certs/global-bundle.pem'),$cert.ExportCertificatePem()) } finally { $cert.Dispose() }
    } finally { $key.Dispose() }
    foreach ($component in @('catalogo','envios','mensajeria','reportes','intermediario')) {
        $directory=Join-Path $temporary "ms-rutaexpress-$component"
        $null=New-Item -ItemType Directory -Path $directory -Force
        [IO.File]::WriteAllText((Join-Path $directory 'Dockerfile'),'# fixture')
    }
    Test 'Comprobador acepta archivos validos sin afirmar conexion real' {
        $r=Execute 'comprobar-aws.ps1' @('-SinDocker')
        $safe=$r.Text -replace '(?:CAT|SHP|MSG|RAB|CKE)_[0-9]+','[oculto]'
        Assert ($r.Code -eq 0 -and $r.Text -match 'PENDIENTE' -and $r.Text -notmatch 'CAT_0123') ('Falso resultado o secreto. '+$safe)
    }
    Test 'Comprobador rechaza override heredado sin mostrar su valor' {
        $previous=[Environment]::GetEnvironmentVariable('RDS_HOST','Process')
        try {
            [Environment]::SetEnvironmentVariable('RDS_HOST','PRIVATE_OVERRIDE_DO_NOT_PRINT','Process')
            $r=Execute 'comprobar-aws.ps1' @('-SinDocker')
            Assert ($r.Code -ne 0 -and $r.Text -match 'contradice' -and $r.Text -notmatch 'PRIVATE_OVERRIDE_DO_NOT_PRINT') 'Override aceptado/impreso'
        } finally { [Environment]::SetEnvironmentVariable('RDS_HOST',$previous,'Process') }
    }
} finally {
    $absolute=[IO.Path]::GetFullPath($temporary)
    $parent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
    if ((Split-Path -Parent $absolute).TrimEnd('\','/') -ne $parent -or (Split-Path -Leaf $absolute) -notmatch '^rutaexpress-aws-files-[a-f0-9]{32}$') {
        throw 'Destino temporal inesperado: limpieza detenida.'
    }
    Remove-Item -LiteralPath $absolute -Recurse -Force
}
"TOTAL: $script:passed pruebas de scripts en archivos efimeros aprobadas. Sin AWS ni credenciales reales."
# Las pruebas negativas dejan LASTEXITCODE=1 aunque sean correctas: cerrar con exito explicito.
exit 0
