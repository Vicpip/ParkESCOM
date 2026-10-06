import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/local/almacen_tokens.dart';
import '../config/entorno.dart';
import 'interceptor_sesion.dart';

/// Aviso de que la API rechazó el refresh token y la sesión terminó. El
/// interceptor lo dispara y el ViewModel de sesión lo escucha; así el cliente
/// HTTP no depende de ningún ViewModel.
class AvisoSesionExpirada {
  void Function()? _alExpirar;

  /// Registra quién reacciona cuando la sesión termina.
  void escuchar(void Function() alExpirar) => _alExpirar = alExpirar;

  void dejarDeEscuchar() => _alExpirar = null;

  void avisar() => _alExpirar?.call();
}

final avisoSesionExpiradaProvider = Provider<AvisoSesionExpirada>(
  (ref) => AvisoSesionExpirada(),
);

final almacenTokensProvider = Provider<AlmacenTokens>(
  (ref) => AlmacenTokensSeguro(),
);

BaseOptions _opciones() => BaseOptions(
  baseUrl: Entorno.apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 30),
  contentType: Headers.jsonContentType,
);

/// Cliente HTTP de la API, con el token de acceso y la renovación de sesión.
/// Solo lo usan las fuentes de `data/sources/remote`.
final clienteApiProvider = Provider<Dio>((ref) {
  final sinSesion = Dio(_opciones());
  final dio = Dio(_opciones());
  dio.interceptors.add(
    InterceptorSesion(
      almacen: ref.watch(almacenTokensProvider),
      dioSinSesion: sinSesion,
      alExpirar: ref.watch(avisoSesionExpiradaProvider).avisar,
    ),
  );
  ref.onDispose(() {
    dio.close();
    sinSesion.close();
  });
  return dio;
});
