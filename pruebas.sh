#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORACLE_RESULTS="$ROOT_DIR/report/resultados/oracle"
POSTGRES_RESULTS="$ROOT_DIR/report/resultados/postgres"

mkdir -p "$ORACLE_RESULTS" "$POSTGRES_RESULTS"

SAMPLES=(
  "100 1000 1000"
  "500 5000 5000"
  "1000 10000 10000"
  "2000 20000 25000"
)

if [[ "${RUN_LARGE:-0}" == "1" ]]; then
  SAMPLES+=("5000 50000 50000")
fi

run_oracle_sql() {
  local script_path="$1"
  local output_path="$2"
  docker exec -i t4final_oracle sqlplus -s bd2/bd2@localhost/FREEPDB1 @"$script_path" > "$output_path"
}

run_postgres_sql() {
  local script_path="$1"
  local output_path="$2"
  docker exec -i t4final_postgres psql -U bd2 -d bd2 -f "$script_path" > "$output_path" 2>&1
}

copy_sql_to_containers() {
  docker exec t4final_oracle mkdir -p /tmp/trabajo/sql/oracle
  docker exec t4final_postgres mkdir -p /tmp/trabajo/sql/postgres
  docker cp "$ROOT_DIR/sql/oracle/." t4final_oracle:/tmp/trabajo/sql/oracle/
  docker cp "$ROOT_DIR/sql/postgres/." t4final_postgres:/tmp/trabajo/sql/postgres/
}

run_oracle_sample() {
  local providers="$1"
  local products="$2"
  local relations="$3"
  local sample_name="${providers}prov_${relations}rel"
  local load_file="$ROOT_DIR/oracle_load_${sample_name}.sql"

  cat > "$load_file" <<SQL
SET SERVEROUTPUT ON
SET TIMING ON
CALL cargar_datos_aleatorios(${providers}, ${products}, ${relations});
SELECT COUNT(*) AS total_proveedores FROM Prov;
SELECT COUNT(*) AS total_relaciones FROM ProvxProd;
EXIT
SQL

  docker cp "$load_file" t4final_oracle:/tmp/trabajo/sql/oracle/load_sample.sql
  docker exec -i t4final_oracle sqlplus -s bd2/bd2@localhost/FREEPDB1 @/tmp/trabajo/sql/oracle/load_sample.sql > "$ORACLE_RESULTS/${sample_name}_carga.txt"

  run_oracle_sql "/tmp/trabajo/sql/oracle/03_consultas.sql" "$ORACLE_RESULTS/${sample_name}_consultas.txt"
  run_oracle_sql "/tmp/trabajo/sql/oracle/04_explain_plan.sql" "$ORACLE_RESULTS/${sample_name}_explain_plan.txt"
  run_oracle_sql "/tmp/trabajo/sql/oracle/05_tkprof_setup.sql" "$ORACLE_RESULTS/${sample_name}_trace_sqlplus.txt"
  run_oracle_sql "/tmp/trabajo/sql/oracle/06_metricas.sql" "$ORACLE_RESULTS/${sample_name}_metricas.txt"

  docker exec t4final_oracle bash -lc "trace=\$(find /opt/oracle/diag -name '*BD2_TRABAJO4*.trc' | tail -1); if [ -n \"\$trace\" ]; then tkprof \"\$trace\" /tmp/${sample_name}_tkprof.txt sort=exeela,fchela; fi" || true
  docker cp "t4final_oracle:/tmp/${sample_name}_tkprof.txt" "$ORACLE_RESULTS/${sample_name}_tkprof.txt" >/dev/null 2>&1 || true
}

run_postgres_sample() {
  local providers="$1"
  local products="$2"
  local relations="$3"
  local sample_name="${providers}prov_${relations}rel"
  local load_file="$ROOT_DIR/postgres_load_${sample_name}.sql"

  cat > "$load_file" <<SQL
\timing on
CALL cargar_datos_aleatorios(${providers}, ${products}, ${relations});
SELECT COUNT(*) AS total_proveedores FROM Prov;
SELECT COUNT(*) AS total_relaciones FROM ProvxProd;
SQL

  docker cp "$load_file" t4final_postgres:/tmp/trabajo/sql/postgres/load_sample.sql
  run_postgres_sql "/tmp/trabajo/sql/postgres/load_sample.sql" "$POSTGRES_RESULTS/${sample_name}_carga.txt"
  run_postgres_sql "/tmp/trabajo/sql/postgres/03_consultas.sql" "$POSTGRES_RESULTS/${sample_name}_consultas.txt"
  run_postgres_sql "/tmp/trabajo/sql/postgres/04_explain_analyze.sql" "$POSTGRES_RESULTS/${sample_name}_explain_analyze.txt"
  run_postgres_sql "/tmp/trabajo/sql/postgres/05_metricas.sql" "$POSTGRES_RESULTS/${sample_name}_metricas.txt"
}

echo "Levantando contenedores..."
docker compose up -d

"$ROOT_DIR/scripts/wait-for-oracle.sh" t4final_oracle 80
"$ROOT_DIR/scripts/wait-for-postgres.sh" t4final_postgres 60

copy_sql_to_containers

echo "Otorgando privilegios necesarios en Oracle..."
docker exec -i t4final_oracle sqlplus -s "sys/oracle@localhost/FREEPDB1 as sysdba" > "$ORACLE_RESULTS/00_privilegios.txt" <<SQL
GRANT ALTER SESSION TO bd2;
EXIT
SQL

echo "Creando esquema y procedimientos en Oracle..."
run_oracle_sql "/tmp/trabajo/sql/oracle/01_schema.sql" "$ORACLE_RESULTS/00_schema.txt"
run_oracle_sql "/tmp/trabajo/sql/oracle/02_carga_datos.sql" "$ORACLE_RESULTS/00_carga_procedure.txt"

echo "Creando esquema y procedimiento en PostgreSQL..."
run_postgres_sql "/tmp/trabajo/sql/postgres/01_schema.sql" "$POSTGRES_RESULTS/00_schema.txt"
run_postgres_sql "/tmp/trabajo/sql/postgres/02_carga_datos.sql" "$POSTGRES_RESULTS/00_carga_procedure.txt"

for sample in "${SAMPLES[@]}"; do
  read -r providers products relations <<< "$sample"
  echo "Ejecutando muestra: proveedores=${providers}, productos=${products}, relaciones=${relations}"
  run_oracle_sample "$providers" "$products" "$relations"
  run_postgres_sample "$providers" "$products" "$relations"
done

echo "Pruebas finalizadas."
echo "Resultados Oracle: $ORACLE_RESULTS"
echo "Resultados PostgreSQL: $POSTGRES_RESULTS"
