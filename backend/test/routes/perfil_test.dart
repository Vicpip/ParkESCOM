@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../soporte/servidor_pruebas.dart';

/// PNG real de 1×1 px.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

Map<String, dynamic> _objeto(Respuesta respuesta) =>
    respuesta.json! as Map<String, dynamic>;

Map<String, dynamic> _usuario(Respuesta respuesta) =>
    _objeto(respuesta)['usuario'] as Map<String, dynamic>;

/// Comprueba un 422 `VALIDACION` con exactamente esos [campos].
void _esperarValidacion(Respuesta respuesta, Map<String, String> campos) {
  expect(
    respuesta.estado,
    HttpStatus.unprocessableEntity,
    reason: '${respuesta.json}',
  );
  final error = _objeto(respuesta)['error'] as Map<String, dynamic>;
  expect(error['code'], 'VALIDACION');
  expect(error['campos'], campos);
}

void main() {
  late ServidorPruebas api;
  late Cuenta yo;
  late Cuenta otro;

  Future<String> subir(Cuenta cuenta, String proposito) async {
    final respuesta = await api.subir(
      _png,
      proposito: proposito,
      token: cuenta.token,
    );
    expect(respuesta.estado, HttpStatus.created, reason: '${respuesta.json}');
    return _objeto(respuesta)['id'] as String;
  }

  Future<Respuesta> cambiar(Map<String, Object?> cambios) =>
      api.patch('/perfil', cuerpo: cambios, token: yo.token);

  setUpAll(() async {
    api = await ServidorPruebas.levantar();
    // El perfil solo se edita mientras la cuenta está pendiente.
    yo = await api.crearCuenta(estado: 'pendiente');
    otro = await api.crearCuenta(estado: 'pendiente');
  });
  tearDownAll(() => api.cerrar());

  test('GET /perfil devuelve los datos del usuario, con sus fotos', () async {
    final respuesta = await api.get('/perfil', token: yo.token);

    expect(respuesta.estado, HttpStatus.ok);
    expect(_usuario(respuesta), {
      'id': yo.id,
      'nombre': isA<String>(),
      'correo': yo.correo,
      'boleta_o_empleado': isA<String>(),
      'rol': 'usuario',
      'estado': 'pendiente',
      'foto_titular_id': null,
      'foto_credencial_id': null,
    });
  });

  test('sin token → 401, y otro método → 405', () async {
    expect((await api.get('/perfil')).estado, HttpStatus.unauthorized);
    expect((await api.patch('/perfil')).estado, HttpStatus.unauthorized);
    expect(
      (await api.post('/perfil', token: yo.token)).estado,
      HttpStatus.methodNotAllowed,
    );
  });

  test(
    'asignar fotos propias funciona y /auth/me también las devuelve',
    () async {
      final titular = await subir(yo, 'perfil');
      final credencial = await subir(yo, 'credencial_escolar');

      final respuesta = await cambiar({
        'foto_titular_id': titular,
        'foto_credencial_id': credencial,
      });

      expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
      expect(_usuario(respuesta)['foto_titular_id'], titular);
      expect(_usuario(respuesta)['foto_credencial_id'], credencial);

      for (final ruta in ['/auth/me', '/perfil']) {
        final leido = _usuario(await api.get(ruta, token: yo.token));
        expect(leido['foto_titular_id'], titular, reason: ruta);
        expect(leido['foto_credencial_id'], credencial, reason: ruta);
      }
    },
  );

  test(
    'cambia el nombre (sin espacios alrededor) y no toca lo demás',
    () async {
      final antes = _usuario(await api.get('/perfil', token: yo.token));

      final respuesta = await cambiar({'nombre': '  María José Hernández  '});

      expect(respuesta.estado, HttpStatus.ok);
      expect(_usuario(respuesta), {...antes, 'nombre': 'María José Hernández'});
    },
  );

  test('un nombre vacío o que no es texto → 422', () async {
    _esperarValidacion(await cambiar({'nombre': '   '}), {
      'nombre': 'NOMBRE_VACIO',
    });
    _esperarValidacion(await cambiar({'nombre': 42}), {
      'nombre': 'NOMBRE_VACIO',
    });
    _esperarValidacion(await cambiar({'nombre': 'a' * 121}), {
      'nombre': 'NOMBRE_MUY_LARGO',
    });
  });

  test('una foto de otro usuario → 422 y el perfil no cambia', () async {
    final antes = _usuario(await api.get('/perfil', token: yo.token));
    final ajena = await subir(otro, 'perfil');
    final credencialAjena = await subir(otro, 'credencial_escolar');

    _esperarValidacion(await cambiar({'foto_titular_id': ajena}), {
      'foto_titular_id': 'FOTO_INVALIDA',
    });
    _esperarValidacion(await cambiar({'foto_credencial_id': credencialAjena}), {
      'foto_credencial_id': 'FOTO_INVALIDA',
    });
    expect(_usuario(await api.get('/perfil', token: yo.token)), antes);
  });

  test('una foto con el propósito equivocado → 422', () async {
    final deVehiculo = await subir(yo, 'vehiculo');
    final dePerfil = await subir(yo, 'perfil');
    final deCredencial = await subir(yo, 'credencial_escolar');

    _esperarValidacion(await cambiar({'foto_titular_id': deVehiculo}), {
      'foto_titular_id': 'FOTO_INVALIDA',
    });
    // Cruzadas: cada campo solo acepta su propio propósito.
    _esperarValidacion(
      await cambiar({
        'foto_titular_id': deCredencial,
        'foto_credencial_id': dePerfil,
      }),
      {
        'foto_titular_id': 'FOTO_INVALIDA',
        'foto_credencial_id': 'FOTO_INVALIDA',
      },
    );
  });

  test('un id inexistente o mal formado → 422', () async {
    for (final valor in <Object>[
      '00000000-0000-4000-8000-000000000000',
      'no-es-uuid',
      "'; DROP TABLE usuarios; --",
      42,
    ]) {
      _esperarValidacion(await cambiar({'foto_titular_id': valor}), {
        'foto_titular_id': 'FOTO_INVALIDA',
      });
    }
  });

  test('si un campo falla no se aplica ninguno', () async {
    final antes = _usuario(await api.get('/perfil', token: yo.token));

    _esperarValidacion(
      await cambiar({'nombre': 'Nombre Nuevo', 'foto_titular_id': 'x'}),
      {'foto_titular_id': 'FOTO_INVALIDA'},
    );
    expect(_usuario(await api.get('/perfil', token: yo.token)), antes);
  });

  test('null quita la foto; un cuerpo vacío no cambia nada', () async {
    await cambiar({'foto_titular_id': await subir(yo, 'perfil')});

    final sinFoto = await cambiar({'foto_titular_id': null});
    expect(sinFoto.estado, HttpStatus.ok);
    expect(_usuario(sinFoto)['foto_titular_id'], isNull);

    final igual = await cambiar({});
    expect(igual.estado, HttpStatus.ok);
    expect(_usuario(igual), _usuario(sinFoto));
  });

  group('cuenta activa', () {
    late Cuenta activa;

    setUpAll(() async => activa = await api.crearCuenta());

    test('GET /perfil sigue funcionando', () async {
      final respuesta = await api.get('/perfil', token: activa.token);

      expect(respuesta.estado, HttpStatus.ok);
      expect(_usuario(respuesta)['id'], activa.id);
      expect(_usuario(respuesta)['estado'], 'activo');
    });

    test(
      'PATCH /perfil → 409 PERFIL_BLOQUEADO y el perfil no cambia',
      () async {
        final antes = _usuario(await api.get('/perfil', token: activa.token));
        final foto = await subir(activa, 'perfil');

        // Tampoco con un cuerpo vacío o inválido: el bloqueo va antes de la
        // validación de campos.
        for (final cambios in <Map<String, Object?>>[
          {'nombre': 'Nombre Nuevo'},
          {'foto_titular_id': foto},
          {'foto_credencial_id': null},
          {'nombre': '   '},
          {},
        ]) {
          final respuesta = await api.patch(
            '/perfil',
            cuerpo: cambios,
            token: activa.token,
          );

          expect(respuesta.estado, HttpStatus.conflict, reason: '$cambios');
          expect(_objeto(respuesta)['error'], {
            'code': 'PERFIL_BLOQUEADO',
            'message':
                'Para cambiar tus datos o fotos, contacta a Administración',
          }, reason: '$cambios');
        }
        expect(_usuario(await api.get('/perfil', token: activa.token)), antes);
      },
    );

    test('el bloqueo empieza en cuanto se activa la cuenta', () async {
      final cuenta = await api.crearCuenta(estado: 'pendiente');
      final editar = {'nombre': 'Antes de Activar'};

      final pendiente = await api.patch(
        '/perfil',
        cuerpo: editar,
        token: cuenta.token,
      );
      expect(pendiente.estado, HttpStatus.ok, reason: '${pendiente.json}');

      await api.pool.execute(
        Sql.named("UPDATE usuarios SET estado = 'activo' WHERE id = @id:uuid"),
        parameters: {'id': cuenta.id},
      );

      // Mismo token de acceso: el estado se lee de la base.
      final activo = await api.patch(
        '/perfil',
        cuerpo: {'nombre': 'Después de Activar'},
        token: cuenta.token,
      );
      expect(activo.estado, HttpStatus.conflict);
      expect(
        _usuario(await api.get('/perfil', token: cuenta.token))['nombre'],
        'Antes de Activar',
      );
    });

    test('una cuenta de baja → 401, no 409', () async {
      // Se da de baja con la sesión ya abierta: su token sigue vigente.
      final cuenta = await api.crearCuenta(estado: 'pendiente');
      await api.pool.execute(
        Sql.named("UPDATE usuarios SET estado = 'baja' WHERE id = @id:uuid"),
        parameters: {'id': cuenta.id},
      );

      final respuesta = await api.patch(
        '/perfil',
        cuerpo: {'nombre': 'Nombre Nuevo'},
        token: cuenta.token,
      );

      expect(respuesta.estado, HttpStatus.unauthorized);
    });
  });
}
