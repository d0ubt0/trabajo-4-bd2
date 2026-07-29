#!/usr/bin/env bash
set -euo pipefail

container="${1:-t4final_oracle}"
max_attempts="${2:-60}"

echo "Esperando Oracle en el contenedor ${container}..."

for attempt in $(seq 1 "$max_attempts"); do
  if docker exec "$container" bash -lc "echo 'SELECT 1 FROM dual;' | sqlplus -s bd2/bd2@localhost/FREEPDB1" >/dev/null 2>&1; then
    echo "Oracle esta listo."
    exit 0
  fi

  echo "Oracle aun no esta listo. Intento ${attempt}/${max_attempts}."
  sleep 10
done

echo "No fue posible conectar a Oracle dentro del tiempo esperado."
exit 1
