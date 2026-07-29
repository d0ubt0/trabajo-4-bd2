SET LINESIZE 220
SET PAGESIZE 200

PROMPT Consulta auxiliar para revisar SQL ejecutado recientemente por el usuario BD2.
PROMPT Las columnas ayudan a calcular: LIOs=(buffer_gets), lecturas disco=disk_reads, filas=rows_processed, fetches=fetches.

SELECT sql_id,
       executions,
       fetches,
       rows_processed,
       buffer_gets,
       disk_reads,
       elapsed_time,
       ROUND(buffer_gets / NULLIF(rows_processed, 0), 4) AS lios_sobre_filas,
       ROUND(rows_processed / NULLIF(fetches, 0), 4) AS filas_sobre_fetches,
       ROUND(disk_reads / NULLIF(buffer_gets, 0), 4) AS disco_sobre_lios,
       SUBSTR(sql_text, 1, 90) AS sql_texto
FROM v$sql
WHERE parsing_schema_name = 'BD2'
  AND UPPER(sql_text) LIKE 'SELECT P1.NIT%'
ORDER BY last_active_time DESC;
