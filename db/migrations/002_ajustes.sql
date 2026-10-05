-- 002_ajustes: ajustes al esquema inicial (Fase 1A.1).
-- Migración inmutable: los cambios posteriores van en una migración nueva.

-- ---------------------------------------------------------------------------
-- Vehículos: la placa solo es única entre vehículos activos o pendientes
-- ---------------------------------------------------------------------------
-- Una placa de un vehículo dado de baja se puede volver a registrar.
DROP INDEX vehiculos_placa_unica;
CREATE UNIQUE INDEX vehiculos_placa_unica ON vehiculos (placa) WHERE estado <> 'baja';

-- ---------------------------------------------------------------------------
-- Credenciales: siempre de un vehículo; el QR, además, de un usuario
-- ---------------------------------------------------------------------------
ALTER TABLE credenciales
  DROP CONSTRAINT credenciales_con_dueno,
  ALTER COLUMN vehiculo_id SET NOT NULL,
  -- Un QR dinámico por cada par usuario-vehículo.
  ADD CONSTRAINT credenciales_qr_con_usuario CHECK (tipo <> 'qr' OR usuario_id IS NOT NULL);

-- ---------------------------------------------------------------------------
-- Estancias: de un vehículo registrado o de un pase de visitante
-- ---------------------------------------------------------------------------
ALTER TABLE estancias
  ALTER COLUMN vehiculo_id DROP NOT NULL,
  ADD COLUMN pase_id uuid REFERENCES pases (id),
  ADD CONSTRAINT estancias_vehiculo_o_pase CHECK (num_nonnulls(vehiculo_id, pase_id) = 1);

-- Anti-passback de visitantes: un pase solo puede tener una estancia abierta.
CREATE UNIQUE INDEX estancias_pase_una_abierta ON estancias (pase_id) WHERE salida_id IS NULL;

-- ---------------------------------------------------------------------------
-- Incidentes: el tipo pasa de texto libre a enum
-- ---------------------------------------------------------------------------
CREATE TYPE tipo_incidente AS ENUM (
  'antipassback', 'credencial_invalida', 'lectura_fallida', 'inconsistencia_vehiculo', 'otro'
);

-- Los tipos que no estén en el enum se conservan como 'otro'.
ALTER TABLE incidentes
  ALTER COLUMN tipo TYPE tipo_incidente USING (
    CASE
      WHEN tipo IN ('antipassback', 'credencial_invalida', 'lectura_fallida', 'inconsistencia_vehiculo')
        THEN tipo
      ELSE 'otro'
    END
  )::tipo_incidente;

-- ---------------------------------------------------------------------------
-- Dispositivos: tipos de equipo permitidos
-- ---------------------------------------------------------------------------
ALTER TABLE dispositivos
  ADD CONSTRAINT dispositivos_tipo_permitido CHECK (tipo IN ('mc33xr', 'et401', 'otro'));

-- ---------------------------------------------------------------------------
-- Puertas: todo tipo de vehículo entra y sale por cualquiera de las dos
-- ---------------------------------------------------------------------------
UPDATE puertas
   SET tipos_vehiculo = '{auto,moto,bici,scooter}'
 WHERE nombre IN ('Puerta A', 'Puerta B');
