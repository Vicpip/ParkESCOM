-- 005_solicitudes: reglas e índices de las solicitudes de vehículo (Fase 2B).
-- Migración inmutable: los cambios posteriores van en una migración nueva.

-- Un vehículo no puede tener dos solicitudes pendientes a la vez (por
-- ejemplo, un cambio y una baja): la segunda espera a que se resuelva la
-- primera. Las ya resueltas no estorban.
CREATE UNIQUE INDEX solicitudes_una_pendiente ON solicitudes (vehiculo_id)
  WHERE estado = 'pendiente' AND vehiculo_id IS NOT NULL;

-- "Mis solicitudes": las de un usuario, de la más reciente a la más antigua.
CREATE INDEX solicitudes_usuario_creado_idx ON solicitudes (usuario_id, creado_en DESC);
