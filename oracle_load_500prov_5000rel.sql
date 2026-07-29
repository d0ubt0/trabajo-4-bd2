SET SERVEROUTPUT ON
SET TIMING ON
CALL cargar_datos_aleatorios(500, 5000, 5000);
SELECT COUNT(*) AS total_proveedores FROM Prov;
SELECT COUNT(*) AS total_relaciones FROM ProvxProd;
EXIT
