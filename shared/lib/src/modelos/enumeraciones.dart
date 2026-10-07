/// Tipo de vehículo; corresponde al enum `tipo_vehiculo` de la base.
enum TipoVehiculo {
  /// Automóvil.
  auto('auto'),

  /// Motocicleta.
  moto('moto'),

  /// Bicicleta.
  bici('bici'),

  /// Scooter.
  scooter('scooter');

  const TipoVehiculo(this.nombre);

  /// Valor en la base y en la API.
  final String nombre;

  /// Autos y motos llevan placa; bicis y scooters pueden no tenerla.
  bool get exigePlaca => this == auto || this == moto;

  /// Solo en las motos se pide la foto de la placa.
  bool get exigeFotoPlaca => this == moto;

  /// Tipo con ese [nombre], o `null` si no existe.
  static TipoVehiculo? deNombre(Object? nombre) =>
      values.where((valor) => valor.nombre == nombre).firstOrNull;
}

/// Estado de un usuario o de un vehículo; corresponde a `estado_registro`.
enum EstadoRegistro {
  /// Registrado, en espera de que Administración lo apruebe.
  pendiente('pendiente'),

  /// Aprobado y vigente.
  activo('activo'),

  /// Dado de baja (baja lógica).
  baja('baja');

  const EstadoRegistro(this.nombre);

  /// Valor en la base y en la API.
  final String nombre;

  /// Estado con ese [nombre], o `null` si no existe.
  static EstadoRegistro? deNombre(Object? nombre) =>
      values.where((valor) => valor.nombre == nombre).firstOrNull;
}

/// Qué pide una solicitud; corresponde al enum `tipo_solicitud`.
enum TipoSolicitud {
  /// Registrar un vehículo nuevo.
  alta('alta'),

  /// Cambiar los datos o las fotos de un vehículo.
  cambio('cambio'),

  /// Dar de baja un vehículo.
  baja('baja');

  const TipoSolicitud(this.nombre);

  /// Valor en la base y en la API.
  final String nombre;

  /// Tipo con ese [nombre], o `null` si no existe.
  static TipoSolicitud? deNombre(Object? nombre) =>
      values.where((valor) => valor.nombre == nombre).firstOrNull;
}

/// Estado de una solicitud; corresponde al enum `estado_solicitud`.
enum EstadoSolicitud {
  /// En espera de que Administración la resuelva.
  pendiente('pendiente'),

  /// Aprobada.
  aprobada('aprobada'),

  /// Rechazada; el comentario dice por qué.
  rechazada('rechazada');

  const EstadoSolicitud(this.nombre);

  /// Valor en la base y en la API.
  final String nombre;

  /// Estado con ese [nombre], o `null` si no existe.
  static EstadoSolicitud? deNombre(Object? nombre) =>
      values.where((valor) => valor.nombre == nombre).firstOrNull;
}

/// Tipo de credencial; corresponde al enum `tipo_credencial`.
enum TipoCredencial {
  /// Tag RFID propio de ESCOM.
  tagPropio('tag_propio'),

  /// Tag RFID de casetas.
  tagCaseta('tag_caseta'),

  /// Calcomanía NFC.
  nfc('nfc'),

  /// QR dinámico de un usuario para un vehículo.
  qr('qr');

  const TipoCredencial(this.nombre);

  /// Valor en la base y en la API.
  final String nombre;

  /// Tipo con ese [nombre], o `null` si no existe.
  static TipoCredencial? deNombre(Object? nombre) =>
      values.where((valor) => valor.nombre == nombre).firstOrNull;
}

/// Estado de una credencial; corresponde al enum `estado_credencial`.
enum EstadoCredencial {
  /// Funciona en las casetas.
  activa('activa'),

  /// Reportada como perdida.
  perdida('perdida'),

  /// Revocada por Administración o por la baja del vehículo.
  revocada('revocada'),

  /// Pasó su vigencia.
  vencida('vencida');

  const EstadoCredencial(this.nombre);

  /// Valor en la base y en la API.
  final String nombre;

  /// Estado con ese [nombre], o `null` si no existe.
  static EstadoCredencial? deNombre(Object? nombre) =>
      values.where((valor) => valor.nombre == nombre).firstOrNull;
}
