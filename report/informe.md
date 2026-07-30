# Trabajo 4 de Bases de Datos 2

## Introduccion

El objetivo de este trabajo es resolver y comparar varias formas de una misma consulta SQL: obtener todas las parejas de proveedores que venden exactamente el mismo conjunto de productos. La solucion se desarrolla en Oracle y PostgreSQL, usando las mismas tablas y muestras de datos comparables.

El trabajo se hizo con Docker para que las pruebas puedan repetirse sin instalar manualmente los motores de base de datos en el sistema operativo.

## Objetivos

- Crear las tablas `Prov` y `ProvxProd` respetando la estructura del enunciado.
- Escribir cuatro consultas SQL distintas para resolver el problema.
- Crear un programa PL/SQL en Oracle que cargue datos aleatorios consistentes.
- Ejecutar pruebas con tamanos de muestra crecientes.
- Obtener Explain Plan y TKPROF en Oracle.
- Obtener metricas equivalentes en PostgreSQL mediante `EXPLAIN ANALYZE`.
- Comparar el comportamiento de las consultas en ambos motores.

## Modelo De Datos

La tabla `Prov` almacena proveedores:

```sql
Prov(nit, nombre)
```

La tabla `ProvxProd` almacena los productos que vende cada proveedor:

```sql
ProvxProd(nit, codigoProducto)
```

Restricciones:

- `Prov.nit` es clave primaria.
- `Prov.nombre` es unico.
- `(ProvxProd.nit, ProvxProd.codigoProducto)` es clave primaria compuesta.
- `ProvxProd.nit` es clave foranea hacia `Prov`.

No se agregaron columnas adicionales porque el enunciado indica que no debe modificarse la estructura.

## Metodologia

Las pruebas se ejecutan con Docker Compose. Se levantan dos contenedores:

- Oracle Free.
- PostgreSQL.

Para cada muestra se realiza este proceso:

1. Se eliminan los datos anteriores.
2. Se cargan proveedores.
3. Se cargan relaciones proveedor-producto aleatorias, evitando duplicados.
4. Se ejecutan las cuatro consultas.
5. En Oracle se genera Explain Plan.
6. En Oracle se activa traza SQL y se procesa con TKPROF.
7. En PostgreSQL se ejecuta `EXPLAIN (ANALYZE, BUFFERS)`.
8. Se guardan los resultados en archivos de texto.

Los tamanos de muestra propuestos son:

| Muestra | Proveedores | Productos posibles | Filas en ProvxProd |
|---|---:|---:|---:|
| 1 | 100 | 1.000 | 1.000 |
| 2 | 500 | 5.000 | 5.000 |
| 3 | 1.000 | 10.000 | 10.000 |
| 4 | 2.000 | 20.000 | 25.000 |
| 5 | 5.000 | 50.000 | 50.000 |

La muestra 5 es opcional porque puede tardar bastante en computadores personales. Para ejecutarla se usa `RUN_LARGE=1 ./pruebas.sh`.

Estos tamanos permiten empezar con datos pequenos y aumentar gradualmente hasta observar diferencias de rendimiento.

## Generacion De Datos

En Oracle se usa el procedimiento `cargar_datos_aleatorios`, escrito en PL/SQL. El procedimiento recibe:

- numero de proveedores;
- numero de productos posibles;
- numero de relaciones proveedor-producto.

Primero borra los datos anteriores, luego inserta proveedores con `nit` consecutivo y nombre unico. Despues genera pares aleatorios `(nit, codigoProducto)`. Si un par ya existe, se ignora y se intenta generar otro.

La clave foranea siempre es consistente porque los valores de `nit` se generan entre `1` y el numero de proveedores creados.

Tambien pueden quedar proveedores sin productos. Esto es correcto, porque el enunciado contempla el caso de proveedores con conjunto vacio de productos.

En PostgreSQL se implementa una version equivalente en PL/pgSQL para que las pruebas sean comparables.

## Explicacion De Las Cuatro Consultas

### Consulta 1: doble `NOT EXISTS`

Esta consulta compara cada pareja de proveedores `(p1, p2)`. La condicion exige dos cosas:

- que no exista un producto vendido por `p1` que no venda `p2`;
- que no exista un producto vendido por `p2` que no venda `p1`.

Si ambas condiciones se cumplen, los conjuntos son iguales.

Esta consulta es distinta porque usa subconsultas correlacionadas y expresa la igualdad como ausencia de diferencias.

### Consulta 2: agrupacion y firma del conjunto

Esta consulta crea una representacion textual del conjunto de productos de cada proveedor. En Oracle usa `LISTAGG`; en PostgreSQL usa `STRING_AGG`.

Los productos se ordenan antes de concatenarlos. Esto es importante porque los conjuntos `{100, 500}` y `{500, 100}` deben considerarse iguales.

Luego se comparan proveedores cuya firma sea igual.

Esta consulta es distinta porque transforma cada conjunto en un valor agrupado y luego compara esos valores.

### Consulta 3: conteos y productos comunes

Esta consulta calcula:

- cuantos productos vende cada proveedor;
- cuantos productos tienen en comun dos proveedores.

Dos proveedores venden el mismo conjunto si tienen la misma cantidad total de productos y todos los productos de uno aparecen en el otro.

Esta consulta es distinta porque se basa en agregaciones numericas y conteo de coincidencias, no en operadores de diferencia ni en concatenacion.

### Consulta 4: operadores de conjuntos

En Oracle se usa `MINUS`; en PostgreSQL se usa `EXCEPT`.

La idea es revisar que:

- productos de `p1` menos productos de `p2` sea vacio;
- productos de `p2` menos productos de `p1` sea vacio.

Si ambas diferencias son vacias, los conjuntos son iguales.

Esta consulta es distinta porque usa operadores de conjuntos propios del SQL.

## Explain Plan En Oracle

Para obtener el Explain Plan se usa:

```sql
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_NOT_EXISTS' FOR
SELECT ...

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1_NOT_EXISTS', 'BASIC +COST +BYTES'));
```

En el proyecto esto esta automatizado en:

```text
sql/oracle/04_explain_plan.sql
```

El resultado queda en archivos como:

```text
report/resultados/oracle/100prov_1000rel_explain_plan.txt
```

Las metricas principales a revisar son:

- `Cost`: costo estimado por el optimizador.
- Operaciones del plan: joins, full scans, index scans, sorts, etc.
- Cantidad estimada de filas.

## TKPROF En Oracle

Para usar TKPROF se activa la traza SQL:

```sql
ALTER SESSION SET tracefile_identifier = 'BD2_TRABAJO4';
ALTER SESSION SET statistics_level = ALL;
ALTER SESSION SET sql_trace = TRUE;
```

Despues se ejecutan las consultas y se desactiva la traza:

```sql
ALTER SESSION SET sql_trace = FALSE;
```

Luego se ubica el archivo `.trc`:

```bash
find /opt/oracle/diag -name '*BD2_TRABAJO4*.trc'
```

Y se procesa con:

```bash
tkprof archivo.trc salida_tkprof.txt sort=exeela,fchela
```

En este proyecto, `pruebas.sh` intenta hacer este proceso automaticamente y guardar archivos como:

```text
report/resultados/oracle/100prov_1000rel_tkprof.txt
```

Para calcular las tasas solicitadas:

| Tasa | Formula |
|---|---|
| LIOs sobre filas procesadas | `(query + current) / rows` |
| Filas retornadas sobre fetches | `rows / fetches` |
| Lecturas de disco sobre LIOs | `disk / (query + current)` |

En TKPROF normalmente:

- `query` representa lecturas logicas consistentes.
- `current` representa lecturas logicas en modo actual.
- `disk` representa lecturas fisicas.
- `rows` representa filas procesadas.
- `fetch` muestra las llamadas fetch.

## PostgreSQL

PostgreSQL no tiene TKPROF. La herramienta equivalente para este trabajo es:

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT ...
```

Esta instruccion ejecuta realmente la consulta y muestra:

- tiempo estimado y real;
- filas estimadas y reales;
- metodo de acceso;
- tipo de join;
- buffers leidos desde cache;
- buffers leidos desde disco.

Los resultados quedan en:

```text
report/resultados/postgres/
```

Para comparar con Oracle:

- `shared hit` se puede interpretar como lectura logica desde cache.
- `shared read` se puede interpretar como lectura fisica desde disco.
- `actual rows` permite revisar filas procesadas o retornadas.
- `Execution Time` permite comparar tiempo real.

## Resultados

Los resultados que se presentan a continuacion provienen directamente de los archivos generados en `report/resultados/` tras ejecutar `pruebas.sh` con las 4 muestras (100, 500, 1000 y 2000 proveedores). No se ejecuto la muestra 5 (5000 proveedores) porque es opcional y requiere activar `RUN_LARGE=1`.

Todas las consultas retornaron 190 filas en todas las muestras, porque el conjunto de proveedores con productos identicos esta fijo en 20 proveedores especiales que comparten los mismos productos.

### Tabla Resumen Oracle - Explain Plan

| Muestra | Consulta | Cost | Elapsed (TKPROF) | Observaciones |
|---|---:|---:|---:|---|
| 100 / 1.000 | Q1 - NOT EXISTS | 4472 | 0.01s | MERGE JOIN + FILTER, INDEX RANGE SCAN en PK_PROVXPROD |
| 100 / 1.000 | Q2 - LISTAGG | 218 | 0.00s | TEMP TABLE TRANSFORMATION, HASH JOIN a tabla temporal |
| 100 / 1.000 | Q3 - conteos | 26 | 0.03s | TEMP TABLE TRANSFORMATION, HASH GROUP BY, NESTED LOOPS |
| 100 / 1.000 | Q4 - MINUS | 3356 | 0.02s | MERGE JOIN + MINUS con INDEX RANGE SCAN |
| 500 / 5.000 | Q1 - NOT EXISTS | 4472 | 0.21s | Mismo plan, costo no refleja el crecimiento de datos |
| 500 / 5.000 | Q2 - LISTAGG | 220 | 0.00s | Plan estable, costo sube ligeramente |
| 500 / 5.000 | Q3 - conteos | 30 | 0.71s | Mismo plan, NESTED LOOPS sobre 124.750 pares |
| 500 / 5.000 | Q4 - MINUS | 3356 | 0.39s | Mismo plan, MINUS se ejecuta por cada par |
| 1.000 / 10.000 | Q1 - NOT EXISTS | 4472 | 0.85s | Plan identico, tiempo real crece |
| 1.000 / 10.000 | Q2 - LISTAGG | 224 | 0.00s | Plan estable y eficiente |
| 1.000 / 10.000 | Q3 - conteos | 41 | 2.94s | Plan hash cambia a 2544319945 (full scan en Prov) |
| 1.000 / 10.000 | Q4 - MINUS | 3356 | 1.58s | Mismo plan, 499.500 pares evaluados |
| 2.000 / 25.000 | Q1 - NOT EXISTS | 4476 | 3.44s | Costo estimado apenas 4476, pero real 3.44s |
| 2.000 / 25.000 | Q2 - LISTAGG | 234 | 0.02s | Plan estable, mas rapido que Q1/Q3/Q4 por ordenes de magnitud |
| 2.000 / 25.000 | Q3 - conteos | 63 | 16.40s | Usa disco (7335 lecturas fisicas); alto costo real |
| 2.000 / 25.000 | Q4 - MINUS | 3360 | 6.37s | 1.999.000 pares, 4.78M de LIOs |

### Tabla Resumen Oracle - TKPROF

| Muestra | Consulta | LIOs / filas proc. | Filas ret. / fetches | Disco / LIOs |
|---|---:|---:|---:|---:|
| 100 / 1.000 | Q1 | 68.34 | 13.57 | 0.0000 |
| 100 / 1.000 | Q2 | 0.09 | 13.57 | 0.0000 |
| 100 / 1.000 | Q3 | 77.36 | 13.57 | 0.0000 |
| 100 / 1.000 | Q4 | 69.43 | 13.57 | 0.0000 |
| 500 / 5.000 | Q1 | 1.560.77 | 13.57 | 0.0000 |
| 500 / 5.000 | Q2 | 0.12 | 13.57 | 0.0000 |
| 500 / 5.000 | Q3 | 1.894.99 | 13.57 | 0.0000 |
| 500 / 5.000 | Q4 | 1.563.44 | 13.57 | 0.0000 |
| 1.000 / 10.000 | Q1 | 6.197.84 | 13.57 | 0.0000 |
| 1.000 / 10.000 | Q2 | 0.20 | 13.57 | 0.0000 |
| 1.000 / 10.000 | Q3 | 7.903.71 | 13.57 | 0.0000 |
| 1.000 / 10.000 | Q4 | 6.201.65 | 13.57 | 0.0000 |
| 2.000 / 25.000 | Q1 | 25.164.63 | 13.57 | 0.0000 |
| 2.000 / 25.000 | Q2 | 0.41 | 13.57 | 0.0000 |
| 2.000 / 25.000 | Q3 | 14.038.62 | 13.57 | 0.0027 |
| 2.000 / 25.000 | Q4 | 25.193.05 | 13.57 | 0.0000 |

### Tabla Resumen PostgreSQL

| Muestra | Consulta | Execution Time | shared hit | shared read | Observaciones |
|---|---:|---:|---:|---:|---|
| 100 / 1.000 | Q1 | 23.293 ms | 220 | 0 | Hash Anti Join, Nested Loop, Seq Scan + Index Scan |
| 100 / 1.000 | Q2 | 0.721 ms | 9 | 0 | Hash Join con CTE, GroupAggregate |
| 100 / 1.000 | Q3 | 10.954 ms | 216 | 0 | Hash Join con CTE, HashAggregate, Nested Loop |
| 100 / 1.000 | Q4 | 74.343 ms | 69.881 | 0 | Nested Loop, SubPlan con HashSetOp Except |
| 500 / 5.000 | Q1 | 60.035 ms | 2.522 | 0 | Mismo plan; 500 x 250 filas en Nested Loop |
| 500 / 5.000 | Q2 | 3.079 ms | 34 | 0 | Plan eficiente, firma por STRING_AGG |
| 500 / 5.000 | Q3 | 207.707 ms | 2.499 | 0 | Hash Right Join produce 1.2M filas intermedias |
| 500 / 5.000 | Q4 | 1.762.754 ms | 2.824.693 | 0 | SubPlan se ejecuta 124.750 veces; 2.8M buffers |
| 1.000 / 10.000 | Q1 | 208.851 ms | 200.728 | 0 | Nested Loop produce 499.500 filas internas |
| 1.000 / 10.000 | Q2 | 6.774 ms | 85 | 0 | Plan estable, 10.020 filas agrupadas |
| 1.000 / 10.000 | Q3 | 951.194 ms | 199.433 | temp: 1511 | Usa disco por primera vez (hash batches: 4) |
| 1.000 / 10.000 | Q4 | 7.946.117 ms | 15.862.912 | 0 | 499.500 iteraciones del SubPlan; 15.8M buffers |
| 2.000 / 25.000 | Q1 | 801.607 ms | 398.426 | 0 | 1.999.000 filas en Nested Loop; JIT habilitado |
| 2.000 / 25.000 | Q2 | 17.639 ms | 183 | 0 | Plan cambia a Merge Join (antes Hash Join) |
| 2.000 / 25.000 | Q3 | 4.030.356 ms | 396.940 | temp: 10128 | 32 batches hash, 24.6M filas intermedias |
| 2.000 / 25.000 | Q4 | 19.167.849 ms | 34.839.945 | 0 | 1.999.000 iteraciones, Index Only Scan, 34.8M buffers |

## Comparacion Oracle Vs PostgreSQL

Los resultados obtenidos permiten comparar el comportamiento de ambos motores ante las mismas consultas y los mismos datos.

### Tiempo de ejecucion

La consulta mas rapida en ambos motores fue Q2 (firma con LISTAGG / STRING_AGG). En Oracle se mantuvo siempre por debajo de 0.02s incluso con 2000 proveedores. En PostgreSQL fue igual de eficiente: 0.7ms en la muestra mas pequena y 17.6ms en la mas grande.

La consulta mas lenta fue Q4 (MINUS / EXCEPT) en ambos motores. En Oracle alcanzo 6.37s con 2000 proveedores; en PostgreSQL llego a 19.17s. La diferencia se debe a que Oracle usa INDEX RANGE SCAN dentro del MINUS, mientras que PostgreSQL ejecuta un SubPlan anidado para cada par de proveedores, lo que escala cuadraticamente.

### Lecturas logicas (LIOs vs shared hit)

Oracle y PostgreSQL muestran el mismo patron: Q2 consume minimas lecturas (17-77 buffers en Oracle, 9-183 en PostgreSQL). Q1, Q3 y Q4 consumen cada vez mas a medida que crece la muestra. En la muestra de 2000 proveedores, Q4 en Oracle requirio 4.78M de LIOs, mientras que en PostgreSQL fueron 34.8M de shared hit (buffers). La diferencia se explica porque PostgreSQL ejecuta el SubPlan del EXCEPT para cada par de proveedores (1.999.000 veces), mientras que Oracle lo resuelve con INDEX RANGE SCAN dentro del operador MINUS.

### Uso de disco

Oracle solo uso disco en Q3 con 2000 proveedores (7335 lecturas fisicas, tasa disco/LIOs = 0.0027). PostgreSQL empezo a usar disco temporal en Q3 desde 1000 proveedores (1511 bloques escritos/leidos) y llego a 10128 bloques con 2000 proveedores, debido a que Hash Join necesito dividirse en 32 batches.

### Planes de ejecucion

Oracle mantuvo planes casi identicos en todas las muestras para Q1 y Q4 (MERGE JOIN + FILTER con INDEX RANGE SCAN). Los costos estimados variaron muy poco (4472 a 4476 en Q1, 3356 a 3360 en Q4), lo que sugiere que el optimizador no recalcula bien el costo real a medida que crecen los datos.

En PostgreSQL los planes evolucionaron: Q2 paso de Hash Join a Merge Join en la muestra de 2000 proveedores; Q4 paso de Bitmap Heap Scan a Index Only Scan. Ademas, PostgreSQL habilito JIT (inlining y optimization) en las muestras grandes, lo que indica que el motor detecto consultas suficientemente costosas para justificar la compilacion.

### Estabilidad

Q2 fue la unica consulta completamente estable en ambos motores: tiempo, lecturas y plan se mantuvieron predecibles en todas las muestras. Q3 fue la mas afectada por el crecimiento de datos, porque genera una cantidad de filas intermedias que crece cuadraticamente (producto cartesiano de pares de proveedores por productos). Q1 y Q4 tambien escalan cuadraticamente, pero el impacto es menor porque trabajan sobre indices, no sobre tablas completas.

## Conclusiones

1. **La consulta mas eficiente** en ambos motores fue Q2 (LISTAGG / STRING_AGG). Su tiempo de ejecucion se mantuvo practicamente constante independientemente del tamano de la muestra. Esto la convierte en la mejor opcion para el problema planteado.

2. **La consulta mas lenta** fue Q4 (MINUS / EXCEPT) en PostgreSQL, con 19 segundos en la muestra de 2000 proveedores. La razon es que PostgreSQL implementa EXCEPT anidado dentro de un SubPlan que se ejecuta para cada par de proveedores, mientras que Oracle maneja MINUS de forma mas optima con INDEX RANGE SCAN.

3. **Planes de ejecucion similares**: Ambos motores usaron estrategias comparables para Q1 y Q2 (merge join / hash join con scans secuenciales o por indice). Para Q3 y Q4 ambos recurrieron a nested loops, pero con diferencias importantes en la implementacion de los operadores de conjuntos.

4. **Operadores de conjuntos (MINUS / EXCEPT)**: La consulta Q4 es conceptualmente la mas clara (expresa directamente "productos de p1 que no estan en p2"), pero resulto ser la mas costosa en ambos motores. En Oracle el plan es razonable porque aprovecha los indices; en PostgreSQL el plan anidado es muy costoso.

5. **Firma agregada (Q2)**: Demostro ser la estrategia mas eficiente y escalable. Transformar el conjunto de productos en una cadena ordenada y comparar firmas evita el producto cartesiano de pares de productos. La unica desventaja es que LISTAGG / STRING_AGG tienen limites de longitud, pero para datos reales de proveedores esto rara vez es un problema.

6. **Crecimiento cuadratico**: El cuello de botella principal no es el tamano de las tablas individuales, sino el numero de pares de proveedores (N*(N-1)/2). Con 100 proveedores hay 4.950 pares; con 2000 hay 1.999.000 pares. Todas las consultas excepto Q2 se ven afectadas por este crecimiento.

7. **Oracle vs PostgreSQL**: Oracle mostro mejor rendimiento en las consultas que usan indices (Q1, Q4), mientras que PostgreSQL fue similar o mejor en Q2. Para Q3, PostgreSQL empezo a usar disco temporal desde los 1000 proveedores, mientras que Oracle lo hizo recien en 2000. En general, Oracle manejo mejor la escalabilidad de las consultas con operadores de conjuntos.

8. **La consulta 2 es la recomendada** para resolver el problema planteado: es clara, rapida, estable y no depende de operadores especificos de cada motor (LISTAGG y STRING_AGG son equivalentes funcionales).

## Anexos

Los archivos de soporte estan en:

- `sql/oracle/`
- `sql/postgres/`
- `report/resultados/oracle/`
- `report/resultados/postgres/`
- `report/capturas/`
