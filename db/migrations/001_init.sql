-- 001_init: esquema inicial de ParkESCOM (16 tablas).
-- Migración inmutable: los cambios posteriores van en una migración nueva.

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------
CREATE TYPE rol_usuario AS ENUM ('usuario', 'guardia', 'admin');
CREATE TYPE estado_registro AS ENUM ('pendiente', 'activo', 'baja');
CREATE TYPE tipo_vehiculo AS ENUM ('auto', 'moto', 'bici', 'scooter');
CREATE TYPE tipo_credencial AS ENUM ('tag_propio', 'tag_caseta', 'nfc', 'qr');
CREATE TYPE estado_credencial AS ENUM ('activa', 'perdida', 'revocada', 'vencida');
CREATE TYPE tipo_solicitud AS ENUM ('alta', 'cambio', 'baja');
CREATE TYPE estado_solicitud AS ENUM ('pendiente', 'aprobada', 'rechazada');
CREATE TYPE estado_pase AS ENUM ('pendiente', 'aprobado', 'rechazado', 'usado', 'vencido');
CREATE TYPE sentido AS ENUM ('entrada', 'salida');
CREATE TYPE fuente_lectura AS ENUM ('rfid', 'qr', 'nfc', 'hce', 'manual');
CREATE TYPE resultado_validacion AS ENUM ('aceptado', 'rechazado');
CREATE TYPE estado_incidente AS ENUM ('abierto', 'en_revision', 'resuelto');

-- ---------------------------------------------------------------------------
-- Funciones de trigger
-- ---------------------------------------------------------------------------

-- Mantiene actualizado_en para la sincronización incremental de las casetas.
CREATE FUNCTION tocar_actualizado_en() RETURNS trigger AS $$
BEGIN
  NEW.actualizado_en := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- La auditoría es de solo inserción.
CREATE FUNCTION rechazar_cambio_auditoria() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'La tabla auditoria es de solo inserción';
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Usuarios y archivos
-- ---------------------------------------------------------------------------
CREATE TABLE usuarios (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  correo             text NOT NULL,
  hash_password      text NOT NULL,
  nombre             text NOT NULL,
  boleta_o_empleado  text NOT NULL,
  rol                rol_usuario NOT NULL DEFAULT 'usuario',
  foto_titular_id    uuid,
  foto_credencial_id uuid,
  estado             estado_registro NOT NULL DEFAULT 'pendiente',
  vigencia           timestamptz,
  creado_en          timestamptz NOT NULL DEFAULT now(),
  actualizado_en     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT usuarios_correo_unico UNIQUE (correo),
  CONSTRAINT usuarios_boleta_o_empleado_unico UNIQUE (boleta_o_empleado),
  CONSTRAINT usuarios_correo_minusculas CHECK (correo = lower(correo))
);

CREATE TABLE archivos (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ruta         text NOT NULL,
  tipo_mime    text NOT NULL,
  tamano_bytes integer NOT NULL,
  dueno_id     uuid REFERENCES usuarios (id),
  creado_en    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT archivos_ruta_unica UNIQUE (ruta),
  CONSTRAINT archivos_tipo_mime_permitido CHECK (tipo_mime IN ('image/jpeg', 'image/png')),
  CONSTRAINT archivos_tamano_maximo CHECK (tamano_bytes > 0 AND tamano_bytes <= 2097152)
);

ALTER TABLE usuarios
  ADD CONSTRAINT usuarios_foto_titular_fk FOREIGN KEY (foto_titular_id) REFERENCES archivos (id),
  ADD CONSTRAINT usuarios_foto_credencial_fk FOREIGN KEY (foto_credencial_id) REFERENCES archivos (id);

-- ---------------------------------------------------------------------------
-- Vehículos y credenciales
-- ---------------------------------------------------------------------------
CREATE TABLE vehiculos (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo           tipo_vehiculo NOT NULL,
  placa          text,
  numero_serie   text,
  marca          text,
  modelo         text,
  color          text,
  foto_id        uuid REFERENCES archivos (id),
  foto_placa_id  uuid REFERENCES archivos (id),
  estado         estado_registro NOT NULL DEFAULT 'pendiente',
  creado_en      timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz NOT NULL DEFAULT now(),
  -- Letras, números y guiones; en mayúsculas y sin espacios.
  CONSTRAINT vehiculos_placa_formato CHECK (placa ~ '^[A-Z0-9-]+$')
);

-- Placa única cuando no es nula.
CREATE UNIQUE INDEX vehiculos_placa_unica ON vehiculos (placa) WHERE placa IS NOT NULL;

CREATE TABLE vehiculo_usuarios (
  vehiculo_id    uuid NOT NULL REFERENCES vehiculos (id),
  usuario_id     uuid NOT NULL REFERENCES usuarios (id),
  es_titular     boolean NOT NULL DEFAULT false,
  -- Baja lógica de la autorización, para que la sincronización la vea.
  activo         boolean NOT NULL DEFAULT true,
  creado_en      timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (vehiculo_id, usuario_id)
);

-- Un solo titular por vehículo.
CREATE UNIQUE INDEX vehiculo_usuarios_un_titular ON vehiculo_usuarios (vehiculo_id) WHERE es_titular;

CREATE TABLE credenciales (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Tags y calcomanías NFC pertenecen a un vehículo; el QR dinámico, a su dueño.
  vehiculo_id          uuid REFERENCES vehiculos (id),
  usuario_id           uuid REFERENCES usuarios (id),
  tipo                 tipo_credencial NOT NULL,
  identificador        text NOT NULL,
  semilla_totp_cifrada text,
  estado               estado_credencial NOT NULL DEFAULT 'activa',
  vigencia             timestamptz,
  consentimiento       boolean NOT NULL DEFAULT false,
  creado_en            timestamptz NOT NULL DEFAULT now(),
  actualizado_en       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT credenciales_con_dueno CHECK (vehiculo_id IS NOT NULL OR usuario_id IS NOT NULL)
);

-- Una sola credencial activa por identificador.
CREATE UNIQUE INDEX credenciales_activa_unica ON credenciales (tipo, identificador) WHERE estado = 'activa';
CREATE INDEX credenciales_actualizado_en_idx ON credenciales (actualizado_en);

CREATE TABLE solicitudes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id      uuid NOT NULL REFERENCES usuarios (id),
  vehiculo_id     uuid REFERENCES vehiculos (id),
  tipo            tipo_solicitud NOT NULL,
  datos_propuestos jsonb,
  estado          estado_solicitud NOT NULL DEFAULT 'pendiente',
  comentario      text,
  resuelta_por    uuid REFERENCES usuarios (id),
  resuelta_en     timestamptz,
  creado_en       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pases (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitante_id uuid NOT NULL REFERENCES usuarios (id),
  visitante      text NOT NULL,
  placa          text,
  ventana_inicio timestamptz NOT NULL,
  ventana_fin    timestamptz NOT NULL,
  estado         estado_pase NOT NULL DEFAULT 'pendiente',
  -- Identificador del token firmado.
  jti            uuid NOT NULL DEFAULT gen_random_uuid(),
  resuelto_por   uuid REFERENCES usuarios (id),
  creado_en      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pases_jti_unico UNIQUE (jti),
  CONSTRAINT pases_ventana_valida CHECK (ventana_fin > ventana_inicio),
  CONSTRAINT pases_placa_formato CHECK (placa ~ '^[A-Z0-9-]+$')
);

-- ---------------------------------------------------------------------------
-- Puertas, zonas y dispositivos
-- ---------------------------------------------------------------------------
CREATE TABLE puertas (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre         text NOT NULL,
  tipos_vehiculo tipo_vehiculo[] NOT NULL,
  creado_en      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT puertas_nombre_unico UNIQUE (nombre)
);

CREATE TABLE zonas (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre         text NOT NULL,
  tipos_vehiculo tipo_vehiculo[] NOT NULL,
  cupo           integer NOT NULL,
  creado_en      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT zonas_nombre_unico UNIQUE (nombre),
  CONSTRAINT zonas_cupo_positivo CHECK (cupo > 0)
);

CREATE TABLE dispositivos (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre                text NOT NULL,
  tipo                  text NOT NULL,
  puerta_id             uuid REFERENCES puertas (id),
  hash_token            text NOT NULL,
  ultima_sincronizacion timestamptz,
  activo                boolean NOT NULL DEFAULT true,
  creado_en             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT dispositivos_hash_token_unico UNIQUE (hash_token)
);

-- ---------------------------------------------------------------------------
-- Movimientos, estancias e incidentes
-- ---------------------------------------------------------------------------
CREATE TABLE movimientos (
  -- UUID generado en el dispositivo: un reintento con el mismo id no duplica.
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehiculo_id     uuid REFERENCES vehiculos (id),
  credencial_id   uuid REFERENCES credenciales (id),
  pase_id         uuid REFERENCES pases (id),
  puerta_id       uuid NOT NULL REFERENCES puertas (id),
  sentido         sentido NOT NULL,
  hora_dispositivo timestamptz NOT NULL,
  hora_servidor   timestamptz NOT NULL DEFAULT now(),
  fuente          fuente_lectura NOT NULL,
  dispositivo_id  uuid REFERENCES dispositivos (id),
  resultado       resultado_validacion NOT NULL,
  motivo          text,
  CONSTRAINT movimientos_credencial_o_pase CHECK (credencial_id IS NULL OR pase_id IS NULL),
  -- Todo rechazo y todo registro manual llevan motivo.
  CONSTRAINT movimientos_motivo_obligatorio
    CHECK (motivo IS NOT NULL OR (resultado = 'aceptado' AND fuente <> 'manual'))
);

CREATE INDEX movimientos_vehiculo_hora_idx ON movimientos (vehiculo_id, hora_servidor);
CREATE INDEX movimientos_puerta_hora_idx ON movimientos (puerta_id, hora_servidor);

CREATE TABLE estancias (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehiculo_id uuid NOT NULL REFERENCES vehiculos (id),
  entrada_id  uuid NOT NULL REFERENCES movimientos (id),
  salida_id   uuid REFERENCES movimientos (id),
  zona_id     uuid REFERENCES zonas (id),
  CONSTRAINT estancias_entrada_unica UNIQUE (entrada_id),
  CONSTRAINT estancias_salida_unica UNIQUE (salida_id)
);

-- Anti-passback: un vehículo solo puede tener una estancia abierta.
CREATE UNIQUE INDEX estancias_una_abierta ON estancias (vehiculo_id) WHERE salida_id IS NULL;
CREATE INDEX estancias_zona_abiertas_idx ON estancias (zona_id) WHERE salida_id IS NULL;

CREATE TABLE incidentes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Número corto para citar el incidente de viva voz (INC-0001).
  folio         integer GENERATED ALWAYS AS IDENTITY,
  tipo          text NOT NULL,
  descripcion   text NOT NULL,
  foto_id       uuid REFERENCES archivos (id),
  latitud       double precision,
  longitud      double precision,
  estado        estado_incidente NOT NULL DEFAULT 'abierto',
  movimiento_id uuid REFERENCES movimientos (id),
  reportado_por uuid REFERENCES usuarios (id),
  creado_en     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT incidentes_folio_unico UNIQUE (folio),
  CONSTRAINT incidentes_ubicacion_completa CHECK ((latitud IS NULL) = (longitud IS NULL))
);

-- ---------------------------------------------------------------------------
-- Sesiones, restablecimientos y auditoría
-- ---------------------------------------------------------------------------
CREATE TABLE sesiones (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id         uuid NOT NULL REFERENCES usuarios (id),
  hash_refresh_token text NOT NULL,
  expira_en          timestamptz NOT NULL,
  revocada           boolean NOT NULL DEFAULT false,
  creado_en          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sesiones_hash_unico UNIQUE (hash_refresh_token)
);

CREATE TABLE restablecimientos (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id uuid NOT NULL REFERENCES usuarios (id),
  hash_token text NOT NULL,
  expira_en  timestamptz NOT NULL,
  usado      boolean NOT NULL DEFAULT false,
  creado_en  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT restablecimientos_hash_unico UNIQUE (hash_token)
);

CREATE TABLE auditoria (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id   uuid REFERENCES usuarios (id),
  accion     text NOT NULL,
  entidad    text NOT NULL,
  entidad_id uuid,
  antes      jsonb,
  despues    jsonb,
  fecha      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX auditoria_entidad_idx ON auditoria (entidad, entidad_id);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
CREATE TRIGGER usuarios_actualizado_en BEFORE UPDATE ON usuarios
  FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en();
CREATE TRIGGER vehiculos_actualizado_en BEFORE UPDATE ON vehiculos
  FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en();
CREATE TRIGGER vehiculo_usuarios_actualizado_en BEFORE UPDATE ON vehiculo_usuarios
  FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en();
CREATE TRIGGER credenciales_actualizado_en BEFORE UPDATE ON credenciales
  FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en();

CREATE TRIGGER auditoria_solo_insercion BEFORE UPDATE OR DELETE ON auditoria
  FOR EACH ROW EXECUTE FUNCTION rechazar_cambio_auditoria();
