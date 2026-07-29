SET SERVEROUTPUT ON
SET TIMING ON
CALL cargar_datos_aleatorios(1000, 10000, 10000);
SELECT COUNT(*) AS total_proveedores FROM Prov;
SELECT COUNT(*) AS total_relaciones FROM ProvxProd;
EXIT
