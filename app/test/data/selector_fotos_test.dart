import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/data/sources/local/selector_fotos.dart';

void main() {
  Uint8List bytes(int cantidad) => Uint8List(cantidad);

  test('usa la primera calidad que baja del límite', () async {
    final calidades = <int>[];

    final resultado = await comprimirBajoElLimite(bytes(5000), (
      _,
      calidad,
    ) async {
      calidades.add(calidad);
      return bytes(calidad * 20);
    }, limite: 1200);

    expect(calidades, [80, 65, 50]);
    expect(resultado.length, 1000);
  });

  test('si ninguna calidad alcanza, avisa que la foto es muy grande', () {
    expect(
      comprimirBajoElLimite(
        bytes(5000),
        (_, _) async => bytes(3000),
        limite: 1200,
      ),
      throwsA(
        isA<ExcepcionApi>().having(
          (error) => error.codigo,
          'codigo',
          CodigoError.archivoMuyGrande,
        ),
      ),
    );
  });

  test('si no se puede comprimir, usa el original cuando ya cabe', () async {
    final original = bytes(800);

    final resultado = await comprimirBajoElLimite(
      original,
      (_, _) async => throw UnsupportedError('formato'),
      limite: 1200,
    );

    expect(resultado, same(original));
  });

  test('el límite por omisión es el de la API: 2 MB', () {
    expect(tamanoMaximoFoto, 2 * 1024 * 1024);
  });
}
