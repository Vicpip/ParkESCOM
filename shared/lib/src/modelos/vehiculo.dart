import 'enumeraciones.dart';
import 'json.dart';

/// Credencial de un vehículo tal como la ve su usuario.
///
/// Del identificador (EPC del tag, UID de NFC) solo lleva los últimos cuatro
/// caracteres, para reconocerla sin poder copiarla. No lleva la semilla del
/// QR dinámico ni ningún otro secreto.
class CredencialResumen {
  /// Crea el resumen de una credencial.
  const CredencialResumen({
    required this.id,
    required this.tipo,
    required this.estado,
    required this.terminacion,
    this.vigencia,
  });

  /// Lee una credencial de la respuesta de la API.
  factory CredencialResumen.fromJson(Map<String, dynamic> json) =>
      CredencialResumen(
        id: exigirCampo(json['id'], 'id'),
        tipo: exigirCampo(TipoCredencial.deNombre(json['tipo']), 'tipo'),
        estado: exigirCampo(
          EstadoCredencial.deNombre(json['estado']),
          'estado',
        ),
        terminacion: exigirCampo(json['terminacion'], 'terminacion'),
        vigencia: fechaDeJson(json['vigencia']),
      );

  /// Cuántos caracteres del identificador se muestran.
  static const largoTerminacion = 4;

  /// Últimos [largoTerminacion] caracteres de [identificador] (o todo, si es
  /// más corto).
  static String terminacionDe(String identificador) =>
      identificador.length <= largoTerminacion
      ? identificador
      : identificador.substring(identificador.length - largoTerminacion);

  /// UUID de la credencial; con él se reporta como perdida.
  final String id;

  /// Tag propio, tag de casetas, NFC o QR.
  final TipoCredencial tipo;

  /// Activa, perdida, revocada o vencida.
  final EstadoCredencial estado;

  /// Últimos cuatro caracteres del identificador.
  final String terminacion;

  /// Hasta cuándo sirve, o `null` si no tiene fecha.
  final DateTime? vigencia;

  /// Representación en la API.
  Map<String, Object?> toJson() => {
    'id': id,
    'tipo': tipo.nombre,
    'estado': estado.nombre,
    'terminacion': terminacion,
    'vigencia': fechaAJson(vigencia),
  };
}

/// Persona que puede usar un vehículo.
class UsuarioAutorizado {
  /// Crea el usuario autorizado.
  const UsuarioAutorizado({required this.nombre, required this.esTitular});

  /// Lee un usuario autorizado de la respuesta de la API.
  factory UsuarioAutorizado.fromJson(Map<String, dynamic> json) =>
      UsuarioAutorizado(
        nombre: exigirCampo(json['nombre'], 'nombre'),
        esTitular: exigirCampo(json['es_titular'], 'es_titular'),
      );

  /// Nombre completo.
  final String nombre;

  /// Si es el titular del vehículo.
  final bool esTitular;

  /// Representación en la API.
  Map<String, Object?> toJson() => {'nombre': nombre, 'es_titular': esTitular};
}

/// Vehículo como aparece en la lista "Mis vehículos".
class VehiculoResumen {
  /// Crea el resumen de un vehículo.
  const VehiculoResumen({
    required this.id,
    required this.tipo,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.estado,
    required this.esTitular,
    this.placa,
    this.fotoId,
  });

  /// Lee un vehículo de la respuesta de la API.
  factory VehiculoResumen.fromJson(Map<String, dynamic> json) =>
      VehiculoResumen(
        id: exigirCampo(json['id'], 'id'),
        tipo: exigirCampo(TipoVehiculo.deNombre(json['tipo']), 'tipo'),
        placa: json['placa'] as String?,
        marca: exigirCampo(json['marca'], 'marca'),
        modelo: exigirCampo(json['modelo'], 'modelo'),
        color: exigirCampo(json['color'], 'color'),
        estado: exigirCampo(EstadoRegistro.deNombre(json['estado']), 'estado'),
        fotoId: json['foto_id'] as String?,
        esTitular: exigirCampo(json['es_titular'], 'es_titular'),
      );

  /// UUID del vehículo.
  final String id;

  /// Auto, moto, bici o scooter.
  final TipoVehiculo tipo;

  /// Placa en mayúsculas, o `null` si no tiene (bicis y scooters).
  final String? placa;

  /// Marca.
  final String marca;

  /// Modelo.
  final String modelo;

  /// Color.
  final String color;

  /// Pendiente (su alta está en revisión) o activo.
  final EstadoRegistro estado;

  /// Id del archivo con la foto del vehículo.
  final String? fotoId;

  /// Si quien consulta es el titular (y no solo un usuario autorizado).
  final bool esTitular;

  /// Representación en la API.
  Map<String, Object?> toJson() => {
    'id': id,
    'tipo': tipo.nombre,
    'placa': placa,
    'marca': marca,
    'modelo': modelo,
    'color': color,
    'estado': estado.nombre,
    'foto_id': fotoId,
    'es_titular': esTitular,
  };
}

/// Vehículo con todo lo que muestra su pantalla de detalle.
class VehiculoDetalle extends VehiculoResumen {
  /// Crea el detalle de un vehículo.
  const VehiculoDetalle({
    required super.id,
    required super.tipo,
    required super.marca,
    required super.modelo,
    required super.color,
    required super.estado,
    required super.esTitular,
    required this.credenciales,
    required this.usuariosAutorizados,
    required this.solicitudPendiente,
    super.placa,
    super.fotoId,
    this.numeroSerie,
    this.fotoPlacaId,
  });

  /// Lee el detalle de la respuesta de la API.
  factory VehiculoDetalle.fromJson(Map<String, dynamic> json) {
    final resumen = VehiculoResumen.fromJson(json);
    return VehiculoDetalle(
      id: resumen.id,
      tipo: resumen.tipo,
      placa: resumen.placa,
      marca: resumen.marca,
      modelo: resumen.modelo,
      color: resumen.color,
      estado: resumen.estado,
      fotoId: resumen.fotoId,
      esTitular: resumen.esTitular,
      numeroSerie: json['numero_serie'] as String?,
      fotoPlacaId: json['foto_placa_id'] as String?,
      credenciales: [
        for (final credencial in exigirCampo<List<dynamic>>(
          json['credenciales'],
          'credenciales',
        ))
          CredencialResumen.fromJson(credencial as Map<String, dynamic>),
      ],
      usuariosAutorizados: [
        for (final usuario in exigirCampo<List<dynamic>>(
          json['usuarios_autorizados'],
          'usuarios_autorizados',
        ))
          UsuarioAutorizado.fromJson(usuario as Map<String, dynamic>),
      ],
      solicitudPendiente: exigirCampo(
        json['solicitud_pendiente'],
        'solicitud_pendiente',
      ),
    );
  }

  /// Número de serie, o `null` si no se capturó.
  final String? numeroSerie;

  /// Id del archivo con la foto de la placa (motos).
  final String? fotoPlacaId;

  /// Credenciales del vehículo que puede ver quien consulta.
  final List<CredencialResumen> credenciales;

  /// Usuarios con autorización vigente; el titular va primero.
  final List<UsuarioAutorizado> usuariosAutorizados;

  /// Si hay una solicitud (alta, cambio o baja) en revisión: mientras tanto
  /// no se puede crear otra sobre este vehículo.
  final bool solicitudPendiente;

  @override
  Map<String, Object?> toJson() => {
    ...super.toJson(),
    'numero_serie': numeroSerie,
    'foto_placa_id': fotoPlacaId,
    'credenciales': [for (final c in credenciales) c.toJson()],
    'usuarios_autorizados': [for (final u in usuariosAutorizados) u.toJson()],
    'solicitud_pendiente': solicitudPendiente,
  };
}
