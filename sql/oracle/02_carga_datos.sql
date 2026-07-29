SET SERVEROUTPUT ON
SET ECHO ON
SET FEEDBACK ON

CREATE OR REPLACE PROCEDURE cargar_datos_aleatorios(
  p_num_proveedores IN NUMBER,
  p_num_productos   IN NUMBER,
  p_num_relaciones  IN NUMBER
) AS
  v_nit NUMBER;
  v_producto NUMBER;
  v_insertadas NUMBER := 0;
  v_intentos NUMBER := 0;
  v_max_intentos NUMBER;
BEGIN
  DELETE FROM ProvxProd;
  DELETE FROM Prov;

  FOR i IN 1..p_num_proveedores LOOP
    INSERT INTO Prov(nit, nombre)
    VALUES (i, 'Proveedor_' || TO_CHAR(i));
  END LOOP;

  v_max_intentos := p_num_relaciones * 20;

  WHILE v_insertadas < p_num_relaciones AND v_intentos < v_max_intentos LOOP
    v_intentos := v_intentos + 1;
    IF p_num_proveedores > 20 THEN
      -- Los primeros 20 proveedores quedan sin productos para garantizar parejas con conjunto vacio.
      v_nit := TRUNC(DBMS_RANDOM.VALUE(21, p_num_proveedores + 1));
    ELSE
      v_nit := TRUNC(DBMS_RANDOM.VALUE(1, p_num_proveedores + 1));
    END IF;
    v_producto := TRUNC(DBMS_RANDOM.VALUE(1, p_num_productos + 1));

    BEGIN
      INSERT INTO ProvxProd(nit, codigoProducto)
      VALUES (v_nit, v_producto);
      v_insertadas := v_insertadas + 1;
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        NULL;
    END;
  END LOOP;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Proveedores cargados: ' || p_num_proveedores);
  DBMS_OUTPUT.PUT_LINE('Relaciones solicitadas: ' || p_num_relaciones);
  DBMS_OUTPUT.PUT_LINE('Relaciones insertadas: ' || v_insertadas);
END;
/

SHOW ERRORS
