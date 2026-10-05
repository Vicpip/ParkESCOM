-- ParkESCOM · Fase 1C: propósito de cada archivo.
--
-- El propósito decide quién puede descargar un archivo (la foto de la
-- credencial escolar solo la ven su dueño y Administración) y a qué campo se
-- puede asignar (por ejemplo, `usuarios.foto_titular_id` solo acepta `perfil`).

CREATE TYPE proposito_archivo AS ENUM (
  'perfil',
  'credencial_escolar',
  'vehiculo',
  'placa',
  'incidente'
);

ALTER TABLE archivos ADD COLUMN proposito proposito_archivo;

-- Los archivos que ya existan toman el propósito del campo que los referencia.
UPDATE archivos a SET proposito = 'perfil'
  FROM usuarios u WHERE u.foto_titular_id = a.id;
UPDATE archivos a SET proposito = 'credencial_escolar'
  FROM usuarios u WHERE u.foto_credencial_id = a.id AND a.proposito IS NULL;
UPDATE archivos a SET proposito = 'vehiculo'
  FROM vehiculos v WHERE v.foto_id = a.id AND a.proposito IS NULL;
UPDATE archivos a SET proposito = 'placa'
  FROM vehiculos v WHERE v.foto_placa_id = a.id AND a.proposito IS NULL;
UPDATE archivos a SET proposito = 'incidente'
  FROM incidentes i WHERE i.foto_id = a.id AND a.proposito IS NULL;

-- Si quedara algún archivo sin referencia, la migración falla aquí en vez de
-- inventarle un propósito.
ALTER TABLE archivos ALTER COLUMN proposito SET NOT NULL;
