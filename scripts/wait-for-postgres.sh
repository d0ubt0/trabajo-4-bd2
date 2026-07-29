#!/usr/bin/env bash
set -euo pipefail

container="${1:-t4final_postgres}"
max_attempts="${2:-60}"

echo "Esperando PostgreSQL en el contenedor ${container}..."

for attempt in $(seq 1 "$max_attempts"); do
  if docker exec "$container" pg_isready -U bd2 -d bd2 >/dev/null 2>&1; then
    echo "PostgreSQL esta listo."
    exit 0
  fi

  echo "PostgreSQL aun no esta listo. Intento ${attempt}/${max_attempts}."
  sleep 3
done

echo "No fue posible conectar a PostgreSQL dentro del tiempo esperado."
exit 1
