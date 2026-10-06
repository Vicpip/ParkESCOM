import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/features/auth/viewmodel/recuperar_viewmodel.dart';

import '../../../apoyo/falsos.dart';

void main() {
  late Falsos falsos;
  late ProviderContainer contenedor;

  setUp(() {
    falsos = Falsos();
    contenedor = ProviderContainer.test(overrides: falsos.overrides);
    contenedor.listen(recuperarProvider, (_, _) {});
  });

  RecuperarViewModel vm() => contenedor.read(recuperarProvider.notifier);
  EstadoRecuperar estado() => contenedor.read(recuperarProvider);

  test('éxito: marca enviado y manda el correo normalizado', () async {
    await vm().enviar(' Ana@IPN.mx');

    expect(estado().enviado, isTrue);
    expect(estado().error, isNull);
    expect(falsos.auth.correosRecuperacion, ['ana@ipn.mx']);
  });

  test('demasiados intentos: deja el error y no marca enviado', () async {
    falsos.auth.errorRecuperacion = const ExcepcionApi(
      CodigoError.demasiadosIntentos,
      estadoHttp: 429,
    );

    await vm().enviar('ana@ipn.mx');

    expect(estado().enviado, isFalse);
    expect(estado().error?.codigo, CodigoError.demasiadosIntentos);
  });

  test('red caída: error de red', () async {
    falsos.auth.errorRecuperacion = const ExcepcionApi(CodigoError.sinConexion);

    await vm().enviar('ana@ipn.mx');

    expect(estado().error?.esDeRed, isTrue);
  });

  test('validación: un correo mal escrito no llega al repositorio', () async {
    await vm().enviar('ana@');

    expect(estado().errorCorreo, 'CORREO_INVALIDO');
    expect(falsos.auth.correosRecuperacion, isEmpty);

    vm().alCambiarCorreo();
    expect(estado().errorCorreo, isNull);
  });
}
