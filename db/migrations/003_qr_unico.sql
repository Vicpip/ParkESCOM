-- 003_qr_unico: un solo QR activo por cada par usuario-vehículo (Fase 1B).
-- Migración inmutable: los cambios posteriores van en una migración nueva.

-- Un QR revocado, perdido o vencido no estorba para emitir uno nuevo.
CREATE UNIQUE INDEX credenciales_qr_activo_unico ON credenciales (vehiculo_id, usuario_id)
  WHERE tipo = 'qr' AND estado = 'activa';
