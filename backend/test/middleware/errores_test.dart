import 'dart:convert';
import 'dart:io';

import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/errores.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _ContextoFalso extends Mock implements RequestContext {}

void main() {
  late RequestContext contexto;
  late List<String> bitacora;

  setUp(() {
    bitacora = [];
    contexto = _ContextoFalso();
    when(() => contexto.request).thenReturn(
      Request.post(
        Uri.parse('http://localhost/auth/login?token=en-la-url'),
        headers: {'Authorization': 'Bearer token-de-acceso'},
        body: '{"correo": "a@ipn.mx", "password": "Secreta-2026"}',
      ),
    );
  });

  Future<Response> ejecutar(Handler handler) async =>
      errores(registrar: bitacora.add)(handler)(contexto);

  test('un ErrorApi se responde con su código y no se anota', () async {
    final respuesta = await ejecutar(
      (_) => throw const ErrorApi.sinPermiso(),
    );

    expect(respuesta.statusCode, HttpStatus.forbidden);
    expect(jsonDecode(await respuesta.body()), {
      'error': {
        'code': 'SIN_PERMISO',
        'message': 'No tienes permiso para realizar esta acción.',
      },
    });
    expect(bitacora, isEmpty);
  });

  test(
    'una excepción cualquiera → 500 ERROR_INTERNO, sin su mensaje',
    () async {
      final respuesta = await ejecutar(
        (_) => throw StateError('password=Secreta-2026'),
      );

      expect(respuesta.statusCode, HttpStatus.internalServerError);
      final cuerpo = await respuesta.body();
      expect(
        (jsonDecode(cuerpo) as Map)['error'],
        containsPair('code', 'ERROR_INTERNO'),
      );
      expect(cuerpo, isNot(contains('Secreta-2026')));
    },
  );

  test('la bitácora lleva método, ruta y tipo, pero ningún dato sensible', () {
    return ejecutar(
      (_) => throw StateError('password=Secreta-2026 token=abc123'),
    ).then((_) {
      final linea = bitacora.single;
      expect(linea, contains('POST /auth/login'));
      expect(linea, contains('StateError'));
      for (final sensible in [
        'Secreta-2026',
        'abc123',
        'token-de-acceso',
        'en-la-url',
        'a@ipn.mx',
      ]) {
        expect(linea, isNot(contains(sensible)));
      }
    });
  });

  test('si no hay error, la respuesta pasa intacta', () async {
    final respuesta = await ejecutar((_) => Response(body: 'ok'));

    expect(respuesta.statusCode, HttpStatus.ok);
    expect(await respuesta.body(), 'ok');
    expect(bitacora, isEmpty);
  });
}
