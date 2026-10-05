@TestOn('vm')
library;

import 'dart:io';

import 'package:backend/auth/tokens.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../soporte/servidor_pruebas.dart';

const _nueva = 'Nueva-Clave-2027';

Map<String, dynamic> _objeto(Respuesta respuesta) =>
    respuesta.json! as Map<String, dynamic>;

void _esperarError(Respuesta respuesta, int estado, String codigo) {
  expect(respuesta.estado, estado, reason: '${respuesta.json}');
  final error = _objeto(respuesta)['error'] as Map<String, dynamic>;
  expect(error['code'], codigo);
  expect(error['message'], isA<String>().having((m) => m, 'texto', isNotEmpty));
}

void main() {
  late ServidorPruebas api;

  Future<Respuesta> olvide(String correo) =>
      api.post('/auth/olvide-password', cuerpo: {'correo': correo});

  Future<Respuesta> restablecer(String token, [String password = _nueva]) =>
      api.post(
        '/auth/restablecer',
        cuerpo: {'token': token, 'password_nueva': password},
      );

  Future<Respuesta> login(String correo, String password) => api.post(
    '/auth/login',
    cuerpo: {'correo': correo, 'password': password},
  );

  /// Pide el enlace para [correo] y devuelve el token que llegó por correo.
  Future<String> pedirToken(String correo) async {
    expect((await olvide(correo)).estado, HttpStatus.ok);
    final enlace = Uri.parse(api.correo.enlacePara(correo)!);
    return enlace.queryParameters['token']!;
  }

  Future<int> restablecimientosDe(String correo) async {
    final filas = await api.pool.execute(
      Sql.named(
        'SELECT count(*)::int FROM restablecimientos r '
        'JOIN usuarios u ON u.id = r.usuario_id WHERE u.correo = @correo',
      ),
      parameters: {'correo': correo},
    );
    return filas.single[0]! as int;
  }

  setUpAll(() async => api = await ServidorPruebas.levantar());
  tearDownAll(() => api.cerrar());

  group('POST /auth/olvide-password', () {
    test(
      'responde lo mismo, byte por byte, exista o no el correo',
      () async {
        final cuenta = await api.crearCuenta();
        final enviadosAntes = api.correo.correos.length;

        final existente = await olvide(cuenta.correo);
        final inexistente = await olvide('nadie.con.este.correo@alumno.ipn.mx');

        expect(existente.estado, HttpStatus.ok);
        expect(inexistente.estado, existente.estado);
        expect(inexistente.bytes, existente.bytes);
        expect(
          inexistente.cabeceras.contentType.toString(),
          existente.cabeceras.contentType.toString(),
        );

        // Solo a la cuenta real se le envió correo.
        expect(api.correo.correos, hasLength(enviadosAntes + 1));
        expect(api.correo.correos.last.destinatario, cuenta.correo);
      },
    );

    test(
      'el correo va en español, con el enlace y el aviso de 15 min',
      () async {
        final cuenta = await api.crearCuenta();
        await olvide('  ${cuenta.correo.toUpperCase()} ');

        final correo = api.correo.correos.last;
        expect(correo.destinatario, cuenta.correo);
        expect(correo.asunto, 'Restablece tu contraseña de ParkESCOM');
        expect(
          correo.texto,
          contains(
            'Este enlace vence en 15 minutos. Si no lo pediste, ignora este '
            'mensaje.',
          ),
        );

        final enlace = Uri.parse(api.correo.enlacePara(cuenta.correo)!);
        expect(enlace.origin, origenWebDePruebas);
        expect(enlace.path, '/restablecer');
        // 32 bytes aleatorios en base64url sin relleno.
        expect(
          enlace.queryParameters['token'],
          matches(RegExp(r'^[A-Za-z0-9_-]{43}$')),
        );
      },
    );

    test(
      'en la base solo queda el hash SHA-256, con 15 min de vigencia',
      () async {
        final cuenta = await api.crearCuenta();
        final token = await pedirToken(cuenta.correo);

        final filas = await api.pool.execute(
          Sql.named(
            'SELECT hash_token, usado, '
            'extract(epoch FROM expira_en - now())::int '
            'FROM restablecimientos WHERE usuario_id = @id:uuid',
          ),
          parameters: {'id': cuenta.id},
        );
        final fila = filas.single;
        expect(fila[0], hashRefreshToken(token));
        expect(fila[0], isNot(contains(token)));
        expect(fila[1], isFalse);
        expect(fila[2], inInclusiveRange(14 * 60, 15 * 60));
      },
    );

    test('una cuenta de baja no recibe correo ni token', () async {
      final cuenta = await api.crearCuenta();
      await api.pool.execute(
        Sql.named("UPDATE usuarios SET estado = 'baja' WHERE id = @id:uuid"),
        parameters: {'id': cuenta.id},
      );

      final respuesta = await olvide(cuenta.correo);

      expect(respuesta.estado, HttpStatus.ok);
      expect(api.correo.enlacePara(cuenta.correo), isNull);
      expect(await restablecimientosDe(cuenta.correo), 0);
    });

    test('la 4.ª solicitud del mismo correo en una hora → 429', () async {
      final cuenta = await api.crearCuenta();
      for (var i = 0; i < 3; i++) {
        expect((await olvide(cuenta.correo)).estado, HttpStatus.ok);
      }

      _esperarError(
        await olvide(cuenta.correo),
        HttpStatus.tooManyRequests,
        'DEMASIADOS_INTENTOS',
      );
      // Tampoco escribiéndolo distinto.
      _esperarError(
        await olvide(' ${cuenta.correo.toUpperCase()}'),
        HttpStatus.tooManyRequests,
        'DEMASIADOS_INTENTOS',
      );
      expect(await restablecimientosDe(cuenta.correo), 3);

      // El límite es igual para un correo que no existe: no lo delata.
      const inexistente = 'tampoco.existe@alumno.ipn.mx';
      for (var i = 0; i < 3; i++) {
        expect((await olvide(inexistente)).estado, HttpStatus.ok);
      }
      _esperarError(
        await olvide(inexistente),
        HttpStatus.tooManyRequests,
        'DEMASIADOS_INTENTOS',
      );

      // Y es por correo: otra cuenta no se ve afectada.
      final otra = await api.crearCuenta();
      expect((await olvide(otra.correo)).estado, HttpStatus.ok);
    });
  });

  group('POST /auth/restablecer', () {
    test(
      'cambia la contraseña y el token funciona una sola vez',
      () async {
        final cuenta = await api.crearCuenta();
        final token = await pedirToken(cuenta.correo);

        final primera = await restablecer(token);
        expect(primera.estado, HttpStatus.ok, reason: '${primera.json}');
        expect(_objeto(primera).keys, ['mensaje']);

        expect((await login(cuenta.correo, _nueva)).estado, HttpStatus.ok);
        _esperarError(
          await login(cuenta.correo, passwordDePruebas),
          HttpStatus.unauthorized,
          'CREDENCIALES_INVALIDAS',
        );

        _esperarError(
          await restablecer(token, 'Otra-Clave-2028'),
          HttpStatus.badRequest,
          'ENLACE_INVALIDO',
        );
        // La segunda vez no cambió nada.
        expect((await login(cuenta.correo, _nueva)).estado, HttpStatus.ok);
      },
    );

    test(
      'tras restablecer, el refresh token anterior deja de servir',
      () async {
        final cuenta = await api.crearCuenta();
        final token = await pedirToken(cuenta.correo);

        expect((await restablecer(token)).estado, HttpStatus.ok);

        _esperarError(
          await api.post(
            '/auth/refresh',
            cuerpo: {'refresh_token': cuenta.refresh},
          ),
          HttpStatus.unauthorized,
          'REFRESH_INVALIDO',
        );
        final vivas = await api.pool.execute(
          Sql.named(
            'SELECT count(*)::int FROM sesiones '
            'WHERE usuario_id = @id:uuid AND NOT revocada',
          ),
          parameters: {'id': cuenta.id},
        );
        expect(vivas.single[0], 0);
      },
    );

    test(
      'vencido, inexistente y vacío responden el mismo ENLACE_INVALIDO',
      () async {
        final cuenta = await api.crearCuenta();
        final token = await pedirToken(cuenta.correo);
        await api.pool.execute(
          Sql.named(
            'UPDATE restablecimientos '
            "SET expira_en = now() - interval '1 second' "
            'WHERE hash_token = @hash',
          ),
          parameters: {'hash': hashRefreshToken(token)},
        );

        final vencido = await restablecer(token);
        final inexistente = await restablecer(generarRefreshToken());
        final vacio = await restablecer('');

        _esperarError(vencido, HttpStatus.badRequest, 'ENLACE_INVALIDO');
        expect(inexistente.estado, vencido.estado);
        expect(inexistente.bytes, vencido.bytes);
        expect(vacio.bytes, vencido.bytes);

        // La contraseña sigue siendo la original.
        expect(
          (await login(cuenta.correo, passwordDePruebas)).estado,
          HttpStatus.ok,
        );
      },
    );

    test('pedir un enlace nuevo invalida el anterior', () async {
      final cuenta = await api.crearCuenta();
      final primero = await pedirToken(cuenta.correo);
      final segundo = await pedirToken(cuenta.correo);

      _esperarError(
        await restablecer(primero),
        HttpStatus.badRequest,
        'ENLACE_INVALIDO',
      );
      expect((await restablecer(segundo)).estado, HttpStatus.ok);
    });

    test(
      'una contraseña inválida → 422 y el enlace se puede volver a usar',
      () async {
        final cuenta = await api.crearCuenta();
        final token = await pedirToken(cuenta.correo);

        // 40 caracteres, 78 bytes en UTF-8.
        final casos = {
          'a1${'ñ' * 30}${'é' * 8}': 'CONTRASENA_MUY_LARGA',
          'corta1': 'PASSWORD_MUY_CORTA',
          'sinnumeros': 'PASSWORD_SIN_NUMERO',
        };
        for (final MapEntry(key: password, value: codigo) in casos.entries) {
          final respuesta = await restablecer(token, password);
          _esperarError(
            respuesta,
            HttpStatus.unprocessableEntity,
            'VALIDACION',
          );
          expect((_objeto(respuesta)['error'] as Map)['campos'], {
            'password_nueva': codigo,
          });
        }

        expect((await restablecer(token)).estado, HttpStatus.ok);
        expect((await login(cuenta.correo, _nueva)).estado, HttpStatus.ok);
      },
    );

    test(
      'si la cuenta se dio de baja después, el enlace ya no sirve',
      () async {
        final cuenta = await api.crearCuenta();
        final token = await pedirToken(cuenta.correo);
        await api.pool.execute(
          Sql.named("UPDATE usuarios SET estado = 'baja' WHERE id = @id:uuid"),
          parameters: {'id': cuenta.id},
        );

        _esperarError(
          await restablecer(token),
          HttpStatus.badRequest,
          'ENLACE_INVALIDO',
        );
      },
    );
  });
}
