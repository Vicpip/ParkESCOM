import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/features/auth/view/login_view.dart';
import 'package:parkescom/features/auth/view/recuperar_view.dart';

import '../../../apoyo/falsos.dart';
import '../../../apoyo/montaje.dart';

void main() {
  Future<Falsos> abrir(WidgetTester tester) async {
    final falsos = Falsos();
    await montarApp(tester, falsos);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('¿Olvidaste tu contraseña?'));
    expect(find.byType(RecuperarView), findsOneWidget);
    return falsos;
  }

  testWidgets('envía el correo y muestra un mensaje neutro', (tester) async {
    final falsos = await abrir(tester);

    await tester.enterText(campo('Correo institucional'), 'ana@ipn.mx');
    await tocar(tester, find.text('Enviar enlace'));

    expect(falsos.auth.correosRecuperacion, ['ana@ipn.mx']);
    expect(find.text('Revisa tu correo'), findsOneWidget);
    // No afirma que la cuenta exista.
    expect(find.textContaining('Si el correo está registrado'), findsOneWidget);
  });

  testWidgets('un correo mal escrito no se envía', (tester) async {
    final falsos = await abrir(tester);

    await tester.enterText(campo('Correo institucional'), 'ana');
    await tocar(tester, find.text('Enviar enlace'));

    expect(find.textContaining('Escribe un correo válido'), findsOneWidget);
    expect(falsos.auth.correosRecuperacion, isEmpty);
  });

  testWidgets('demasiadas solicitudes muestran su propio mensaje', (
    tester,
  ) async {
    final falsos = await abrir(tester);
    falsos.auth.errorRecuperacion = const ExcepcionApi(
      CodigoError.demasiadosIntentos,
      estadoHttp: 429,
    );

    await tester.enterText(campo('Correo institucional'), 'ana@ipn.mx');
    await tocar(tester, find.text('Enviar enlace'));

    expect(find.textContaining('Ya pediste varios enlaces'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
  });

  testWidgets('regresa al inicio de sesión', (tester) async {
    await abrir(tester);

    await tocar(tester, find.text('Volver a iniciar sesión'));

    expect(find.byType(LoginView), findsOneWidget);
  });
}
