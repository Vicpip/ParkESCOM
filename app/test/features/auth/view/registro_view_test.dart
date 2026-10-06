import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/data/modelos/foto.dart';
import 'package:parkescom/features/auth/view/registro_view.dart';

import '../../../apoyo/falsos.dart';
import '../../../apoyo/montaje.dart';

void main() {
  Future<Falsos> abrir(WidgetTester tester, {Size pantalla = celular}) async {
    final falsos = Falsos();
    await montarApp(tester, falsos, pantalla: pantalla);
    await tester.pumpAndSettle();
    await tocar(tester, find.text('Crear cuenta'));
    expect(find.byType(RegistroView), findsOneWidget);
    return falsos;
  }

  Future<void> llenarDatos(WidgetTester tester) async {
    await tester.enterText(campo('Nombre completo'), 'Ana Prueba');
    await tester.enterText(campo('Correo institucional'), 'ana@alumno.ipn.mx');
    await tester.enterText(campo('Boleta o número de empleado'), '2024630001');
    await tester.enterText(campo('Contraseña'), 'secreta123');
    await tester.pump();
  }

  Future<void> elegirFotos(WidgetTester tester) async {
    for (final origen in ['Tomar foto', 'Elegir de la galería']) {
      await tocar(tester, find.text('Agregar foto').first);
      await tester.tap(find.text(origen));
      await tester.pumpAndSettle();
    }
    expect(find.text('Cambiar foto'), findsNWidgets(2));
  }

  testWidgets('valida en vivo cada campo con las reglas compartidas', (
    tester,
  ) async {
    await abrir(tester);

    await tester.enterText(campo('Correo institucional'), 'ana@gmail.com');
    await tester.enterText(campo('Boleta o número de empleado'), '12');
    await tester.enterText(campo('Contraseña'), 'sololetras');
    await tester.pump();

    expect(find.text('Usa tu correo institucional.'), findsOneWidget);
    expect(find.textContaining('Escribe tu boleta'), findsOneWidget);
    expect(find.text('Incluye al menos un número.'), findsOneWidget);

    // 37 letras con acento pasan de 72 bytes aunque sean 38 caracteres.
    await tester.enterText(campo('Contraseña'), '${'á' * 37}1');
    await tester.pump();
    expect(find.textContaining('demasiado larga'), findsOneWidget);
  });

  testWidgets('las fotos y el aviso de privacidad son obligatorios', (
    tester,
  ) async {
    final falsos = await abrir(tester);
    await llenarDatos(tester);

    await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

    expect(find.text('Esta foto es obligatoria.'), findsNWidgets(2));
    expect(find.textContaining('debes aceptar el aviso'), findsOneWidget);
    expect(falsos.auth.registros, 0);
  });

  testWidgets('el aviso de privacidad se puede leer', (tester) async {
    await abrir(tester);

    await tocar(tester, find.text('aviso de privacidad'));

    expect(find.text('Aviso de privacidad'), findsOneWidget);
    expect(find.text('Quién puede verlos'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Quién puede verlos'), findsNothing);
  });

  testWidgets('registro completo lleva al inicio con el aviso de cuenta '
      'pendiente', (tester) async {
    final falsos = await abrir(tester);
    await llenarDatos(tester);
    await elegirFotos(tester);
    await tocar(tester, find.byType(Checkbox));

    await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

    expect(falsos.auth.registros, 1);
    expect(falsos.fotos.subidas, hasLength(2));
    expect(find.byType(RegistroView), findsNothing);
    expect(find.text('Tu cuenta está en revisión'), findsOneWidget);
    expect(find.text('Te faltan fotos'), findsNothing);
  });

  testWidgets('si falla una foto, la cuenta queda creada y solo se reintenta '
      'la foto', (tester) async {
    final falsos = await abrir(tester);
    falsos.fotos.respuestas[PropositoFoto.credencialEscolar] = [
      const ExcepcionApi(CodigoError.archivoMuyGrande, estadoHttp: 413),
    ];
    await llenarDatos(tester);
    await elegirFotos(tester);
    await tocar(tester, find.byType(Checkbox));

    await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

    // Sigue en el registro, ya sin el formulario de datos.
    expect(find.byType(RegistroView), findsOneWidget);
    expect(find.text('Tu cuenta ya fue creada'), findsOneWidget);
    expect(find.text('Nombre completo'), findsNothing);
    expect(find.text('Foto subida'), findsOneWidget);
    expect(find.textContaining('pesa más de 2 MB'), findsOneWidget);

    await tocar(tester, find.text('Subir fotos'));

    expect(falsos.auth.registros, 1);
    expect(falsos.fotos.subidas, hasLength(3));
    expect(find.text('Tu cuenta está en revisión'), findsOneWidget);
  });

  testWidgets('quien dejó el registro a medias puede completarlo desde el '
      'inicio', (tester) async {
    final falsos = Falsos()..auth.sesionGuardada = usuarioDePrueba();
    await montarApp(tester, falsos);
    await tester.pumpAndSettle();

    expect(find.text('Te faltan fotos'), findsOneWidget);
    await tocar(tester, find.text('Completar registro'));

    expect(find.byType(RegistroView), findsOneWidget);
    expect(find.text('Tu cuenta ya fue creada'), findsOneWidget);
    await elegirFotos(tester);
    await tocar(tester, find.text('Subir fotos'));

    expect(falsos.auth.registros, 0);
    expect(falsos.perfil.asignaciones, hasLength(1));
    expect(find.text('Te faltan fotos'), findsNothing);
  });

  testWidgets('cabe en la pantalla del MC33xR sin desbordarse', (tester) async {
    await abrir(tester, pantalla: mc33);
    await llenarDatos(tester);
    await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

    expect(tester.takeException(), isNull);
  });
}
