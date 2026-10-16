#!/usr/bin/env bash
# Solo consultas HTTP internas; no muestra cuerpos, claves ni datos personales.
# Requiere el backend AWS ya iniciado y la imagen BFF construida, con bash/coreutils.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
docker compose -p rutaexpress-ev2-aws --env-file .env.aws -f compose.aws.yml run --rm --no-deps \
  --entrypoint /usr/bin/timeout bff 40 /bin/bash -c '
set -euo pipefail
for target in bff:8080 catalog:8081 shipments:5000 messaging:8084 report:8082; do
  if ! exec 3<>/dev/tcp/"${target%:*}"/"${target##*:}"; then
    printf "ERROR: %s no responde. Revisar arranque/red localmente.\n" "$target"
    exit 1
  fi
  printf "GET /actuator/health HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n" "$target" >&3
  response=$(cat <&3)
  exec 3<&- 3>&-
  if [[ "$response" =~ ^HTTP/[0-9.]+[[:space:]]200[[:space:]] ]] &&
     [[ "$response" =~ \"status\"[[:space:]]*:[[:space:]]*\"UP\" ]]; then
    printf "OK: %s HTTP 200, estado UP (sin detalles).\n" "$target"
  else
    printf "ERROR: %s sin salud UP. Revisar RDS/TLS/Rabbit/arranque, sin compartir logs privados.\n" "$target"
    exit 1
  fi
done
'
