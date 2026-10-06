import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/app.dart';
import 'package:parkescom/core/theme/tema.dart';

import 'falsos.dart';

/// Pantalla de un celular (dp).
const celular = Size(360, 760);

/// Ancho útil aproximado del MC33xR (pantalla de 4").
const mc33 = Size(320, 600);

/// Fija el tamaño lógico de la pantalla de la prueba.
void usarPantalla(WidgetTester tester, Size tamano) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.reset);
}

/// Monta la app completa (router incluido) con los repositorios falsos.
Future<void> montarApp(
  WidgetTester tester,
  Falsos falsos, {
  Size pantalla = celular,
}) async {
  usarPantalla(tester, pantalla);
  await tester.pumpWidget(
    ProviderScope(
      overrides: falsos.overrides,
      child: const AplicacionParkEscom(),
    ),
  );
}

/// Monta un widget suelto con el tema de la app.
Future<void> montarWidget(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(
      MaterialApp(
        theme: construirTema(),
        home: Scaffold(body: widget),
      ),
    );

/// Toca [buscador] después de desplazarlo a la vista.
Future<void> tocar(WidgetTester tester, Finder buscador) async {
  await tester.ensureVisible(buscador);
  await tester.pumpAndSettle();
  await tester.tap(buscador);
  await tester.pumpAndSettle();
}

/// Campo de texto cuya etiqueta visible es [etiqueta].
Finder campo(String etiqueta) => find.descendant(
  of: find
      .ancestor(of: find.text(etiqueta), matching: find.byType(Column))
      .first,
  matching: find.byType(TextFormField),
);
