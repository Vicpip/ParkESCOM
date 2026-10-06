import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/features/auth/view/login_view.dart';
import 'package:parkescom/features/auth/view/recuperar_view.dart';
import 'package:parkescom/features/auth/view/registro_view.dart';

import '../../../apoyo/falsos.dart';
import '../../../apoyo/montaje.dart';

void main() {
  Future<Falsos> abrir(WidgetTester tester, {Size pantalla = celular}) async {
    final falsos = Falsos();
    await montarApp(tester, falsos, pantalla: pantalla);
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
    return falsos;
  }

  Future<void> entrar(WidgetTester tester) async {
    await tester.enterText(campo('Correo institucional'), 'ana@alumno.ipn.mx');
    await tester.enterText(campo('Contraseña'), 'secreta123');
    await tocar(tester, find.text('Iniciar sesión'));
  }

  testWidgets('valida en vivo el correo mientras se escribe', (tester) async {
    await abrir(tester);

    await tester.enterText(campo('Correo institucional'), 'ana@');
    await tester.pump();
    expect(find.textContaining('Escribe un correo válido'), findsOneWidget);

    await tester.enterText(campo('Correo institucional'), 'ana@ipn.mx');
    await tester.pump();
    expect(find.textContaining('Escribe un correo válido'), findsNothing);
  });

  testWidgets('con campos vacíos no llama a la API', (tester) async {
    final falsos = await abrir(tester);

    await tocar(tester, find.text('Iniciar sesión'));

    expect(find.text('Este campo es obligatorio.'), findsNWidgets(2));
    expect(falsos.auth.inicios, 0);
  });

  testWidgets('inicio correcto lleva a la pantalla de inicio', (tester) async {
    final falsos = await abrir(tester);

    await entrar(tester);

    expect(falsos.auth.inicios, 1);
    expect(find.byType(LoginView), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('credenciales inválidas y demasiados intentos muestran '
      'mensajes distintos', (tester) async {
    final falsos = await abrir(tester);

    falsos.auth.errorLogin = const ExcepcionApi(
      CodigoError.credencialesInvalidas,
      estadoHttp: 401,
    );
    await entrar(tester);
    expect(
      find.text('El correo o la contraseña no coinciden.'),
      findsOneWidget,
    );

    falsos.auth.errorLogin = const ExcepcionApi(
      CodigoError.demasiadosIntentos,
      estadoHttp: 429,
    );
    await tocar(tester, find.text('Iniciar sesión'));
    expect(find.text('El correo o la contraseña no coinciden.'), findsNothing);
    expect(find.textContaining('Demasiados intentos fallidos'), findsOneWidget);
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('sin red muestra el mensaje de conexión', (tester) async {
    final falsos = await abrir(tester);
    falsos.auth.errorLogin = const ExcepcionApi(CodigoError.sinConexion);

    await entrar(tester);

    expect(find.textContaining('No pudimos conectar'), findsOneWidget);
  });

  testWidgets('enlaza al registro y a la recuperación', (tester) async {
    await abrir(tester);

    await tocar(tester, find.text('Crear cuenta'));
    expect(find.byType(RegistroView), findsOneWidget);

    await tocar(tester, find.byType(BackButton));
    expect(find.byType(LoginView), findsOneWidget);

    await tocar(tester, find.text('¿Olvidaste tu contraseña?'));
    expect(find.byType(RecuperarView), findsOneWidget);
  });

  testWidgets('cabe en la pantalla del MC33xR sin desbordarse', (tester) async {
    await abrir(tester, pantalla: mc33);
    await tocar(tester, find.text('Iniciar sesión'));

    expect(tester.takeException(), isNull);
  });
}
