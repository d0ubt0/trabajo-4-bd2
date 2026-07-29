\set ON_ERROR_STOP on

DROP TABLE IF EXISTS ProvxProd;
DROP TABLE IF EXISTS Prov;

CREATE TABLE Prov (
  nit INTEGER NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  CONSTRAINT pk_prov PRIMARY KEY (nit),
  CONSTRAINT uq_prov_nombre UNIQUE (nombre)
);

CREATE TABLE ProvxProd (
  nit INTEGER NOT NULL,
  codigoProducto INTEGER NOT NULL,
  CONSTRAINT pk_provxprod PRIMARY KEY (nit, codigoProducto),
  CONSTRAINT fk_provxprod_prov FOREIGN KEY (nit) REFERENCES Prov(nit)
);
