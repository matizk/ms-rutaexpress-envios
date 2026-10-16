$ErrorActionPreference = 'Stop'
$docker = (Get-Command docker -ErrorAction Stop).Source
$image = 'rutaexpress-ev2-frontend:latest'
$passed = 0
$examples = @(
    @{Value='http://bff:8080';Valid=$true},
    @{Value='https://api.example.test';Valid=$true},
    @{Value='https://api.example.test/prod';Valid=$true},
    @{Value='https://api.example.test:443/prod/v1';Valid=$true},
    @{Value='http://api.example.test';Valid=$false},
    @{Value='https://name:fictitious@api.example.test';Valid=$false},
    @{Value='https://api.example.test?secret=fictitious';Valid=$false},
    @{Value='https://api.example.test/#fragment';Valid=$false},
    @{Value='https://api.example.test/';Valid=$false},
    @{Value='https://api.example.test;injection';Valid=$false},
    @{Value='https://api.example.test/$variable';Valid=$false},
    @{Value=('https://api.example.test' + [Environment]::NewLine);Valid=$false}
)
foreach ($example in $examples) {
    # This executes only input validation in an ephemeral container, not Nginx or a network request.
    $output = & $docker run --pull=never --rm --network none --entrypoint /docker-entrypoint.d/25-validate-upstream.sh --env ('BFF_UPSTREAM=' + $example.Value) $image 2>&1
    $accepted = $LASTEXITCODE -eq 0
    if ($accepted -ne $example.Valid) { throw 'El validador Docker no coincide con la politica esperada para un destino ficticio.' }
    if (($output -join ' ') -match 'name:fictitious|secret=fictitious') { throw 'El validador Docker revelo una URL sensible de prueba.' }
    $passed++
}
Write-Output ("Pruebas de proxy: {0} correctas; contenedores efimeros sin red, sin contactar dominios externos." -f $passed)
