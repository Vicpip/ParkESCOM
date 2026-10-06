import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/componentes/campo_texto.dart';
import 'package:parkescom/core/componentes/dialogo_destructivo.dart';
import 'package:parkescom/core/componentes/estado_vacio.dart';
import 'package:parkescom/core/componentes/franja_sin_conexion.dart';
import 'package:parkescom/core/componentes/skeleton.dart';
import 'package:parkescom/core/componentes/vista_async.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/core/theme/colores.dart';
import 'package:parkescom/core/theme/medidas.dart';
import 'package:parkescom/core/theme/tema.dart';

import '../../apoyo/montaje.dart';

void main() {
  group('VistaAsync', () {
    Widget vista(
      AsyncValue<List<String>> valor, {
      VoidCallback? alReintentar,
    }) => VistaAsync<List<String>>(
      valor: valor,
      cargando: const SkeletonLista(),
      alReintentar: alReintentar,
      estaVacio: (lista) => lista.isEmpty,
      vacio: const EstadoVacio(
        icono: Icons.directions_car_outlined,
        titulo: 'Aún no tienes vehículos',
      ),
      datos: (lista) => Text(lista.join(', ')),
    );

    testWidgets('carga: muestra el skeleton', (tester) async {
      await montarWidget(tester, vista(const AsyncLoading()));

      expect(find.byType(Skeleton), findsWidgets);
    });

    testWidgets('error: muestra el mensaje y permite reintentar', (
      tester,
    ) async {
      var reintentos = 0;
      await montarWidget(
        tester,
        vista(
          const AsyncError(
            ExcepcionApi(CodigoError.sinConexion),
            StackTrace.empty,
          ),
          alReintentar: () => reintentos++,
        ),
      );

      expect(find.text('No pudimos conectar con el servidor'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);
    });

    testWidgets('vacío: muestra el estado vacío', (tester) async {
      await montarWidget(tester, vista(const AsyncData([])));

      expect(find.text('Aún no tienes vehículos'), findsOneWidget);
    });

    testWidgets('datos: muestra el contenido', (tester) async {
      await montarWidget(tester, vista(const AsyncData(['ABC-123'])));

      expect(find.text('ABC-123'), findsOneWidget);
    });
  });

  testWidgets('la franja sin conexión lleva ícono y texto', (tester) async {
    await montarWidget(tester, const FranjaSinConexion());

    expect(find.text('Sin conexión · datos guardados'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });

  testWidgets('el error de un campo va debajo, con ícono y texto', (
    tester,
  ) async {
    await montarWidget(
      tester,
      const CampoTexto(etiqueta: 'Placa', errorExterno: 'Formato inválido.'),
    );

    expect(find.text('Formato inválido.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Formato inválido.')).dy,
      greaterThan(tester.getBottomLeft(find.byType(EditableText)).dy),
    );
  });

  testWidgets('el diálogo destructivo solo confirma con su botón', (
    tester,
  ) async {
    final respuestas = <bool>[];
    await montarWidget(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => respuestas.add(
            await mostrarDialogoDestructivo(
              context,
              titulo: 'Solicitar baja',
              mensaje: 'Tu historial se conserva.',
              textoConfirmar: 'Solicitar baja',
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Solicitar baja'));
    await tester.pumpAndSettle();

    expect(respuestas, [false, true]);
  });

  test('el tema usa los colores exactos, Inter y cuerpo de 16', () {
    final tema = construirTema();

    expect(tema.colorScheme.primary, ColoresApp.primario);
    expect(tema.colorScheme.primaryContainer, ColoresApp.contenedorPrimario);
    expect(tema.colorScheme.error, ColoresApp.rechazo);
    expect(tema.colorScheme.onSurface, ColoresApp.texto);
    expect(tema.scaffoldBackgroundColor, ColoresApp.fondo);
    expect(tema.extension<ColoresEstado>()?.exito, ColoresApp.exito);
    expect(tema.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(tema.textTheme.bodyMedium?.fontSize, 16);
    expect(tema.textTheme.bodyLarge?.fontSize, 16);
    final boton = tema.filledButtonTheme.style!;
    expect(boton.minimumSize?.resolve({})?.height, Medidas.altoBoton);
    expect(
      boton.shape?.resolve({}),
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  });
}
