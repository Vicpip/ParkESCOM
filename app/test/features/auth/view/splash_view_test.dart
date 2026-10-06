import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/data/modelos/usuario.dart';
import 'package:parkescom/features/auth/view/login_view.dart';
import 'package:parkescom/features/auth/view/splash_view.dart';

import '../../../apoyo/falsos.dart';
import '../../../apoyo/montaje.dart';

void main() {
  testWidgets('muestra la marca y la carga mientras revisa la sesión', (
    tester,
  ) async {
    final falsos = Falsos();
    falsos.auth.esperaRestaurar = Completer<void>();

    await montarApp(tester, falsos);
    await tester.pump();

    expect(find.byType(SplashView), findsOneWidget);
    expect(find.text('ParkESCOM'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    falsos.auth.esperaRestaurar!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('sin sesión manda al inicio de sesión', (tester) async {
    await montarApp(tester, Falsos());
    await tester.pumpAndSettle();

    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('con sesión de usuario manda a su inicio con la barra inferior', (
    tester,
  ) async {
    final falsos = Falsos()..auth.sesionGuardada = usuarioCompleto();

    await montarApp(tester, falsos);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final destino in ['Inicio', 'Vehículos', 'Historial', 'Perfil']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(destino),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('en tablet la navegación va en un riel lateral', (tester) async {
    final falsos = Falsos()..auth.sesionGuardada = usuarioCompleto();

    await montarApp(tester, falsos, pantalla: const Size(800, 1280));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('cada rol llega a su propia pantalla', (tester) async {
    final falsos = Falsos()
      ..auth.sesionGuardada = usuarioCompleto(rol: Rol.guardia);

    await montarApp(tester, falsos);
    await tester.pumpAndSettle();

    expect(find.text('Caseta'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('sin red ofrece reintentar y conserva la sesión', (tester) async {
    final falsos = Falsos()
      ..auth.sesionGuardada = usuarioCompleto()
      ..auth.errorRestaurar = const ExcepcionApi(CodigoError.sinConexion);

    await montarApp(tester, falsos);
    await tester.pumpAndSettle();

    expect(find.text('No pudimos conectar con el servidor'), findsOneWidget);
    expect(find.byType(LoginView), findsNothing);

    falsos.auth.errorRestaurar = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
