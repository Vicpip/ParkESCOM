@TestOn('vm')
library;

import 'dart:io';

import 'package:backend/auth/tokens.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/auth/usuarios_demo.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../soporte/servidor_pruebas.dart';

const _password = 'Prueba-2026';

Map<String, dynamic> _objeto(Respuesta respuesta) =>
    respuesta.json! as Map<String, dynamic>;

Map<String, dynamic> _usuario(Respuesta respuesta) =>
    _objeto(respuesta)['usuario'] as Map<String, dynamic>;

String _acceso(Respuesta respuesta) =>
    _objeto(respuesta)['access_token'] as String;

String _refresh(Respuesta respuesta) =>
    _objeto(respuesta)['refresh_token'] as String;

/// Comprueba el código HTTP y el `error.code` del formato uniforme.
void _esperarError(Respuesta respuesta, int estado, String codigo) {
  expect(respuesta.estado, estado, reason: '${respuesta.json}');
  final error = _objeto(respuesta)['error'] as Map<String, dynamic>;
  expect(error['code'], codigo);
  expect(error['message'], isA<String>().having((m) => m, 'texto', isNotEmpty));
}

void main() {
  late ServidorPruebas api;
  var consecutivo = 0;

  /// Datos de registro válidos y distintos en cada llamada.
  Map<String, String> datosNuevos() {
    consecutivo++;
    return {
      'nombre': 'Persona de Prueba $consecutivo',
      'correo': 'prueba$consecutivo@alumno.ipn.mx',
      'boleta_o_empleado': '${2026000000 + consecutivo}',
      'password': _password,
    };
  }

  /// Registra una cuenta nueva y devuelve sus datos de registro.
  Future<Map<String, String>> registrar() async {
    final datos = datosNuevos();
    final respuesta = await api.post('/auth/registro', cuerpo: datos);
    expect(respuesta.estado, HttpStatus.created, reason: '${respuesta.json}');
    return datos;
  }

  Future<Respuesta> login(String correo, [String password = _password]) =>
      api.post(
        '/auth/login',
        cuerpo: {'correo': correo, 'password': password},
      );

  Future<void> actualizarUsuario(String correo, String asignacion) =>
      api.pool.execute(
        Sql.named('UPDATE usuarios SET $asignacion WHERE correo = @correo'),
        parameters: {'correo': correo},
      );

  setUpAll(() async => api = await ServidorPruebas.levantar());
  tearDownAll(() => api.cerrar());

  group('POST /auth/registro', () {
    test(
      'crea la cuenta pendiente, con correo en minúsculas, y abre sesión',
      () async {
        final datos = datosNuevos();
        final respuesta = await api.post(
          '/auth/registro',
          cuerpo: {...datos, 'correo': '  ${datos['correo']!.toUpperCase()} '},
        );

        expect(respuesta.estado, HttpStatus.created);
        expect(_usuario(respuesta), {
          'id': isA<String>(),
          'nombre': datos['nombre'],
          'correo': datos['correo'],
          'boleta_o_empleado': datos['boleta_o_empleado'],
          'rol': 'usuario',
          'estado': 'pendiente',
          'foto_titular_id': null,
          'foto_credencial_id': null,
        });
        expect(_objeto(respuesta)['expira_en'], 900);

        // Inicio de sesión automático: el token de acceso ya sirve.
        final yo = await api.get('/auth/me', token: _acceso(respuesta));
        expect(yo.estado, HttpStatus.ok);
        expect(_usuario(yo)['correo'], datos['correo']);

        // La contraseña se guarda con bcrypt, nunca en claro.
        final filas = await api.pool.execute(
          Sql.named('SELECT hash_password FROM usuarios WHERE correo = @c'),
          parameters: {'c': datos['correo']},
        );
        final hash = filas.single[0]! as String;
        expect(hash, startsWith(r'$2'));
        expect(hash, isNot(contains(_password)));
      },
    );

    test('correo duplicado → 409 CORREO_YA_REGISTRADO', () async {
      final existente = await registrar();
      final respuesta = await api.post(
        '/auth/registro',
        cuerpo: {
          ...datosNuevos(),
          'correo': existente['correo']!.toUpperCase(),
        },
      );

      _esperarError(respuesta, HttpStatus.conflict, 'CORREO_YA_REGISTRADO');
    });

    test('boleta duplicada → 409 BOLETA_YA_REGISTRADA', () async {
      final existente = await registrar();
      final respuesta = await api.post(
        '/auth/registro',
        cuerpo: {
          ...datosNuevos(),
          'boleta_o_empleado': existente['boleta_o_empleado'],
        },
      );

      _esperarError(respuesta, HttpStatus.conflict, 'BOLETA_YA_REGISTRADA');
    });

    test('dominio no permitido → 422 DOMINIO_NO_PERMITIDO', () async {
      final respuesta = await api.post(
        '/auth/registro',
        cuerpo: {...datosNuevos(), 'correo': 'alguien@gmail.com'},
      );

      _esperarError(
        respuesta,
        HttpStatus.unprocessableEntity,
        'DOMINIO_NO_PERMITIDO',
      );
    });

    test(
      'datos inválidos → 422 VALIDACION con el código de cada campo',
      () async {
        final respuesta = await api.post(
          '/auth/registro',
          cuerpo: {
            'nombre': '  ',
            'correo': 'no-es-correo',
            'boleta_o_empleado': '12',
            'password': 'corta1',
          },
        );

        _esperarError(respuesta, HttpStatus.unprocessableEntity, 'VALIDACION');
        expect((_objeto(respuesta)['error'] as Map)['campos'], {
          'nombre': 'NOMBRE_VACIO',
          'correo': 'CORREO_INVALIDO',
          'boleta_o_empleado': 'BOLETA_O_EMPLEADO_INVALIDO',
          'password': 'PASSWORD_MUY_CORTA',
        });
      },
    );

    test('un cuerpo que no es un objeto JSON → 400', () async {
      final respuesta = await api.post('/auth/registro', cuerpo: 'esto no');

      _esperarError(respuesta, HttpStatus.badRequest, 'SOLICITUD_INVALIDA');
    });

    test('otro método → 405', () async {
      final respuesta = await api.get('/auth/registro');

      _esperarError(
        respuesta,
        HttpStatus.methodNotAllowed,
        'METODO_NO_PERMITIDO',
      );
    });
  });

  group('POST /auth/login', () {
    test('correcto: tokens y datos básicos, sin hash', () async {
      final datos = await registrar();
      final respuesta = await login(datos['correo']!);

      expect(respuesta.estado, HttpStatus.ok);
      expect(_acceso(respuesta), isNotEmpty);
      expect(_refresh(respuesta), hasLength(43));
      expect(_usuario(respuesta)['correo'], datos['correo']);
      expect(respuesta.json.toString(), isNot(contains(r'$2')));
      expect(_usuario(respuesta).keys, isNot(contains('hash_password')));

      // Claims del token de acceso: sub y rol, con 15 min de vigencia.
      final identidad = api.dependencias.tokens.verificarAcceso(
        _acceso(respuesta),
      );
      expect(identidad?.id, _usuario(respuesta)['id']);
      expect(identidad?.rol, Rol.usuario);

      // En la base solo queda el hash SHA-256 del refresh token.
      final sesiones = await api.pool.execute(
        Sql.named(
          "SELECT expira_en > now() + interval '29 days', "
          "expira_en < now() + interval '31 days' FROM sesiones "
          'WHERE hash_refresh_token = @hash',
        ),
        parameters: {'hash': hashRefreshToken(_refresh(respuesta))},
      );
      expect(sesiones.single, [true, true]);
    });

    test('una cuenta activa también entra', () async {
      final datos = await registrar();
      await actualizarUsuario(datos['correo']!, "estado = 'activo'");

      final respuesta = await login(datos['correo']!);

      expect(respuesta.estado, HttpStatus.ok);
      expect(_usuario(respuesta)['estado'], 'activo');
    });

    test('contraseña incorrecta → 401 CREDENCIALES_INVALIDAS', () async {
      final datos = await registrar();

      _esperarError(
        await login(datos['correo']!, 'Otra-2026'),
        HttpStatus.unauthorized,
        'CREDENCIALES_INVALIDAS',
      );
    });

    test('un correo que no existe recibe exactamente el mismo error', () async {
      final datos = await registrar();
      final malPassword = await login(datos['correo']!, 'Otra-2026');
      final sinCuenta = await login('nadie@alumno.ipn.mx');

      expect(sinCuenta.estado, malPassword.estado);
      expect(sinCuenta.json, malPassword.json);
    });

    test('un usuario de baja no entra', () async {
      final datos = await registrar();
      await actualizarUsuario(datos['correo']!, "estado = 'baja'");

      _esperarError(
        await login(datos['correo']!),
        HttpStatus.unauthorized,
        'CREDENCIALES_INVALIDAS',
      );
    });

    test('el 6.º intento fallido → 429 DEMASIADOS_INTENTOS', () async {
      final datos = await registrar();
      final correo = datos['correo']!;

      for (var intento = 1; intento <= 5; intento++) {
        _esperarError(
          await login(correo, 'Otra-2026'),
          HttpStatus.unauthorized,
          'CREDENCIALES_INVALIDAS',
        );
      }
      _esperarError(
        await login(correo, 'Otra-2026'),
        HttpStatus.tooManyRequests,
        'DEMASIADOS_INTENTOS',
      );
      // Bloqueado, ni la contraseña correcta entra.
      _esperarError(
        await login(correo),
        HttpStatus.tooManyRequests,
        'DEMASIADOS_INTENTOS',
      );
    });

    test('un inicio de sesión correcto reinicia el conteo de fallos', () async {
      final datos = await registrar();
      final correo = datos['correo']!;

      for (var intento = 1; intento <= 4; intento++) {
        await login(correo, 'Otra-2026');
      }
      expect((await login(correo)).estado, HttpStatus.ok);
      for (var intento = 1; intento <= 4; intento++) {
        await login(correo, 'Otra-2026');
      }
      expect((await login(correo)).estado, HttpStatus.ok);
    });
  });

  group('POST /auth/refresh', () {
    test('rota el token y el anterior deja de servir', () async {
      final datos = await registrar();
      final anterior = _refresh(await login(datos['correo']!));

      final renovada = await api.post(
        '/auth/refresh',
        cuerpo: {'refresh_token': anterior},
      );
      expect(renovada.estado, HttpStatus.ok);
      final nuevo = _refresh(renovada);
      expect(nuevo, isNot(anterior));
      expect(
        (await api.get('/auth/me', token: _acceso(renovada))).estado,
        HttpStatus.ok,
      );

      _esperarError(
        await api.post('/auth/refresh', cuerpo: {'refresh_token': anterior}),
        HttpStatus.unauthorized,
        'REFRESH_INVALIDO',
      );
      expect(
        (await api.post(
          '/auth/refresh',
          cuerpo: {'refresh_token': nuevo},
        )).estado,
        HttpStatus.ok,
      );
    });

    test('un token desconocido o ausente → 401 REFRESH_INVALIDO', () async {
      _esperarError(
        await api.post(
          '/auth/refresh',
          cuerpo: {'refresh_token': generarRefreshToken()},
        ),
        HttpStatus.unauthorized,
        'REFRESH_INVALIDO',
      );
      _esperarError(
        await api.post('/auth/refresh'),
        HttpStatus.unauthorized,
        'REFRESH_INVALIDO',
      );
    });

    test('una sesión vencida no se renueva', () async {
      final datos = await registrar();
      final token = _refresh(await login(datos['correo']!));
      await api.pool.execute(
        Sql.named(
          "UPDATE sesiones SET expira_en = now() - interval '1 minute' "
          'WHERE hash_refresh_token = @hash',
        ),
        parameters: {'hash': hashRefreshToken(token)},
      );

      _esperarError(
        await api.post('/auth/refresh', cuerpo: {'refresh_token': token}),
        HttpStatus.unauthorized,
        'REFRESH_INVALIDO',
      );
    });

    test('un usuario dado de baja no renueva su sesión', () async {
      final datos = await registrar();
      final token = _refresh(await login(datos['correo']!));
      await actualizarUsuario(datos['correo']!, "estado = 'baja'");

      _esperarError(
        await api.post('/auth/refresh', cuerpo: {'refresh_token': token}),
        HttpStatus.unauthorized,
        'REFRESH_INVALIDO',
      );
    });
  });

  test('POST /auth/logout invalida el refresh token', () async {
    final datos = await registrar();
    final token = _refresh(await login(datos['correo']!));

    final salida = await api.post(
      '/auth/logout',
      cuerpo: {'refresh_token': token},
    );
    expect(salida.estado, HttpStatus.noContent);

    _esperarError(
      await api.post('/auth/refresh', cuerpo: {'refresh_token': token}),
      HttpStatus.unauthorized,
      'REFRESH_INVALIDO',
    );
    // Repetir el cierre de sesión no es un error.
    expect(
      (await api.post('/auth/logout', cuerpo: {'refresh_token': token})).estado,
      HttpStatus.noContent,
    );
  });

  group('GET /auth/me', () {
    test('sin token → 401 NO_AUTENTICADO', () async {
      _esperarError(
        await api.get('/auth/me'),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
    });

    test('con un token alterado, vencido o de otro secreto → 401', () async {
      final datos = await registrar();
      final sesion = await login(datos['correo']!);
      final id = _usuario(sesion)['id'] as String;
      final valido = _acceso(sesion);

      final vencido = api.dependencias.tokens.emitirAcceso(
        usuarioId: id,
        rol: Rol.usuario,
        vigencia: const Duration(seconds: -5),
      );
      final ajeno = ServicioTokens(
        generarRefreshToken(),
      ).emitirAcceso(usuarioId: id, rol: Rol.admin);

      for (final token in [
        '${valido.substring(0, valido.length - 2)}xx',
        vencido,
        ajeno,
        'no-es-un-jwt',
      ]) {
        _esperarError(
          await api.get('/auth/me', token: token),
          HttpStatus.unauthorized,
          'NO_AUTENTICADO',
        );
      }
    });

    test('un usuario dado de baja deja de verse → 401', () async {
      final datos = await registrar();
      final sesion = await login(datos['correo']!);
      await actualizarUsuario(datos['correo']!, "estado = 'baja'");

      _esperarError(
        await api.get('/auth/me', token: _acceso(sesion)),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
    });
  });

  group('autorización por rol', () {
    test('ruta protegida con rol incorrecto → 403 SIN_PERMISO', () async {
      final datos = await registrar();
      final sesion = await login(datos['correo']!);

      _esperarError(
        await api.get('/pruebas/solo-admin', token: _acceso(sesion)),
        HttpStatus.forbidden,
        'SIN_PERMISO',
      );
    });

    test('con el rol correcto pasa, y sin token responde 401', () async {
      final datos = await registrar();
      await actualizarUsuario(datos['correo']!, "rol = 'admin'");
      final sesion = await login(datos['correo']!);

      final respuesta = await api.get(
        '/pruebas/solo-admin',
        token: _acceso(sesion),
      );
      expect(respuesta.estado, HttpStatus.ok);
      _esperarError(
        await api.get('/pruebas/solo-admin'),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
    });
  });

  group('POST /auth/cambiar-password', () {
    test(
      'con la contraseña actual equivocada falla y no cambia nada',
      () async {
        final datos = await registrar();
        final sesion = await login(datos['correo']!);

        _esperarError(
          await api.post(
            '/auth/cambiar-password',
            token: _acceso(sesion),
            cuerpo: {
              'password_actual': 'Otra-2026',
              'password_nueva': 'Nueva-2027',
            },
          ),
          HttpStatus.badRequest,
          'PASSWORD_ACTUAL_INCORRECTA',
        );
        expect((await login(datos['correo']!)).estado, HttpStatus.ok);
        expect(
          (await api.post(
            '/auth/refresh',
            cuerpo: {'refresh_token': _refresh(sesion)},
          )).estado,
          HttpStatus.ok,
        );
      },
    );

    test('al cambiarla, otra sesión deja de poder hacer refresh', () async {
      final datos = await registrar();
      final correo = datos['correo']!;
      final estaSesion = await login(correo);
      final otraSesion = await login(correo);

      final cambio = await api.post(
        '/auth/cambiar-password',
        token: _acceso(estaSesion),
        cuerpo: {'password_actual': _password, 'password_nueva': 'Nueva-2027'},
      );
      expect(cambio.estado, HttpStatus.ok, reason: '${cambio.json}');

      _esperarError(
        await api.post(
          '/auth/refresh',
          cuerpo: {'refresh_token': _refresh(otraSesion)},
        ),
        HttpStatus.unauthorized,
        'REFRESH_INVALIDO',
      );
      // El dispositivo que hizo el cambio sigue con los tokens de la respuesta.
      expect(
        (await api.post(
          '/auth/refresh',
          cuerpo: {'refresh_token': _refresh(cambio)},
        )).estado,
        HttpStatus.ok,
      );
      // La contraseña anterior ya no entra; la nueva sí.
      _esperarError(
        await login(correo),
        HttpStatus.unauthorized,
        'CREDENCIALES_INVALIDAS',
      );
      expect((await login(correo, 'Nueva-2027')).estado, HttpStatus.ok);
    });

    test('una contraseña nueva débil → 422 VALIDACION', () async {
      final datos = await registrar();
      final sesion = await login(datos['correo']!);

      final respuesta = await api.post(
        '/auth/cambiar-password',
        token: _acceso(sesion),
        cuerpo: {'password_actual': _password, 'password_nueva': 'sinnumero'},
      );

      _esperarError(respuesta, HttpStatus.unprocessableEntity, 'VALIDACION');
      expect((_objeto(respuesta)['error'] as Map)['campos'], {
        'password_nueva': 'PASSWORD_SIN_NUMERO',
      });
    });

    test('sin token → 401', () async {
      _esperarError(
        await api.post('/auth/cambiar-password'),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
    });
  });

  group('middleware raíz', () {
    test('una excepción no controlada → 500 con el formato uniforme', () async {
      final respuesta = await api.get('/pruebas/falla');

      _esperarError(
        respuesta,
        HttpStatus.internalServerError,
        'ERROR_INTERNO',
      );
      expect(respuesta.json.toString(), isNot(contains('falla de prueba')));
    });

    test('CORS solo acepta el origen del panel web', () async {
      const cabecera = HttpHeaders.accessControlAllowOriginHeader;

      final permitido = await api.pedir(
        'GET',
        '/auth/me',
        cabeceras: {'Origin': origenWebDePruebas},
      );
      expect(permitido.cabeceras.value(cabecera), origenWebDePruebas);

      final ajeno = await api.pedir(
        'GET',
        '/auth/me',
        cabeceras: {'Origin': 'https://otro.example'},
      );
      expect(ajeno.cabeceras.value(cabecera), isNull);

      final sinOrigen = await api.get('/auth/me');
      expect(sinOrigen.cabeceras.value(cabecera), isNull);
    });

    test(
      'el preflight pasa para el panel web y se rechaza para otros',
      () async {
        Future<Respuesta> preflight(String origen) => api.pedir(
          'OPTIONS',
          '/auth/login',
          cabeceras: {
            'Origin': origen,
            'Access-Control-Request-Method': 'POST',
          },
        );

        final permitido = await preflight(origenWebDePruebas);
        expect(permitido.estado, HttpStatus.noContent);
        expect(
          permitido.cabeceras.value(HttpHeaders.accessControlAllowOriginHeader),
          origenWebDePruebas,
        );
        expect(
          permitido.cabeceras.value(
            HttpHeaders.accessControlAllowHeadersHeader,
          ),
          contains('Authorization'),
        );
        expect(
          (await preflight('https://otro.example')).estado,
          HttpStatus.forbidden,
        );
      },
    );
  });

  group('rutas inexistentes', () {
    test('responden 404 RUTA_NO_ENCONTRADA con el formato uniforme', () async {
      for (final ruta in ['/ruta-que-no-existe', '/auth/no-existe', '/']) {
        final respuesta = await api.get(ruta);
        _esperarError(respuesta, HttpStatus.notFound, 'RUTA_NO_ENCONTRADA');
        expect(
          respuesta.cabeceras.contentType?.mimeType,
          ContentType.json.mimeType,
        );
      }
      _esperarError(
        await api.post('/ruta-que-no-existe', cuerpo: {'a': 1}),
        HttpStatus.notFound,
        'RUTA_NO_ENCONTRADA',
      );
    });

    test(
      'con el origen del panel web conserva las cabeceras de CORS',
      () async {
        final respuesta = await api.pedir(
          'GET',
          '/ruta-que-no-existe',
          cabeceras: {'Origin': origenWebDePruebas},
        );
        _esperarError(respuesta, HttpStatus.notFound, 'RUTA_NO_ENCONTRADA');
        expect(
          respuesta.cabeceras.value('access-control-allow-origin'),
          origenWebDePruebas,
        );
      },
    );
  });

  group('contraseña de más de 72 bytes', () {
    // 40 caracteres, 78 bytes en UTF-8.
    final larga = 'a1${'ñ' * 30}${'é' * 8}';

    test('el registro la rechaza con PASSWORD_MUY_LARGA', () async {
      final respuesta = await api.post(
        '/auth/registro',
        cuerpo: {...datosNuevos(), 'password': larga},
      );
      _esperarError(
        respuesta,
        HttpStatus.unprocessableEntity,
        'VALIDACION',
      );
      expect((_objeto(respuesta)['error'] as Map)['campos'], {
        'password': 'PASSWORD_MUY_LARGA',
      });
    });

    test('el cambio de contraseña la rechaza y deja la anterior', () async {
      final datos = await registrar();
      final sesion = await login(datos['correo']!);
      final respuesta = await api.post(
        '/auth/cambiar-password',
        token: _acceso(sesion),
        cuerpo: {'password_actual': _password, 'password_nueva': larga},
      );
      _esperarError(
        respuesta,
        HttpStatus.unprocessableEntity,
        'VALIDACION',
      );
      expect((_objeto(respuesta)['error'] as Map)['campos'], {
        'password_nueva': 'PASSWORD_MUY_LARGA',
      });
      expect((await login(datos['correo']!)).estado, HttpStatus.ok);
    });

    test('una de exactamente 72 bytes sí se acepta', () async {
      final justa = 'a1${'x' * 70}';
      final datos = {...datosNuevos(), 'password': justa};
      expect(
        (await api.post('/auth/registro', cuerpo: datos)).estado,
        HttpStatus.created,
      );
      expect((await login(datos['correo']!, justa)).estado, HttpStatus.ok);
    });
  });

  test('el seed de usuarios de demostración es idempotente', () async {
    final creados = await sembrarUsuariosDemo(
      api.pool,
      password: _password,
      costo: 4,
    );
    expect(creados, usuariosDemo.map((demo) => demo.correo));
    expect(
      await sembrarUsuariosDemo(api.pool, password: _password, costo: 4),
      isEmpty,
    );

    final admin = await login('demo.admin@ipn.mx');
    expect(admin.estado, HttpStatus.ok);
    expect(_usuario(admin)['rol'], 'admin');
    expect(_usuario(admin)['estado'], 'activo');
    expect(_usuario(await login('demo.guardia@ipn.mx'))['rol'], 'guardia');
  });
}
