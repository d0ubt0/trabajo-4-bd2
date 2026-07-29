# PostgreSQL

Archivos principales:

- `sql/postgres/01_schema.sql`: crea las tablas del enunciado.
- `sql/postgres/02_carga_datos.sql`: crea el procedimiento PL/pgSQL de carga aleatoria.
- `sql/postgres/03_consultas.sql`: contiene las cuatro consultas adaptadas a PostgreSQL.
- `sql/postgres/04_explain_analyze.sql`: ejecuta `EXPLAIN (ANALYZE, BUFFERS)`.
- `sql/postgres/05_metricas.sql`: muestra estadisticas basicas de bloques leidos y cacheados.

PostgreSQL no tiene TKPROF. Para este trabajo se usa `EXPLAIN (ANALYZE, BUFFERS)` como herramienta comparable para revisar tiempo real, filas procesadas y lecturas de buffers.
