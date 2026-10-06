import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores/excepcion_api.dart';
import '../../core/red/cliente_api.dart';
import '../modelos/foto.dart';
import '../sources/local/selector_fotos.dart';
import '../sources/remote/archivos_api.dart';

/// Fotos: tomarlas en el dispositivo y subirlas a la API. Las operaciones
/// lanzan [ExcepcionApi] si fallan.
abstract interface class FotosRepository {
  /// Abre la cámara o la galería y devuelve la foto comprimida a menos de
  /// 2 MB, o `null` si el usuario canceló.
  Future<Foto?> elegir(OrigenFoto origen);

  /// Sube [foto] y devuelve el id del archivo. El archivo todavía no queda
  /// asignado a nada.
  Future<String> subir(Foto foto, PropositoFoto proposito);
}

/// [FotosRepository] con la cámara del dispositivo y la API.
class FotosRepositoryApi implements FotosRepository {
  const FotosRepositoryApi(this._selector, this._api);

  final SelectorFotos _selector;
  final ArchivosApi _api;

  @override
  Future<Foto?> elegir(OrigenFoto origen) => _selector.elegir(origen);

  @override
  Future<String> subir(Foto foto, PropositoFoto proposito) =>
      _api.subir(foto, proposito);
}

final fotosRepositoryProvider = Provider<FotosRepository>(
  (ref) => FotosRepositoryApi(
    SelectorFotosDispositivo(),
    ArchivosApi(ref.watch(clienteApiProvider)),
  ),
);
