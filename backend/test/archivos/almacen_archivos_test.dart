import 'dart:io';

import 'package:backend/archivos/almacen_archivos.dart';
import 'package:test/test.dart';

const _id = '3f2b8c1e-5d4a-4f6b-9c7d-0a1b2c3d4e5f';

void main() {
  group('AlmacenArchivos.resolver', () {
    late Directory raiz;
    late AlmacenArchivos almacen;

    setUp(() {
      raiz = Directory.systemTemp.createTempSync('parkescom_almacen_');
      almacen = AlmacenArchivos(raiz.path);
    });
    tearDown(() => raiz.deleteSync(recursive: true));

    test('un nombre generado queda directamente dentro de la carpeta', () {
      for (final tipo in TipoImagen.values) {
        final archivo = almacen.resolver(AlmacenArchivos.rutaDe(_id, tipo));
        expect(archivo.parent.absolute.path, raiz.absolute.path);
      }
    });

    test('rechaza cualquier ruta que pueda salir de la carpeta', () {
      for (final ruta in [
        '../$_id.png',
        '..\\$_id.png',
        '../../etc/passwd',
        r'..\..\Windows\win.ini',
        '/etc/passwd',
        r'C:\Windows\win.ini',
        r'\\servidor\recurso\x.png',
        'sub/$_id.png',
        'sub\\$_id.png',
        './$_id.png',
        '$_id.png/..',
        '$_id.png\x00.txt',
        '$_id.png ',
        '$_id.PNG',
        '$_id.gif',
        _id,
        '..',
        '.',
        '',
        '%2e%2e%2f$_id.png',
        '.env',
      ]) {
        expect(
          () => almacen.resolver(ruta),
          throwsA(isA<RutaInsegura>()),
          reason: 'ruta: "$ruta"',
        );
      }
    });

    test('guardar, leer y borrar tampoco aceptan rutas inseguras', () async {
      const insegura = '../fuera.png';
      await expectLater(
        almacen.guardar(insegura, [1]),
        throwsA(isA<RutaInsegura>()),
      );
      await expectLater(almacen.leer(insegura), throwsA(isA<RutaInsegura>()));
      await expectLater(almacen.borrar(insegura), throwsA(isA<RutaInsegura>()));
      expect(
        File(
          '${raiz.parent.path}${Platform.pathSeparator}fuera.png',
        ).existsSync(),
        isFalse,
      );
    });

    test(
      'guarda, lee y borra un archivo; leer uno que falta da null',
      () async {
        final ruta = AlmacenArchivos.rutaDe(_id, TipoImagen.png);
        expect(await almacen.leer(ruta), isNull);
        await almacen.guardar(ruta, [1, 2, 3]);
        expect(await almacen.leer(ruta), [1, 2, 3]);
        await almacen.borrar(ruta);
        expect(await almacen.leer(ruta), isNull);
      },
    );
  });

  group('TipoImagen.detectar', () {
    test('reconoce JPEG y PNG por su firma', () {
      expect(TipoImagen.detectar([0xFF, 0xD8, 0xFF, 0xE0, 0]), TipoImagen.jpeg);
      expect(
        TipoImagen.detectar([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        TipoImagen.png,
      );
    });

    test('rechaza lo demás: vacío, texto, GIF, PDF y firmas incompletas', () {
      expect(TipoImagen.detectar([]), isNull);
      expect(TipoImagen.detectar('hola mundo'.codeUnits), isNull);
      expect(TipoImagen.detectar('GIF89a'.codeUnits), isNull);
      expect(TipoImagen.detectar('%PDF-1.7'.codeUnits), isNull);
      expect(TipoImagen.detectar('<svg xmlns="..."/>'.codeUnits), isNull);
      expect(TipoImagen.detectar([0xFF, 0xD8]), isNull);
      expect(TipoImagen.detectar([0x89, 0x50, 0x4E, 0x47]), isNull);
    });
  });
}
