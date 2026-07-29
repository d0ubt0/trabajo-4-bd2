\set ON_ERROR_STOP on

CREATE OR REPLACE PROCEDURE cargar_datos_aleatorios(
  p_num_proveedores INTEGER,
  p_num_productos INTEGER,
  p_num_relaciones INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_nit INTEGER;
  v_producto INTEGER;
  v_insertadas INTEGER := 0;
  v_intentos INTEGER := 0;
  v_max_intentos INTEGER;
BEGIN
  DELETE FROM ProvxProd;
  DELETE FROM Prov;

  INSERT INTO Prov(nit, nombre)
  SELECT i, 'Proveedor_' || i::TEXT
  FROM generate_series(1, p_num_proveedores) AS i;

  v_max_intentos := p_num_relaciones * 20;

  WHILE v_insertadas < p_num_relaciones AND v_intentos < v_max_intentos LOOP
    v_intentos := v_intentos + 1;
    IF p_num_proveedores > 20 THEN
      -- Los primeros 20 proveedores quedan sin productos para garantizar parejas con conjunto vacio.
      v_nit := floor(random() * (p_num_proveedores - 20) + 21)::INTEGER;
    ELSE
      v_nit := floor(random() * p_num_proveedores + 1)::INTEGER;
    END IF;
    v_producto := floor(random() * p_num_productos + 1)::INTEGER;

    INSERT INTO ProvxProd(nit, codigoProducto)
    VALUES (v_nit, v_producto)
    ON CONFLICT DO NOTHING;

    IF FOUND THEN
      v_insertadas := v_insertadas + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'Proveedores cargados: %', p_num_proveedores;
  RAISE NOTICE 'Relaciones solicitadas: %', p_num_relaciones;
  RAISE NOTICE 'Relaciones insertadas: %', v_insertadas;
END;
$$;
