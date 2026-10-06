import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../modelos/sesion.dart';

/// Dónde viven los tokens de la sesión.
abstract interface class AlmacenTokens {
  /// Tokens guardados, o `null` si no hay sesión.
  Future<Tokens?> leer();

  Future<void> guardar(Tokens tokens);

  Future<void> borrar();
}

/// Tokens en el almacenamiento seguro del dispositivo.
class AlmacenTokensSeguro implements AlmacenTokens {
  AlmacenTokensSeguro([this._almacen = const FlutterSecureStorage()]);

  static const _claveAcceso = 'access_token';
  static const _claveRefresh = 'refresh_token';

  final FlutterSecureStorage _almacen;

  // Copia en memoria para no leer el almacenamiento en cada petición.
  Tokens? _tokens;
  bool _leido = false;

  @override
  Future<Tokens?> leer() async {
    if (_leido) return _tokens;
    final acceso = await _almacen.read(key: _claveAcceso);
    final refresh = await _almacen.read(key: _claveRefresh);
    _tokens = acceso == null || refresh == null
        ? null
        : Tokens(acceso: acceso, refresh: refresh);
    _leido = true;
    return _tokens;
  }

  @override
  Future<void> guardar(Tokens tokens) async {
    _tokens = tokens;
    _leido = true;
    await _almacen.write(key: _claveAcceso, value: tokens.acceso);
    await _almacen.write(key: _claveRefresh, value: tokens.refresh);
  }

  @override
  Future<void> borrar() async {
    _tokens = null;
    _leido = true;
    await _almacen.delete(key: _claveAcceso);
    await _almacen.delete(key: _claveRefresh);
  }
}

/// Tokens solo en memoria, para las pruebas.
class AlmacenTokensMemoria implements AlmacenTokens {
  AlmacenTokensMemoria([this._tokens]);

  Tokens? _tokens;

  @override
  Future<Tokens?> leer() async => _tokens;

  @override
  Future<void> guardar(Tokens tokens) async => _tokens = tokens;

  @override
  Future<void> borrar() async => _tokens = null;
}
