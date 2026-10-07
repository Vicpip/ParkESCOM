@TestOn('vm')
library;

import 'dart:io';

import 'package:backend/auth/usuario.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../soporte/servidor_pruebas.dart';
import '../soporte/vehiculos_pruebas.dart';

void _esperarError(Respuesta respuesta, int estado, String codigo) {
  expect(respuesta.estado, estado, reason: '${respuesta.json}');
  expect(errorDe(respuesta)['code'], codigo);
  expect(errorDe(respuesta)['message'], isA<String>());
}

/// Comprueba un 422 `VALIDACION` con exactamente esos [campos].
void _esperarValidacion(Respuesta respuesta, Map<String, String> campos) {
  _esperarError(respuesta, HttpStatus.unprocessableEntity, 'VALIDACION');
  expect(errorDe(respuesta)['campos'], campos);
}

void main() {
  late ServidorPruebas api;
  late Cuenta admin;
  late Cuenta guardia;
  late Cuenta titular;
  late Cuenta otro;

  Future<int> contar(String tabla) async {
    final filas = await api.pool.execute('SELECT count(*)::int FROM $tabla');
    return filas.single[0]! as int;
  }

  Future<List<String?>> placasVisibles(Cuenta cuenta) async {
    final respuesta = await api.get('/vehiculos', token: cuenta.token);
    return [
      for (final vehiculo in objeto(respuesta)['vehiculos'] as List<dynamic>)
        (vehiculo as Map<String, dynamic>)['placa'] as String?,
    ];
  }

  setUpAll(() async {
    api = await ServidorPruebas.levantar();
    admin = await api.crearCuenta(rol: Rol.admin);
    guardia = await api.crearCuenta(rol: Rol.guardia);
    titular = await api.crearCuenta();
    otro = await api.crearCuenta();
  });
  tearDownAll(() => api.cerrar());

  group('POST /solicitudes · alta', () {
    test('una moto con sus dos fotos → 201, vehículo y solicitud '
        'pendientes', () async {
      final datos = await api.datosVehiculo(
        titular,
        tipo: 'moto',
        cambios: {'placa': ' a1b 2c ', 'marca': '  Italika '},
      );

      final respuesta = await api.solicitar(titular, {
        'tipo': 'alta',
        'datos': datos,
      });

      expect(respuesta.estado, HttpStatus.created, reason: '${respuesta.json}');
      final solicitud = solicitudDe(respuesta);
      final normalizados = {...datos, 'placa': 'A1B2C', 'marca': 'Italika'};
      expect(solicitud, {
        'id': isA<String>(),
        'usuario_id': titular.id,
        'vehiculo_id': isA<String>(),
        'tipo': 'alta',
        'estado': 'pendiente',
        'datos_propuestos': normalizados,
        'comentario': null,
        'creado_en': isA<String>(),
        'resuelta_en': null,
      });

      final vehiculoId = solicitud['vehiculo_id'] as String;
      final vehiculos = await api.pool.execute(
        Sql.named(
          'SELECT tipo::text, placa, marca, modelo, color, estado::text, '
          'foto_id::text, foto_placa_id::text FROM vehiculos '
          'WHERE id = @id:uuid',
        ),
        parameters: {'id': vehiculoId},
      );
      expect(vehiculos.single, [
        'moto',
        'A1B2C',
        'Italika',
        'Versa 2020',
        'Gris',
        'pendiente',
        datos['foto_id'],
        datos['foto_placa_id'],
      ]);

      final autorizados = await api.pool.execute(
        Sql.named(
          'SELECT usuario_id::text, es_titular, activo '
          'FROM vehiculo_usuarios WHERE vehiculo_id = @id:uuid',
        ),
        parameters: {'id': vehiculoId},
      );
      expect(autorizados.single, [titular.id, true, true]);
    });

    test('una cuenta pendiente también puede pedir un alta', () async {
      final pendiente = await api.crearCuenta(estado: 'pendiente');

      final alta = await api.darDeAlta(pendiente);

      expect(
        await api.leer('vehiculos', 'estado', alta.vehiculoId),
        'pendiente',
      );
    });

    test('una bici sin placa ni número de serie → 201', () async {
      final alta = await api.darDeAlta(
        titular,
        tipo: 'bici',
        cambios: {'placa': null},
      );

      expect(await api.leer('vehiculos', 'placa', alta.vehiculoId), isNull);
    });

    test('una moto sin foto de placa → 422 y no se crea nada', () async {
      final vehiculos = await contar('vehiculos');
      final solicitudes = await contar('solicitudes');
      final datos = await api.datosVehiculo(
        titular,
        tipo: 'moto',
        cambios: {'foto_placa_id': null},
      );

      _esperarValidacion(
        await api.solicitar(titular, {'tipo': 'alta', 'datos': datos}),
        {'foto_placa_id': 'FOTO_PLACA_REQUERIDA'},
      );
      expect(await contar('vehiculos'), vehiculos);
      expect(await contar('solicitudes'), solicitudes);
    });

    test('los datos inválidos se reportan todos juntos', () async {
      _esperarValidacion(
        await api.solicitar(titular, {
          'tipo': 'alta',
          'datos': {
            'tipo': 'auto',
            'placa': 'ABC_123',
            'marca': '',
            'modelo': 'm' * 61,
            'color': 7,
          },
        }),
        {
          'placa': 'PLACA_INVALIDA',
          'marca': 'MARCA_VACIA',
          'modelo': 'MODELO_MUY_LARGO',
          'color': 'COLOR_VACIO',
          'foto_id': 'FOTO_VEHICULO_REQUERIDA',
        },
      );
    });

    test('un auto sin placa → 422 PLACA_REQUERIDA', () async {
      final datos = await api.datosVehiculo(titular, cambios: {'placa': ''});

      _esperarValidacion(
        await api.solicitar(titular, {'tipo': 'alta', 'datos': datos}),
        {'placa': 'PLACA_REQUERIDA'},
      );
    });

    test('tipo de solicitud desconocido o sin datos → 422', () async {
      _esperarValidacion(await api.solicitar(titular, {'tipo': 'permuta'}), {
        'tipo': 'TIPO_SOLICITUD_INVALIDO',
      });
      _esperarValidacion(await api.solicitar(titular, {}), {
        'tipo': 'TIPO_SOLICITUD_INVALIDO',
      });
      _esperarValidacion(await api.solicitar(titular, {'tipo': 'alta'}), {
        'datos': 'DATOS_REQUERIDOS',
      });
      _esperarValidacion(
        await api.solicitar(titular, {'tipo': 'alta', 'datos': 'auto'}),
        {'datos': 'DATOS_REQUERIDOS'},
      );
    });

    test(
      'la placa de otro vehículo vigente → 409 PLACA_YA_REGISTRADA',
      () async {
        final existente = await api.darDeAlta(titular);
        final vehiculos = await contar('vehiculos');
        final datos = await api.datosVehiculo(
          otro,
          // La misma placa, escrita de otra forma.
          cambios: {'placa': ' ${existente.placa!.toLowerCase()} '},
        );

        _esperarError(
          await api.solicitar(otro, {'tipo': 'alta', 'datos': datos}),
          HttpStatus.conflict,
          'PLACA_YA_REGISTRADA',
        );
        // La transacción se deshizo completa.
        expect(await contar('vehiculos'), vehiculos);
      },
    );

    test('una foto de otro usuario → 422 FOTO_INVALIDA', () async {
      final ajena = await api.subirFoto(otro, 'vehiculo');
      final placaAjena = await api.subirFoto(otro, 'placa');
      final datos = await api.datosVehiculo(
        titular,
        tipo: 'moto',
        cambios: {'foto_id': ajena, 'foto_placa_id': placaAjena},
      );

      _esperarValidacion(
        await api.solicitar(titular, {'tipo': 'alta', 'datos': datos}),
        {'foto_id': 'FOTO_INVALIDA', 'foto_placa_id': 'FOTO_INVALIDA'},
      );
    });

    test(
      'una foto con otro propósito, inexistente o mal formada → 422',
      () async {
        final dePerfil = await api.subirFoto(titular, 'perfil');
        final deVehiculo = await api.subirFoto(titular, 'vehiculo');
        final dePlaca = await api.subirFoto(titular, 'placa');

        for (final foto in [dePerfil, dePlaca, idInexistente, 'no-es-uuid']) {
          final datos = await api.datosVehiculo(
            titular,
            cambios: {'foto_id': foto},
          );
          _esperarValidacion(
            await api.solicitar(titular, {'tipo': 'alta', 'datos': datos}),
            {'foto_id': 'FOTO_INVALIDA'},
          );
        }
        // Cruzadas: cada campo solo acepta su propósito.
        final cruzadas = await api.datosVehiculo(
          titular,
          tipo: 'moto',
          cambios: {'foto_id': dePlaca, 'foto_placa_id': deVehiculo},
        );
        _esperarValidacion(
          await api.solicitar(titular, {'tipo': 'alta', 'datos': cruzadas}),
          {'foto_id': 'FOTO_INVALIDA', 'foto_placa_id': 'FOTO_INVALIDA'},
        );
      },
    );

    test(
      'una foto que ya es de otro vehículo → 422 FOTO_YA_ASIGNADA',
      () async {
        final datos = await api.datosVehiculo(titular, tipo: 'moto');
        final primera = await api.solicitar(titular, {
          'tipo': 'alta',
          'datos': datos,
        });
        expect(primera.estado, HttpStatus.created);

        _esperarValidacion(
          await api.solicitar(titular, {
            'tipo': 'alta',
            'datos': {...datos, 'placa': placaNueva()},
          }),
          {'foto_id': 'FOTO_YA_ASIGNADA', 'foto_placa_id': 'FOTO_YA_ASIGNADA'},
        );
      },
    );

    test('una cuenta de baja → 401 aunque su token siga vigente', () async {
      final cuenta = await api.crearCuenta();
      final datos = await api.datosVehiculo(cuenta);
      await api.pool.execute(
        Sql.named("UPDATE usuarios SET estado = 'baja' WHERE id = @id:uuid"),
        parameters: {'id': cuenta.id},
      );

      _esperarError(
        await api.solicitar(cuenta, {'tipo': 'alta', 'datos': datos}),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
    });

    test(
      'sin token → 401; un cuerpo que no es objeto → 400; PUT → 405',
      () async {
        _esperarError(
          await api.post('/solicitudes', cuerpo: {'tipo': 'alta'}),
          HttpStatus.unauthorized,
          'NO_AUTENTICADO',
        );
        _esperarError(
          await api.post(
            '/solicitudes',
            cuerpo: '[1, 2]',
            token: titular.token,
          ),
          HttpStatus.badRequest,
          'SOLICITUD_INVALIDA',
        );
        _esperarError(
          await api.pedir('PUT', '/solicitudes', token: titular.token),
          HttpStatus.methodNotAllowed,
          'METODO_NO_PERMITIDO',
        );
      },
    );
  });

  group('POST /solicitudes · cambio y baja', () {
    late Alta auto;
    late Cuenta autorizado;

    setUpAll(() async {
      auto = await api.darDeAlta(titular, aprobadaPor: admin);
      autorizado = await api.crearCuenta();
      await api.autorizar(auto.vehiculoId, autorizado.id);
    });

    Future<Map<String, Object?>> datosDeCambio(
      Cuenta cuenta, [
      Map<String, Object?> cambios = const {},
    ]) => api.datosVehiculo(
      cuenta,
      cambios: {'placa': auto.placa, 'color': 'Azul', ...cambios},
    );

    /// Rechaza la solicitud pendiente del auto, para dejarlo libre.
    Future<void> liberar(Respuesta creada) async {
      expect(creada.estado, HttpStatus.created, reason: '${creada.json}');
      final resuelta = await api.resolver(
        admin,
        solicitudDe(creada)['id'] as String,
        'rechazar',
        comentario: 'Prueba',
      );
      expect(resuelta.estado, HttpStatus.ok);
    }

    test(
      'quien no es titular → 403 SOLO_TITULAR, en cambio y en baja',
      () async {
        _esperarError(
          await api.solicitar(autorizado, {
            'tipo': 'cambio',
            'vehiculo_id': auto.vehiculoId,
            'datos': await datosDeCambio(autorizado),
          }),
          HttpStatus.forbidden,
          'SOLO_TITULAR',
        );
        _esperarError(
          await api.solicitar(autorizado, {
            'tipo': 'baja',
            'vehiculo_id': auto.vehiculoId,
          }),
          HttpStatus.forbidden,
          'SOLO_TITULAR',
        );
      },
    );

    test(
      'un usuario ajeno al vehículo → 404, igual que si no existiera',
      () async {
        final ajeno = await api.solicitar(otro, {
          'tipo': 'baja',
          'vehiculo_id': auto.vehiculoId,
        });
        final inexistente = await api.solicitar(otro, {
          'tipo': 'baja',
          'vehiculo_id': idInexistente,
        });

        _esperarError(ajeno, HttpStatus.notFound, 'VEHICULO_NO_ENCONTRADO');
        expect(ajeno.json, inexistente.json);
        _esperarError(
          await api.solicitar(otro, {
            'tipo': 'cambio',
            'vehiculo_id': 'no-es-uuid',
            'datos': await datosDeCambio(otro),
          }),
          HttpStatus.notFound,
          'VEHICULO_NO_ENCONTRADO',
        );
      },
    );

    test('sin vehiculo_id → 422', () async {
      _esperarValidacion(await api.solicitar(titular, {'tipo': 'baja'}), {
        'vehiculo_id': 'VEHICULO_REQUERIDO',
      });
    });

    test(
      'el cambio guarda los datos propuestos y el vehículo no cambia',
      () async {
        final datos = await datosDeCambio(titular, {'marca': 'Toyota'});

        final respuesta = await api.solicitar(titular, {
          'tipo': 'cambio',
          'vehiculo_id': auto.vehiculoId,
          'datos': datos,
        });

        expect(
          respuesta.estado,
          HttpStatus.created,
          reason: '${respuesta.json}',
        );
        expect(solicitudDe(respuesta)['tipo'], 'cambio');
        expect(solicitudDe(respuesta)['vehiculo_id'], auto.vehiculoId);
        expect(solicitudDe(respuesta)['datos_propuestos'], datos);
        expect(await api.leer('vehiculos', 'color', auto.vehiculoId), 'Gris');
        expect(await api.leer('vehiculos', 'marca', auto.vehiculoId), 'Nissan');
        expect(
          await api.leer('vehiculos', 'foto_id', auto.vehiculoId),
          isNot(datos['foto_id']),
        );
        await liberar(respuesta);
        // Rechazado: sigue igual.
        expect(await api.leer('vehiculos', 'color', auto.vehiculoId), 'Gris');
      },
    );

    test('con una solicitud pendiente, la segunda → 409 '
        'SOLICITUD_PENDIENTE_EXISTENTE', () async {
      final primera = await api.solicitar(titular, {
        'tipo': 'baja',
        'vehiculo_id': auto.vehiculoId,
      });
      expect(primera.estado, HttpStatus.created, reason: '${primera.json}');

      _esperarError(
        await api.solicitar(titular, {
          'tipo': 'baja',
          'vehiculo_id': auto.vehiculoId,
        }),
        HttpStatus.conflict,
        'SOLICITUD_PENDIENTE_EXISTENTE',
      );
      _esperarError(
        await api.solicitar(titular, {
          'tipo': 'cambio',
          'vehiculo_id': auto.vehiculoId,
          'datos': await datosDeCambio(titular),
        }),
        HttpStatus.conflict,
        'SOLICITUD_PENDIENTE_EXISTENTE',
      );

      // Ya resuelta la primera, se puede pedir otra.
      await liberar(primera);
      await liberar(
        await api.solicitar(titular, {
          'tipo': 'baja',
          'vehiculo_id': auto.vehiculoId,
        }),
      );
    });

    test(
      'un vehículo con su alta en revisión no admite otra solicitud',
      () async {
        final enRevision = await api.darDeAlta(titular);

        _esperarError(
          await api.solicitar(titular, {
            'tipo': 'baja',
            'vehiculo_id': enRevision.vehiculoId,
          }),
          HttpStatus.conflict,
          'SOLICITUD_PENDIENTE_EXISTENTE',
        );
      },
    );

    test('el cambio no puede cambiar el tipo de vehículo', () async {
      final datos = await api.datosVehiculo(
        titular,
        tipo: 'moto',
        cambios: {'placa': auto.placa},
      );

      _esperarValidacion(
        await api.solicitar(titular, {
          'tipo': 'cambio',
          'vehiculo_id': auto.vehiculoId,
          'datos': datos,
        }),
        {'tipo': 'TIPO_NO_MODIFICABLE'},
      );
    });

    test('el cambio valida datos y fotos como el alta', () async {
      _esperarValidacion(
        await api.solicitar(titular, {
          'tipo': 'cambio',
          'vehiculo_id': auto.vehiculoId,
          'datos': await datosDeCambio(titular, {
            'color': '',
            'foto_id': await api.subirFoto(otro, 'vehiculo'),
          }),
        }),
        {'color': 'COLOR_VACIO', 'foto_id': 'FOTO_INVALIDA'},
      );
    });

    test(
      'el cambio puede conservar la foto que el vehículo ya tiene',
      () async {
        final fotoActual = await api.leer(
          'vehiculos',
          'foto_id',
          auto.vehiculoId,
        );

        await liberar(
          await api.solicitar(titular, {
            'tipo': 'cambio',
            'vehiculo_id': auto.vehiculoId,
            'datos': await datosDeCambio(titular, {'foto_id': fotoActual}),
          }),
        );
      },
    );

    test('un cambio a la placa de otro vehículo → 409', () async {
      final ajeno = await api.darDeAlta(otro);

      _esperarError(
        await api.solicitar(titular, {
          'tipo': 'cambio',
          'vehiculo_id': auto.vehiculoId,
          'datos': await datosDeCambio(titular, {'placa': ajeno.placa}),
        }),
        HttpStatus.conflict,
        'PLACA_YA_REGISTRADA',
      );
    });
  });

  group('GET /solicitudes', () {
    late Cuenta cuenta;
    late Alta aprobada;
    late Alta rechazada;
    late Alta pendiente;

    setUpAll(() async {
      cuenta = await api.crearCuenta();
      aprobada = await api.darDeAlta(cuenta, aprobadaPor: admin);
      rechazada = await api.darDeAlta(cuenta);
      await api.resolver(
        admin,
        rechazada.solicitudId,
        'rechazar',
        comentario: 'La foto no corresponde.',
      );
      pendiente = await api.darDeAlta(cuenta);
    });

    Future<List<String>> listar([String consulta = '']) async {
      final respuesta = await api.get(
        '/solicitudes$consulta',
        token: cuenta.token,
      );
      expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
      return [
        for (final s in objeto(respuesta)['solicitudes'] as List<dynamic>)
          (s as Map<String, dynamic>)['id'] as String,
      ];
    }

    test('solo las del usuario, de la más reciente a la más antigua', () async {
      expect(await listar(), [
        pendiente.solicitudId,
        rechazada.solicitudId,
        aprobada.solicitudId,
      ]);
    });

    test('?estado= filtra', () async {
      expect(await listar('?estado=pendiente'), [pendiente.solicitudId]);
      expect(await listar('?estado=aprobada'), [aprobada.solicitudId]);
      expect(await listar('?estado=rechazada'), [rechazada.solicitudId]);
      expect(await listar('?estado='), hasLength(3));
    });

    test('un estado desconocido → 422', () async {
      _esperarValidacion(
        await api.get('/solicitudes?estado=cancelada', token: cuenta.token),
        {'estado': 'ESTADO_SOLICITUD_INVALIDO'},
      );
    });

    test('GET /solicitudes/{id} trae el comentario y la fecha de '
        'resolución', () async {
      final respuesta = await api.get(
        '/solicitudes/${rechazada.solicitudId}',
        token: cuenta.token,
      );

      expect(respuesta.estado, HttpStatus.ok);
      final solicitud = solicitudDe(respuesta);
      expect(solicitud['estado'], 'rechazada');
      expect(solicitud['comentario'], 'La foto no corresponde.');
      expect(
        DateTime.parse(solicitud['resuelta_en'] as String).isUtc,
        isTrue,
      );
      // Quién la resolvió no se le dice al usuario.
      expect(solicitud.containsKey('resuelta_por'), isFalse);
    });

    test(
      'la solicitud de otro usuario → 404, igual que si no existiera',
      () async {
        final ajena = await api.get(
          '/solicitudes/${pendiente.solicitudId}',
          token: otro.token,
        );
        final inexistente = await api.get(
          '/solicitudes/$idInexistente',
          token: otro.token,
        );

        _esperarError(ajena, HttpStatus.notFound, 'SOLICITUD_NO_ENCONTRADA');
        expect(ajena.json, inexistente.json);
        _esperarError(
          await api.get('/solicitudes/no-es-uuid', token: otro.token),
          HttpStatus.notFound,
          'SOLICITUD_NO_ENCONTRADA',
        );
        // Ni siquiera un admin la ve por esta ruta: es la de "mis solicitudes".
        _esperarError(
          await api.get(
            '/solicitudes/${pendiente.solicitudId}',
            token: admin.token,
          ),
          HttpStatus.notFound,
          'SOLICITUD_NO_ENCONTRADA',
        );
      },
    );

    test('sin token → 401', () async {
      for (final ruta in [
        '/solicitudes',
        '/solicitudes/${pendiente.solicitudId}',
      ]) {
        _esperarError(
          await api.get(ruta),
          HttpStatus.unauthorized,
          'NO_AUTENTICADO',
        );
      }
    });
  });

  group('POST /solicitudes/{id}/resolver', () {
    test('un usuario normal o un guardia → 403 y nada cambia', () async {
      final alta = await api.darDeAlta(titular);

      for (final cuenta in [titular, otro, guardia]) {
        _esperarError(
          await api.resolver(cuenta, alta.solicitudId, 'aprobar'),
          HttpStatus.forbidden,
          'SIN_PERMISO',
        );
      }
      _esperarError(
        await api.post(
          '/solicitudes/${alta.solicitudId}/resolver',
          cuerpo: {'decision': 'aprobar'},
        ),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
      expect(
        await api.leer('solicitudes', 'estado', alta.solicitudId),
        'pendiente',
      );
      expect(
        await api.leer('vehiculos', 'estado', alta.vehiculoId),
        'pendiente',
      );
    });

    test('aprobar un alta activa el vehículo y al usuario pendiente', () async {
      final nuevo = await api.crearCuenta(estado: 'pendiente');
      final alta = await api.darDeAlta(nuevo);

      final respuesta = await api.resolver(
        admin,
        alta.solicitudId,
        'aprobar',
        comentario: '  Todo en orden.  ',
      );

      expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
      final solicitud = solicitudDe(respuesta);
      expect(solicitud['estado'], 'aprobada');
      expect(solicitud['comentario'], 'Todo en orden.');
      expect(solicitud['resuelta_en'], isA<String>());
      expect(
        await api.leer('solicitudes', 'resuelta_por', alta.solicitudId),
        admin.id,
      );
      expect(await api.leer('vehiculos', 'estado', alta.vehiculoId), 'activo');
      expect(await api.leer('usuarios', 'estado', nuevo.id), 'activo');
      expect(await placasVisibles(nuevo), [alta.placa]);

      // Con la cuenta activa, el perfil queda bloqueado (Fase 1C).
      final perfil = await api.patch(
        '/perfil',
        cuerpo: {'nombre': 'Otro Nombre'},
        token: nuevo.token,
      );
      _esperarError(perfil, HttpStatus.conflict, 'PERFIL_BLOQUEADO');
    });

    test('aprobar deja un renglón en auditoría con el antes y el '
        'después', () async {
      final nuevo = await api.crearCuenta(estado: 'pendiente');
      final alta = await api.darDeAlta(nuevo);

      await api.resolver(admin, alta.solicitudId, 'aprobar');

      final renglon = (await api.auditoriaDe(alta.solicitudId)).single;
      expect(renglon.actor, admin.id);
      expect(renglon.accion, 'solicitud.aprobar');
      expect(renglon.entidad, 'solicitudes');
      final antes = renglon.antes!;
      final despues = renglon.despues!;
      expect((antes['solicitud'] as Map)['estado'], 'pendiente');
      expect((antes['vehiculo'] as Map)['estado'], 'pendiente');
      expect((antes['solicitante'] as Map)['estado'], 'pendiente');
      expect((despues['solicitud'] as Map)['estado'], 'aprobada');
      expect((despues['solicitud'] as Map)['resuelta_por'], admin.id);
      expect((despues['vehiculo'] as Map)['estado'], 'activo');
      expect((despues['vehiculo'] as Map)['placa'], alta.placa);
      expect((despues['solicitante'] as Map)['estado'], 'activo');
    });

    test(
      'rechazar un alta exige comentario y da de baja el vehículo',
      () async {
        final nuevo = await api.crearCuenta(estado: 'pendiente');
        final datos = await api.datosVehiculo(nuevo, tipo: 'moto');
        final creada = await api.solicitar(nuevo, {
          'tipo': 'alta',
          'datos': datos,
        });
        final id = solicitudDe(creada)['id'] as String;
        final vehiculoId = solicitudDe(creada)['vehiculo_id'] as String;

        for (final comentario in [null, '', '   ']) {
          _esperarValidacion(
            await api.resolver(admin, id, 'rechazar', comentario: comentario),
            {'comentario': 'COMENTARIO_REQUERIDO'},
          );
        }
        expect(await api.leer('solicitudes', 'estado', id), 'pendiente');

        final respuesta = await api.resolver(
          admin,
          id,
          'rechazar',
          comentario: 'La placa de la foto no coincide.',
        );

        expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
        expect(solicitudDe(respuesta)['estado'], 'rechazada');
        expect(
          solicitudDe(respuesta)['comentario'],
          'La placa de la foto no coincide.',
        );
        expect(await api.leer('vehiculos', 'estado', vehiculoId), 'baja');
        // El usuario sigue pendiente y ya no ve el vehículo.
        expect(await api.leer('usuarios', 'estado', nuevo.id), 'pendiente');
        expect(await placasVisibles(nuevo), isEmpty);
        expect(
          (await api.auditoriaDe(id)).single.accion,
          'solicitud.rechazar',
        );

        // Puede volver a intentarlo con la misma placa y las mismas fotos.
        final reintento = await api.solicitar(nuevo, {
          'tipo': 'alta',
          'datos': datos,
        });
        expect(
          reintento.estado,
          HttpStatus.created,
          reason: '${reintento.json}',
        );
      },
    );

    test('aprobar un cambio aplica los datos propuestos', () async {
      final moto = await api.darDeAlta(
        titular,
        tipo: 'moto',
        aprobadaPor: admin,
      );
      final credencial = await api.crearCredencial(
        moto.vehiculoId,
        identificador: 'CAMBIO-0001',
      );
      final datos = await api.datosVehiculo(
        titular,
        tipo: 'moto',
        cambios: {
          'numero_serie': 'SERIE-9',
          'marca': 'Honda',
          'modelo': 'CB190',
          'color': 'Negro',
        },
      );
      final creada = await api.solicitar(titular, {
        'tipo': 'cambio',
        'vehiculo_id': moto.vehiculoId,
        'datos': datos,
      });

      final respuesta = await api.resolver(
        admin,
        solicitudDe(creada)['id'] as String,
        'aprobar',
      );

      expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
      final vehiculos = await api.pool.execute(
        Sql.named(
          'SELECT tipo::text, placa, numero_serie, marca, modelo, color, '
          'foto_id::text, foto_placa_id::text, estado::text FROM vehiculos '
          'WHERE id = @id:uuid',
        ),
        parameters: {'id': moto.vehiculoId},
      );
      expect(vehiculos.single, [
        'moto',
        datos['placa'],
        'SERIE-9',
        'Honda',
        'CB190',
        'Negro',
        datos['foto_id'],
        datos['foto_placa_id'],
        'activo',
      ]);
      // Un cambio no toca las credenciales.
      expect(await api.leer('credenciales', 'estado', credencial), 'activa');
    });

    test('aprobar un cambio cuya placa ya tomó otro vehículo → 409 y la '
        'solicitud sigue pendiente', () async {
      final auto = await api.darDeAlta(titular, aprobadaPor: admin);
      final placaDeseada = placaNueva();
      final creada = await api.solicitar(titular, {
        'tipo': 'cambio',
        'vehiculo_id': auto.vehiculoId,
        'datos': await api.datosVehiculo(
          titular,
          cambios: {'placa': placaDeseada},
        ),
      });
      final id = solicitudDe(creada)['id'] as String;
      // Mientras se revisa, otro usuario registra esa placa.
      await api.darDeAlta(otro, cambios: {'placa': placaDeseada});

      _esperarError(
        await api.resolver(admin, id, 'aprobar'),
        HttpStatus.conflict,
        'PLACA_YA_REGISTRADA',
      );
      expect(await api.leer('solicitudes', 'estado', id), 'pendiente');
      expect(await api.leer('vehiculos', 'placa', auto.vehiculoId), auto.placa);
      expect(await api.auditoriaDe(id), isEmpty);
    });

    test('aprobar una baja da de baja el vehículo, desactiva a sus usuarios '
        'y revoca sus credenciales activas', () async {
      final auto = await api.darDeAlta(titular, aprobadaPor: admin);
      final autorizado = await api.crearCuenta();
      await api.autorizar(auto.vehiculoId, autorizado.id);
      final tag = await api.crearCredencial(
        auto.vehiculoId,
        identificador: 'BAJA-TAG-1',
      );
      final qr = await api.crearCredencial(
        auto.vehiculoId,
        identificador: 'BAJA-QR-1',
        tipo: 'qr',
        usuarioId: titular.id,
      );
      final perdida = await api.crearCredencial(
        auto.vehiculoId,
        identificador: 'BAJA-TAG-2',
        estado: 'perdida',
      );
      final deOtroVehiculo = await api.crearCredencial(
        (await api.darDeAlta(titular, aprobadaPor: admin)).vehiculoId,
        identificador: 'BAJA-TAG-3',
      );
      expect(await placasVisibles(autorizado), [auto.placa]);
      final creada = await api.solicitar(titular, {
        'tipo': 'baja',
        'vehiculo_id': auto.vehiculoId,
      });
      final id = solicitudDe(creada)['id'] as String;

      final respuesta = await api.resolver(admin, id, 'aprobar');

      expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
      expect(await api.leer('vehiculos', 'estado', auto.vehiculoId), 'baja');
      expect(await api.leer('credenciales', 'estado', tag), 'revocada');
      expect(await api.leer('credenciales', 'estado', qr), 'revocada');
      // Las que no estaban activas se quedan como estaban.
      expect(await api.leer('credenciales', 'estado', perdida), 'perdida');
      expect(
        await api.leer('credenciales', 'estado', deOtroVehiculo),
        'activa',
      );

      final activos = await api.pool.execute(
        Sql.named(
          'SELECT count(*)::int FROM vehiculo_usuarios '
          'WHERE vehiculo_id = @id:uuid AND activo',
        ),
        parameters: {'id': auto.vehiculoId},
      );
      expect(activos.single[0], 0);
      expect(await placasVisibles(titular), isNot(contains(auto.placa)));
      expect(await placasVisibles(autorizado), isEmpty);
      _esperarError(
        await api.get('/vehiculos/${auto.vehiculoId}', token: titular.token),
        HttpStatus.notFound,
        'VEHICULO_NO_ENCONTRADO',
      );
      // La baja del vehículo no cambia la cuenta de su titular.
      expect(await api.leer('usuarios', 'estado', titular.id), 'activo');

      final renglon = (await api.auditoriaDe(id)).single;
      expect(
        renglon.antes!['credenciales_activas'],
        unorderedEquals([tag, qr]),
      );
      expect(renglon.despues!['credenciales_activas'], isEmpty);
      expect(
        renglon.antes!['usuarios_autorizados'],
        unorderedEquals([titular.id, autorizado.id]),
      );
      expect(renglon.despues!['usuarios_autorizados'], isEmpty);

      // La placa queda libre para un vehículo nuevo.
      final denuevo = await api.darDeAlta(otro, cambios: {'placa': auto.placa});
      expect(denuevo.placa, auto.placa);
    });

    test(
      'rechazar un cambio o una baja solo cambia estado y comentario',
      () async {
        final auto = await api.darDeAlta(titular, aprobadaPor: admin);
        final tag = await api.crearCredencial(
          auto.vehiculoId,
          identificador: 'RECHAZO-TAG-1',
        );

        for (final cuerpo in <Map<String, Object?>>[
          {'tipo': 'baja', 'vehiculo_id': auto.vehiculoId},
          {
            'tipo': 'cambio',
            'vehiculo_id': auto.vehiculoId,
            'datos': await api.datosVehiculo(
              titular,
              cambios: {'color': 'Rojo'},
            ),
          },
        ]) {
          final creada = await api.solicitar(titular, cuerpo);
          final id = solicitudDe(creada)['id'] as String;

          final respuesta = await api.resolver(
            admin,
            id,
            'rechazar',
            comentario: 'No procede.',
          );

          expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
          expect(solicitudDe(respuesta)['estado'], 'rechazada');
          expect(
            await api.leer('vehiculos', 'estado', auto.vehiculoId),
            'activo',
          );
          expect(
            await api.leer('vehiculos', 'placa', auto.vehiculoId),
            auto.placa,
          );
          expect(await api.leer('vehiculos', 'color', auto.vehiculoId), 'Gris');
          expect(await api.leer('credenciales', 'estado', tag), 'activa');
        }
        expect(await placasVisibles(titular), contains(auto.placa));
      },
    );

    test('una solicitud ya resuelta → 409 SOLICITUD_YA_RESUELTA', () async {
      final alta = await api.darDeAlta(titular, aprobadaPor: admin);

      for (final decision in ['aprobar', 'rechazar']) {
        _esperarError(
          await api.resolver(
            admin,
            alta.solicitudId,
            decision,
            comentario: 'Otra vez',
          ),
          HttpStatus.conflict,
          'SOLICITUD_YA_RESUELTA',
        );
      }
      expect(await api.leer('vehiculos', 'estado', alta.vehiculoId), 'activo');
      expect(
        await api.leer('solicitudes', 'comentario', alta.solicitudId),
        isNull,
      );
      expect(await api.auditoriaDe(alta.solicitudId), hasLength(1));
    });

    test('decisión desconocida o comentario muy largo → 422', () async {
      final alta = await api.darDeAlta(titular);

      for (final decision in ['aprobada', 'si', '']) {
        _esperarValidacion(
          await api.resolver(admin, alta.solicitudId, decision),
          {'decision': 'DECISION_INVALIDA'},
        );
      }
      _esperarValidacion(
        await api.resolver(
          admin,
          alta.solicitudId,
          'rechazar',
          comentario: 'x' * 501,
        ),
        {'comentario': 'COMENTARIO_MUY_LARGO'},
      );
    });

    test('una solicitud que no existe → 404; GET → 405', () async {
      for (final id in [idInexistente, 'no-es-uuid']) {
        _esperarError(
          await api.resolver(admin, id, 'aprobar'),
          HttpStatus.notFound,
          'SOLICITUD_NO_ENCONTRADA',
        );
      }
      _esperarError(
        await api.get(
          '/solicitudes/$idInexistente/resolver',
          token: admin.token,
        ),
        HttpStatus.methodNotAllowed,
        'METODO_NO_PERMITIDO',
      );
    });
  });
}
