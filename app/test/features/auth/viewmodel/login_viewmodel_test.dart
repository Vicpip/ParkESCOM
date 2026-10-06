import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/core/errores/mensajes_error.dart';
import 'package:parkescom/features/auth/viewmodel/login_viewmodel.dart';
import 'package:parkescom/features/auth/viewmodel/sesion_viewmodel.dart';

import '../../../apoyo/falsos.dart';

void main() {
  late Falsos falsos;
  late ProviderContainer contenedor;

  setUp(() {
    falsos = Falsos();
    contenedor = ProviderContainer.test(overrides: falsos.overrides);
    // Mantiene vivo el ViewModel, como lo haría la pantalla.
    contenedor.listen(loginProvider, (_, _) {});
  });

  Future<void> entrar({
    String correo = 'Ana@Alumno.ipn.mx ',
    String password = 'secreta123',
  }) => contenedor
      .read(loginProvider.notifier)
      .iniciarSesion(correo: correo, password: password);

  test('éxito: abre la sesión con el usuario y normaliza el correo', () async {
    await entrar();

    final sesion = contenedor.read(sesionProvider);
    expect(sesion, isA<ConSesion>());
    expect((sesion as ConSesion).usuario.nombre, 'Ana Prueba');
    expect(falsos.auth.ultimoCorreo, 'ana@alumno.ipn.mx');
    final estado = contenedor.read(loginProvider);
    expect(estado.enviando, isFalse);
    expect(estado.error, isNull);
  });

  test('credenciales inválidas: deja el error y no abre sesión', () async {
    falsos.auth.errorLogin = const ExcepcionApi(
      CodigoError.credencialesInvalidas,
      estadoHttp: 401,
    );

    await entrar();

    final estado = contenedor.read(loginProvider);
    expect(estado.error?.codigo, CodigoError.credencialesInvalidas);
    expect(estado.enviando, isFalse);
    expect(contenedor.read(sesionProvider), isNot(isA<ConSesion>()));
  });

  test('demasiados intentos: mensaje distinto al de credenciales', () async {
    falsos.auth.errorLogin = const ExcepcionApi(
      CodigoError.demasiadosIntentos,
      estadoHttp: 429,
    );

    await entrar();

    final error = contenedor.read(loginProvider).error!;
    expect(error.codigo, CodigoError.demasiadosIntentos);
    expect(
      error.mensaje(ContextoError.inicioSesion),
      isNot(mensajeDeError(CodigoError.credencialesInvalidas)),
    );
    expect(error.mensaje(ContextoError.inicioSesion), contains('intentos'));
  });

  test('red caída: error de red y se puede reintentar', () async {
    falsos.auth.errorLogin = const ExcepcionApi(CodigoError.sinConexion);

    await entrar();
    expect(contenedor.read(loginProvider).error?.esDeRed, isTrue);

    falsos.auth.errorLogin = null;
    await entrar();
    expect(contenedor.read(sesionProvider), isA<ConSesion>());
    expect(falsos.auth.inicios, 2);
  });

  test('validación: campos inválidos no llegan al repositorio', () async {
    await entrar(correo: 'no-es-correo', password: '');

    final estado = contenedor.read(loginProvider);
    expect(estado.erroresCampos, {
      CampoLogin.correo: 'CORREO_INVALIDO',
      CampoLogin.password: CodigoError.campoRequerido,
    });
    expect(falsos.auth.inicios, 0);

    contenedor
        .read(loginProvider.notifier)
        .limpiarErrorCampo(CampoLogin.correo);
    expect(contenedor.read(loginProvider).erroresCampos.keys, [
      CampoLogin.password,
    ]);
  });
}
