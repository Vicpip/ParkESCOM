import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errores/excepcion_api.dart';
import '../../core/red/cliente_api.dart';
import '../modelos/usuario.dart';
import '../sources/remote/perfil_api.dart';

/// Perfil del usuario con la sesión abierta. Las operaciones lanzan
/// [ExcepcionApi] si fallan.
abstract interface class PerfilRepository {
  /// Asigna al perfil la foto del titular y la de su credencial (ids de
  /// archivos ya subidos) y devuelve el usuario actualizado. Solo funciona
  /// mientras la cuenta está pendiente; después la API responde
  /// `PERFIL_BLOQUEADO`.
  Future<Usuario> asignarFotos({
    required String fotoTitularId,
    required String fotoCredencialId,
  });
}

/// [PerfilRepository] contra la API.
class PerfilRepositoryApi implements PerfilRepository {
  const PerfilRepositoryApi(this._api);

  final PerfilApi _api;

  @override
  Future<Usuario> asignarFotos({
    required String fotoTitularId,
    required String fotoCredencialId,
  }) => _api.actualizar({
    'foto_titular_id': fotoTitularId,
    'foto_credencial_id': fotoCredencialId,
  });
}

final perfilRepositoryProvider = Provider<PerfilRepository>(
  (ref) => PerfilRepositoryApi(PerfilApi(ref.watch(clienteApiProvider))),
);
