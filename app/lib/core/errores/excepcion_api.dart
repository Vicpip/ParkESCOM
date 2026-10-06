import 'package:dio/dio.dart';

import 'codigos_error.dart';
import 'mensajes_error.dart';

/// Error tipado que cruza todas las capas de la app: una respuesta de error
/// de la API (`{"error": {"code", "message", "campos"}}`) o una falla local
/// (sin conexión, respuesta ilegible).
class ExcepcionApi implements Exception {
  const ExcepcionApi(
    this.codigo, {
    this.estadoHttp,
    this.mensajeServidor,
    this.campos = const {},
  });

  /// Convierte un error de dio. Nunca conserva el cuerpo ni las cabeceras de
  /// la petición, que pueden llevar contraseñas o tokens.
  factory ExcepcionApi.deDio(DioException error) {
    final respuesta = error.response;
    if (respuesta == null) {
      final previa = error.error;
      if (previa is ExcepcionApi) return previa;
      return const ExcepcionApi(CodigoError.sinConexion);
    }
    final estado = respuesta.statusCode;
    final cuerpo = respuesta.data;
    final detalle = cuerpo is Map ? cuerpo['error'] : null;
    if (detalle is Map && detalle['code'] is String) {
      final campos = detalle['campos'];
      final mensaje = detalle['message'];
      return ExcepcionApi(
        detalle['code'] as String,
        estadoHttp: estado,
        mensajeServidor: mensaje is String ? mensaje : null,
        campos: campos is Map
            ? {
                for (final entrada in campos.entries)
                  if (entrada.key is String && entrada.value is String)
                    entrada.key as String: entrada.value as String,
              }
            : const {},
      );
    }
    // Un proxy puede rechazar la foto antes de que llegue a la API.
    if (estado == 413) {
      return ExcepcionApi(CodigoError.archivoMuyGrande, estadoHttp: estado);
    }
    return ExcepcionApi(CodigoError.respuestaInesperada, estadoHttp: estado);
  }

  /// Código estable del error (`CodigoError`).
  final String codigo;

  /// Código HTTP, si el error vino de una respuesta.
  final int? estadoHttp;

  /// Mensaje que mandó la API; solo se usa si la app no conoce el código.
  final String? mensajeServidor;

  /// En `VALIDACION`: código de error de cada campo.
  final Map<String, String> campos;

  /// No hubo respuesta del servidor.
  bool get esDeRed => codigo == CodigoError.sinConexion;

  /// La sesión ya no sirve y hay que volver a iniciar.
  bool get esDeSesion =>
      codigo == CodigoError.noAutenticado ||
      codigo == CodigoError.refreshInvalido;

  /// Texto para el usuario.
  String mensaje([ContextoError contexto = ContextoError.general]) =>
      mensajeDeError(codigo, contexto: contexto, respaldo: mensajeServidor);

  @override
  String toString() => 'ExcepcionApi($codigo)';
}
