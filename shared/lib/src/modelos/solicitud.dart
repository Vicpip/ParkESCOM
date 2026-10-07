import '../validacion/datos_vehiculo.dart';
import 'enumeraciones.dart';
import 'json.dart';

/// Solicitud de alta, cambio o baja de un vehículo.
class Solicitud {
  /// Crea la solicitud.
  const Solicitud({
    required this.id,
    required this.usuarioId,
    required this.tipo,
    required this.estado,
    required this.creadoEn,
    this.vehiculoId,
    this.datosPropuestos,
    this.comentario,
    this.resueltaEn,
  });

  /// Lee una solicitud de la respuesta de la API.
  factory Solicitud.fromJson(Map<String, dynamic> json) {
    final datos = json['datos_propuestos'];
    return Solicitud(
      id: exigirCampo(json['id'], 'id'),
      usuarioId: exigirCampo(json['usuario_id'], 'usuario_id'),
      vehiculoId: json['vehiculo_id'] as String?,
      tipo: exigirCampo(TipoSolicitud.deNombre(json['tipo']), 'tipo'),
      estado: exigirCampo(EstadoSolicitud.deNombre(json['estado']), 'estado'),
      datosPropuestos: datos is Map<String, dynamic>
          ? DatosVehiculo.fromJson(datos)
          : null,
      comentario: json['comentario'] as String?,
      creadoEn: exigirCampo(fechaDeJson(json['creado_en']), 'creado_en'),
      resueltaEn: fechaDeJson(json['resuelta_en']),
    );
  }

  /// UUID de la solicitud.
  final String id;

  /// Quién la hizo.
  final String usuarioId;

  /// Vehículo sobre el que trata.
  final String? vehiculoId;

  /// Alta, cambio o baja.
  final TipoSolicitud tipo;

  /// Pendiente, aprobada o rechazada.
  final EstadoSolicitud estado;

  /// Datos capturados en un alta o un cambio; `null` en una baja.
  final DatosVehiculo? datosPropuestos;

  /// Comentario de Administración al resolverla (obligatorio en un rechazo).
  final String? comentario;

  /// Cuándo se creó.
  final DateTime creadoEn;

  /// Cuándo se resolvió, o `null` si sigue pendiente.
  final DateTime? resueltaEn;

  /// Representación en la API.
  Map<String, Object?> toJson() => {
    'id': id,
    'usuario_id': usuarioId,
    'vehiculo_id': vehiculoId,
    'tipo': tipo.nombre,
    'estado': estado.nombre,
    'datos_propuestos': datosPropuestos?.toJson(),
    'comentario': comentario,
    'creado_en': fechaAJson(creadoEn),
    'resuelta_en': fechaAJson(resueltaEn),
  };
}
