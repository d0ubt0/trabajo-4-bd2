# Trabajo 4 - Bases de Datos 2

Este proyecto contiene una solucion reproducible con Docker para comparar cuatro consultas SQL que obtienen parejas de proveedores que venden exactamente el mismo conjunto de productos.

## Requisitos

- Docker
- Docker Compose
- Bash

No se requiere instalar Oracle ni PostgreSQL directamente en el sistema operativo.

## Estructura

```text
/
├── docker-compose.yml
├── oracle/
├── postgres/
├── scripts/
├── sql/
│   ├── oracle/
│   └── postgres/
├── report/
│   ├── informe.md
│   └── resultados/
├── pruebas.sh
└── README.md
```

## Ejecucion

```bash
chmod +x pruebas.sh scripts/wait-for-oracle.sh scripts/wait-for-postgres.sh
./pruebas.sh
```

El script realiza estas tareas:

1. Levanta Oracle y PostgreSQL con Docker Compose.
2. Espera a que ambos motores esten listos.
3. Crea las tablas `Prov` y `ProvxProd`.
4. Crea el procedimiento de carga aleatoria.
5. Ejecuta muestras crecientes. Por defecto llega hasta 2.000 proveedores; con RUN_LARGE=1 tambien ejecuta 5.000 proveedores.
6. Ejecuta las cuatro consultas.
7. Genera Explain Plan en Oracle.
8. Genera traza para TKPROF en Oracle.
9. Ejecuta `EXPLAIN (ANALYZE, BUFFERS)` en PostgreSQL.
10. Guarda resultados en `report/resultados/`.

## Credenciales

Oracle:

```text
usuario: bd2
clave: bd2
servicio: FREEPDB1
puerto: 1521
```

PostgreSQL:

```text
usuario: bd2
clave: bd2
base de datos: bd2
puerto: 5432
```

## Informe

El informe esta en:

```text
report/informe.md
```

Las tablas de resultados deben completarse con las salidas generadas despues de ejecutar `./pruebas.sh`. No se incluyen resultados inventados.

## Nota sobre Oracle

La primera ejecucion puede tardar varios minutos porque Oracle debe inicializar la base de datos. Si la imagen no esta descargada, Docker tambien debe bajarla.
