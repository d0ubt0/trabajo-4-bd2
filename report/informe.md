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

Esta seccion debe completarse despues de ejecutar:

```bash
chmod +x pruebas.sh scripts/wait-for-oracle.sh scripts/wait-for-postgres.sh
./pruebas.sh
```

No se presentan numeros inventados. Los resultados reales deben copiarse desde `report/resultados/`.

### Tabla Resumen Oracle - Explain Plan

| Muestra | Consulta | Cost | Time estimado | Observaciones |
|---|---|---:|---:|---|
| 100 / 1.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q4 | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q4 | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q4 | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q4 | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q4 | Pendiente | Pendiente | Pendiente |

### Tabla Resumen Oracle - TKPROF

| Muestra | Consulta | LIOs / filas procesadas | Filas retornadas / fetches | Disco / LIOs |
|---|---|---:|---:|---:|
| 100 / 1.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q4 | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q4 | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q4 | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q4 | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q1 | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q2 | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q3 | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q4 | Pendiente | Pendiente | Pendiente |

### Tabla Resumen PostgreSQL

| Muestra | Consulta | Execution Time | Shared hit | Shared read | Observaciones |
|---|---|---:|---:|---:|---|
| 100 / 1.000 | Q1 | Pendiente | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q2 | Pendiente | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q3 | Pendiente | Pendiente | Pendiente | Pendiente |
| 100 / 1.000 | Q4 | Pendiente | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q1 | Pendiente | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q2 | Pendiente | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q3 | Pendiente | Pendiente | Pendiente | Pendiente |
| 500 / 5.000 | Q4 | Pendiente | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q1 | Pendiente | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q2 | Pendiente | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q3 | Pendiente | Pendiente | Pendiente | Pendiente |
| 1.000 / 10.000 | Q4 | Pendiente | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q1 | Pendiente | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q2 | Pendiente | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q3 | Pendiente | Pendiente | Pendiente | Pendiente |
| 2.000 / 25.000 | Q4 | Pendiente | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q1 | Pendiente | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q2 | Pendiente | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q3 | Pendiente | Pendiente | Pendiente | Pendiente |
| 5.000 / 50.000 | Q4 | Pendiente | Pendiente | Pendiente | Pendiente |

## Comparacion Oracle Vs PostgreSQL

La comparacion debe hacerse con los resultados reales obtenidos en el mismo computador. Se deben observar principalmente:

- tiempo de ejecucion;
- lecturas logicas;
- lecturas fisicas;
- cambios en el plan cuando aumenta el tamano de muestra;
- estabilidad de cada consulta.

En general, se espera que las consultas basadas en comparar todas las parejas de proveedores sean costosas cuando aumenta el numero de proveedores, porque el numero de parejas posibles crece rapidamente.

## Conclusiones

Pendiente completar con los resultados reales.

Conclusiones que se deben analizar despues de ejecutar las pruebas:

- Cual consulta tuvo menor tiempo en Oracle.
- Cual consulta tuvo menor tiempo en PostgreSQL.
- Si el optimizador eligio planes similares o diferentes.
- Si las consultas con operadores de conjuntos fueron mas claras o mas costosas.
- Si la consulta con firma agregada fue eficiente o tuvo problemas por ordenar y concatenar productos.
- Como influyo el crecimiento de proveedores en el numero de parejas comparadas.

## Anexos

Los archivos de soporte estan en:

- `sql/oracle/`
- `sql/postgres/`
- `report/resultados/oracle/`
- `report/resultados/postgres/`
- `report/capturas/`
