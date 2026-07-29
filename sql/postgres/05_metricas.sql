\echo Metricas disponibles en PostgreSQL
\echo Para resultados comparables se usa EXPLAIN (ANALYZE, BUFFERS).
\echo Buffers shared hit equivale aproximadamente a lecturas logicas desde cache.
\echo Buffers shared read equivale a lecturas fisicas desde disco.
\echo Actual rows muestra filas procesadas/retornadas segun cada nodo del plan.

SELECT relname,
       heap_blks_read,
       heap_blks_hit,
       idx_blks_read,
       idx_blks_hit
FROM pg_statio_user_tables
WHERE relname IN ('prov', 'provxprod')
ORDER BY relname;
