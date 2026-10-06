import 'package:dio/dio.dart';

import '../../modelos/usuario.dart';
import 'llamada_api.dart';

/// Rutas `/perfil` de la API.
class PerfilApi {
  const PerfilApi(this._dio);

  final Dio _dio;

  /// `PATCH /perfil` con los campos de [cambios]; devuelve el usuario
  /// actualizado.
  Future<Usuario> actualizar(Map<String, Object?> cambios) =>
      llamarApi(() async {
        final respuesta = await _dio.patch<dynamic>('/perfil', data: cambios);
        return Usuario.deJson(
          cuerpoJson(respuesta)['usuario'] as Map<String, dynamic>,
        );
      });
}
