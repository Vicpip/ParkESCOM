import 'package:dio/dio.dart';

import '../../../core/errores/codigos_error.dart';
import '../../../core/errores/excepcion_api.dart';

/// Ejecuta una llamada a la API y convierte cualquier falla en
/// [ExcepcionApi]: errores de dio y respuestas que no tienen la forma
/// esperada.
Future<T> llamarApi<T>(Future<T> Function() accion) async {
  try {
    return await accion();
  } on DioException catch (error) {
    throw ExcepcionApi.deDio(error);
  } on ExcepcionApi {
    rethrow;
  } on Object {
    throw const ExcepcionApi(CodigoError.respuestaInesperada);
  }
}

/// Cuerpo de [respuesta] como objeto JSON.
Map<String, dynamic> cuerpoJson(Response<dynamic> respuesta) =>
    respuesta.data as Map<String, dynamic>;
