import 'package:dio/dio.dart';

import '../../modelos/foto.dart';
import 'llamada_api.dart';

/// Rutas `/archivos` de la API.
class ArchivosApi {
  const ArchivosApi(this._dio);

  final Dio _dio;

  /// Sube [foto] y devuelve su `id`.
  Future<String> subir(Foto foto, PropositoFoto proposito) =>
      llamarApi(() async {
        final respuesta = await _dio.post<dynamic>(
          '/archivos',
          data: FormData.fromMap({
            'proposito': proposito.valor,
            // La API reconoce el tipo por el contenido; el nombre solo sirve
            // para que la parte viaje como archivo.
            'archivo': MultipartFile.fromBytes(foto.bytes, filename: 'foto'),
          }),
        );
        return cuerpoJson(respuesta)['id'] as String;
      });
}
