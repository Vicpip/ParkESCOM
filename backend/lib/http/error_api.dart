import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

/// Error que la API le responde al cliente con el formato uniforme
/// `{"error": {"code": "SNAKE_CASE", "message": "texto para el usuario"}}`.
///
/// Las rutas y los servicios lo lanzan; el middleware de errores lo convierte
/// en respuesta.
class ErrorApi implements Exception {
  /// Crea un error con su código HTTP ([estado]), su [codigo] y su [mensaje].
  const ErrorApi(this.estado, this.codigo, this.mensaje, {this.campos});

  /// 400: el cuerpo no es un objeto JSON.
  const ErrorApi.solicitudInvalida()
    : this(
        HttpStatus.badRequest,
        'SOLICITUD_INVALIDA',
        'La solicitud no tiene el formato esperado.',
      );

  /// 401: falta el token de acceso, no es válido o ya venció.
  const ErrorApi.noAutenticado()
    : this(
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
        'Inicia sesión para continuar.',
      );

  /// 403: el rol del usuario no alcanza para la operación.
  const ErrorApi.sinPermiso()
    : this(
        HttpStatus.forbidden,
        'SIN_PERMISO',
        'No tienes permiso para realizar esta acción.',
      );

  /// 422: uno o más campos no pasaron la validación. [campos] lleva, por
  /// cada campo con error, su código (por ejemplo `CORREO_INVALIDO`).
  const ErrorApi.validacion(Map<String, String> campos)
    : this(
        HttpStatus.unprocessableEntity,
        'VALIDACION',
        'Revisa los datos marcados.',
        campos: campos,
      );

  /// Código HTTP de la respuesta.
  final int estado;

  /// Código estable del error, en `SNAKE_CASE` mayúsculas.
  final String codigo;

  /// Texto que se le puede mostrar al usuario.
  final String mensaje;

  /// Solo en `VALIDACION`: código de error de cada campo.
  final Map<String, String>? campos;

  /// Respuesta HTTP con el formato uniforme de error.
  Response aRespuesta() => Response.json(
    statusCode: estado,
    body: {
      'error': {'code': codigo, 'message': mensaje, 'campos': ?campos},
    },
  );

  @override
  String toString() => 'ErrorApi($estado, $codigo)';
}

/// Lanza un 405 `METODO_NO_PERMITIDO` si la petición no usa [metodo].
void exigirMetodo(RequestContext context, HttpMethod metodo) {
  if (context.request.method != metodo) {
    throw const ErrorApi(
      HttpStatus.methodNotAllowed,
      'METODO_NO_PERMITIDO',
      'Método no permitido.',
    );
  }
}

/// Lee el cuerpo de la petición como objeto JSON.
///
/// Lanza [ErrorApi.solicitudInvalida] si no lo es.
Future<Map<String, dynamic>> leerJson(RequestContext context) async {
  final Object? json;
  try {
    json = jsonDecode(await context.request.body());
  } on FormatException {
    throw const ErrorApi.solicitudInvalida();
  }
  if (json is! Map<String, dynamic>) throw const ErrorApi.solicitudInvalida();
  return json;
}

/// Valor de texto del campo [nombre], o cadena vacía si falta o no es texto
/// (los validadores rechazan después el valor vacío).
String campoTexto(Map<String, dynamic> json, String nombre) {
  final valor = json[nombre];
  return valor is String ? valor : '';
}
