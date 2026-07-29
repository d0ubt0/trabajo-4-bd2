\timing on
CALL cargar_datos_aleatorios(100, 1000, 1000);
SELECT COUNT(*) AS total_proveedores FROM Prov;
SELECT COUNT(*) AS total_relaciones FROM ProvxProd;
