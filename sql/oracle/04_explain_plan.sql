SET LINESIZE 220
SET PAGESIZE 200

DELETE FROM PLAN_TABLE;

PROMPT Explain Plan - Consulta 1
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_NOT_EXISTS' FOR
SELECT p1.nit AS Nitprov1, p1.nombre AS NombreProv1,
       p2.nit AS Nitprov2, p2.nombre AS NombreProv2
FROM Prov p1
JOIN Prov p2 ON p1.nit < p2.nit
WHERE NOT EXISTS (
        SELECT 1 FROM ProvxProd x1
        WHERE x1.nit = p1.nit
          AND NOT EXISTS (
            SELECT 1 FROM ProvxProd x2
            WHERE x2.nit = p2.nit
              AND x2.codigoProducto = x1.codigoProducto
          )
      )
  AND NOT EXISTS (
        SELECT 1 FROM ProvxProd y2
        WHERE y2.nit = p2.nit
          AND NOT EXISTS (
            SELECT 1 FROM ProvxProd y1
            WHERE y1.nit = p1.nit
              AND y1.codigoProducto = y2.codigoProducto
          )
      );
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1_NOT_EXISTS', 'BASIC +COST +BYTES'));

PROMPT Explain Plan - Consulta 2
EXPLAIN PLAN SET STATEMENT_ID = 'Q2_LISTAGG' FOR
WITH conjuntos AS (
  SELECT p.nit, p.nombre,
         COALESCE(LISTAGG(x.codigoProducto, ',') WITHIN GROUP (ORDER BY x.codigoProducto), 'SIN_PRODUCTOS') AS firma
  FROM Prov p LEFT JOIN ProvxProd x ON x.nit = p.nit
  GROUP BY p.nit, p.nombre
)
SELECT c1.nit AS Nitprov1, c1.nombre AS NombreProv1,
       c2.nit AS Nitprov2, c2.nombre AS NombreProv2
FROM conjuntos c1 JOIN conjuntos c2 ON c1.nit < c2.nit AND c1.firma = c2.firma;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q2_LISTAGG', 'BASIC +COST +BYTES'));

PROMPT Explain Plan - Consulta 3
EXPLAIN PLAN SET STATEMENT_ID = 'Q3_COUNTS' FOR
WITH total_productos AS (
  SELECT p.nit, p.nombre, COUNT(x.codigoProducto) AS total
  FROM Prov p LEFT JOIN ProvxProd x ON x.nit = p.nit
  GROUP BY p.nit, p.nombre
),
productos_comunes AS (
  SELECT p1.nit AS nit1, p2.nit AS nit2, COUNT(x1.codigoProducto) AS comunes
  FROM Prov p1
  JOIN Prov p2 ON p1.nit < p2.nit
  LEFT JOIN ProvxProd x1 ON x1.nit = p1.nit
  LEFT JOIN ProvxProd x2 ON x2.nit = p2.nit AND x2.codigoProducto = x1.codigoProducto
  WHERE x1.codigoProducto IS NULL OR x2.codigoProducto IS NOT NULL
  GROUP BY p1.nit, p2.nit
)
SELECT t1.nit AS Nitprov1, t1.nombre AS NombreProv1,
       t2.nit AS Nitprov2, t2.nombre AS NombreProv2
FROM total_productos t1
JOIN total_productos t2 ON t1.nit < t2.nit
JOIN productos_comunes pc ON pc.nit1 = t1.nit AND pc.nit2 = t2.nit
WHERE t1.total = t2.total AND pc.comunes = t1.total;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q3_COUNTS', 'BASIC +COST +BYTES'));

PROMPT Explain Plan - Consulta 4
EXPLAIN PLAN SET STATEMENT_ID = 'Q4_MINUS' FOR
SELECT p1.nit AS Nitprov1, p1.nombre AS NombreProv1,
       p2.nit AS Nitprov2, p2.nombre AS NombreProv2
FROM Prov p1
JOIN Prov p2 ON p1.nit < p2.nit
WHERE NOT EXISTS (
        SELECT codigoProducto FROM ProvxProd WHERE nit = p1.nit
        MINUS
        SELECT codigoProducto FROM ProvxProd WHERE nit = p2.nit
      )
  AND NOT EXISTS (
        SELECT codigoProducto FROM ProvxProd WHERE nit = p2.nit
        MINUS
        SELECT codigoProducto FROM ProvxProd WHERE nit = p1.nit
      );
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q4_MINUS', 'BASIC +COST +BYTES'));
