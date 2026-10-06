import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/core/red/cliente_api.dart';
import 'package:parkescom/data/modelos/usuario.dart';
import 'package:parkescom/features/auth/viewmodel/sesion_viewmodel.dart';

import '../../../apoyo/falsos.dart';

void main() {
  late Falsos falsos;
  late ProviderContainer contenedor;

  setUp(() {
    falsos = Falsos();
    contenedor = ProviderContainer.test(overrides: falsos.overrides);
  });

  /// Lee la sesión y espera a que termine la comprobación del arranque.
  Future<EstadoSesion> arrancar() async {
    expect(contenedor.read(sesionProvider), isA<SesionVerificando>());
    await pumpEventQueue();
    return contenedor.read(sesionProvider);
  }

  test('con sesión guardada: queda abierta con su rol', () async {
    falsos.auth.sesionGuardada = usuarioCompleto(rol: Rol.guardia);

    final sesion = await arrancar();

    expect(sesion, isA<ConSesion>());
    expect((sesion as ConSesion).usuario.rol, Rol.guardia);
  });

  test('sin sesión guardada: queda sin sesión', () async {
    expect(await arrancar(), isA<SinSesion>());
  });

  test('red caída al arrancar: se puede reintentar', () async {
    falsos.auth
      ..sesionGuardada = usuarioCompleto()
      ..errorRestaurar = const ExcepcionApi(CodigoError.sinConexion);

    final sesion = await arrancar();
    expect(sesion, isA<SesionSinVerificar>());
    expect((sesion as SesionSinVerificar).error.esDeRed, isTrue);

    falsos.auth.errorRestaurar = null;
    await contenedor.read(sesionProvider.notifier).verificar();
    expect(contenedor.read(sesionProvider), isA<ConSesion>());
    expect(falsos.auth.restauraciones, 2);
  });

  test('cerrar sesión: llama al repositorio y queda sin sesión', () async {
    falsos.auth.sesionGuardada = usuarioCompleto();
    await arrancar();

    await contenedor.read(sesionProvider.notifier).cerrarSesion();

    expect(contenedor.read(sesionProvider), isA<SinSesion>());
    expect(falsos.auth.cierres, 1);
  });

  test('la API rechaza el refresh token: la sesión termina', () async {
    falsos.auth.sesionGuardada = usuarioCompleto();
    await arrancar();

    contenedor.read(avisoSesionExpiradaProvider).avisar();

    expect(contenedor.read(sesionProvider), isA<SinSesion>());
  });

  test('una comprobación en camino no pisa un inicio de sesión', () async {
    // La sesión se establece antes de que corra la comprobación del arranque.
    contenedor.read(sesionProvider);
    contenedor.read(sesionProvider.notifier).establecer(usuarioCompleto());
    await pumpEventQueue();

    expect(contenedor.read(sesionProvider), isA<ConSesion>());
    expect(falsos.auth.restauraciones, 0);
  });
}
