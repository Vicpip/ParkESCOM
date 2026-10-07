@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:backend/auth/usuario.dart';
import 'package:shared/shared.dart';
import 'package:test/test.dart';

import '../soporte/servidor_pruebas.dart';
import '../soporte/vehiculos_pruebas.dart';

void _esperarError(Respuesta respuesta, int estado, String codigo) {
  expect(respuesta.estado, estado, reason: '${respuesta.json}');
  expect(errorDe(respuesta)['code'], codigo);
}

void main() {
  late ServidorPruebas api;
  late Cuenta admin;
  late Cuenta guardia;
  late Cuenta titular;
  late Cuenta autorizado;
  late Cuenta otro;
  late Alta auto;
  late Alta moto;
  late Alta bici;
  late Alta enRevision;

  Future<List<Map<String, dynamic>>> listar(
    Cuenta cuenta, [
    String consulta = '',
  ]) async {
    final respuesta = await api.get('/vehiculos$consulta', token: cuenta.token);
    expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
    return (objeto(respuesta)['vehiculos'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<List<String>> ids(Cuenta cuenta, [String consulta = '']) async => [
    for (final vehiculo in await listar(cuenta, consulta))
      vehiculo['id'] as String,
  ];

  Future<Respuesta> detalle(Cuenta cuenta, String id) =>
      api.get('/vehiculos/$id', token: cuenta.token);

  setUpAll(() async {
    api = await ServidorPruebas.levantar();
    admin = await api.crearCuenta(rol: Rol.admin);
    guardia = await api.crearCuenta(rol: Rol.guardia);
    titular = await api.crearCuenta();
    autorizado = await api.crearCuenta();
    otro = await api.crearCuenta();

    auto = await api.darDeAlta(
      titular,
      cambios: {'placa': 'AUT-100', 'marca': 'Nissan'},
      aprobadaPor: admin,
    );
    moto = await api.darDeAlta(
      titular,
      tipo: 'moto',
      cambios: {'placa': 'MOT0-22', 'marca': 'Italika 100%'},
      aprobadaPor: admin,
    );
    bici = await api.darDeAlta(
      titular,
      tipo: 'bici',
      cambios: {'placa': null, 'marca': 'Benotto', 'numero_serie': 'BN-77'},
      aprobadaPor: admin,
    );
    enRevision = await api.darDeAlta(
      titular,
      cambios: {'placa': 'REV-300', 'marca': 'Mazda'},
    );
    await api.autorizar(auto.vehiculoId, autorizado.id);
  });
  tearDownAll(() => api.cerrar());

  group('GET /vehiculos', () {
    test(
      'los vehículos del usuario, del más reciente al más antiguo',
      () async {
        final vehiculos = await listar(titular);

        expect(vehiculos.map((v) => v['id']), [
          enRevision.vehiculoId,
          bici.vehiculoId,
          moto.vehiculoId,
          auto.vehiculoId,
        ]);
        expect(vehiculos.last, {
          'id': auto.vehiculoId,
          'tipo': 'auto',
          'placa': 'AUT-100',
          'marca': 'Nissan',
          'modelo': 'Versa 2020',
          'color': 'Gris',
          'estado': 'activo',
          'foto_id': isA<String>(),
          'es_titular': true,
        });
        expect(vehiculos.first['estado'], 'pendiente');
        // Cada elemento se lee con el modelo compartido.
        expect(vehiculos.map(VehiculoResumen.fromJson), hasLength(4));
      },
    );

    test('un usuario autorizado ve el vehículo, sin ser titular', () async {
      final vehiculos = await listar(autorizado);

      expect(vehiculos.single['id'], auto.vehiculoId);
      expect(vehiculos.single['es_titular'], isFalse);
    });

    test('otro usuario no ve ninguno', () async {
      expect(await listar(otro), isEmpty);
      // Tampoco un admin o un guardia: esta ruta es la de "mis vehículos".
      expect(await listar(admin), isEmpty);
      expect(await listar(guardia), isEmpty);
    });

    test('una autorización inactiva ya no cuenta', () async {
      final exautorizado = await api.crearCuenta();
      await api.autorizar(moto.vehiculoId, exautorizado.id);
      expect(await ids(exautorizado), [moto.vehiculoId]);

      await api.pool.execute(
        'UPDATE vehiculo_usuarios SET activo = false '
        "WHERE usuario_id = '${exautorizado.id}'",
      );

      expect(await ids(exautorizado), isEmpty);
      _esperarError(
        await detalle(exautorizado, moto.vehiculoId),
        HttpStatus.notFound,
        'VEHICULO_NO_ENCONTRADO',
      );
    });

    test('?tipo= filtra por tipo', () async {
      expect(await ids(titular, '?tipo=auto'), [
        enRevision.vehiculoId,
        auto.vehiculoId,
      ]);
      expect(await ids(titular, '?tipo=moto'), [moto.vehiculoId]);
      expect(await ids(titular, '?tipo=bici'), [bici.vehiculoId]);
      expect(await ids(titular, '?tipo=scooter'), isEmpty);
      expect(await ids(titular, '?tipo='), hasLength(4));
    });

    test('un tipo desconocido → 422', () async {
      final respuesta = await api.get(
        '/vehiculos?tipo=camion',
        token: titular.token,
      );

      _esperarError(respuesta, HttpStatus.unprocessableEntity, 'VALIDACION');
      expect(errorDe(respuesta)['campos'], {'tipo': 'TIPO_VEHICULO_INVALIDO'});
    });

    test('?q= busca un fragmento de la placa o de la marca', () async {
      expect(await ids(titular, '?q=aut'), [auto.vehiculoId]);
      expect(await ids(titular, '?q=T-10'), [auto.vehiculoId]);
      expect(await ids(titular, '?q=NISS'), [auto.vehiculoId]);
      expect(await ids(titular, '?q=benot'), [bici.vehiculoId]);
      // "a" está en AUT-100, Italika, Mazda y Nissan.
      expect(await ids(titular, '?q=a'), [
        enRevision.vehiculoId,
        moto.vehiculoId,
        auto.vehiculoId,
      ]);
      expect(await ids(titular, '?q=zzz'), isEmpty);
      expect(await ids(titular, '?q=%20%20'), hasLength(4));
    });

    test('?q= ignora los espacios al buscar por placa', () async {
      expect(await ids(titular, '?q=aut%20-%20100'), [auto.vehiculoId]);
      expect(await ids(titular, '?q=%20mot0%20'), [moto.vehiculoId]);
    });

    test('?q= trata % y _ como texto, no como comodines', () async {
      expect(await ids(titular, '?q=%25'), [moto.vehiculoId]);
      expect(await ids(titular, '?q=100%25'), [moto.vehiculoId]);
      expect(await ids(titular, '?q=_'), isEmpty);
      expect(await ids(titular, '?q=A_T'), isEmpty);
      expect(
        await ids(titular, "?q=${Uri.encodeComponent("' OR 1=1 --")}"),
        isEmpty,
      );
    });

    test('?tipo= y ?q= se combinan', () async {
      expect(await ids(titular, '?tipo=auto&q=mazda'), [enRevision.vehiculoId]);
      expect(await ids(titular, '?tipo=moto&q=mazda'), isEmpty);
    });

    test('sin token → 401; POST → 405', () async {
      _esperarError(
        await api.get('/vehiculos'),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
      _esperarError(
        await api.post('/vehiculos', token: titular.token),
        HttpStatus.methodNotAllowed,
        'METODO_NO_PERMITIDO',
      );
    });
  });

  group('GET /vehiculos/{id}', () {
    late String tag;
    late String qrTitular;
    late String qrAutorizado;

    setUpAll(() async {
      tag = await api.crearCredencial(
        auto.vehiculoId,
        identificador: 'E2801190A5030064033DC8B7',
      );
      qrTitular = await api.crearCredencial(
        auto.vehiculoId,
        identificador: 'qr-identificador-titular-AAAA',
        tipo: 'qr',
        usuarioId: titular.id,
        semilla: 'SEMILLA-SECRETA-TITULAR',
      );
      qrAutorizado = await api.crearCredencial(
        auto.vehiculoId,
        identificador: 'qr-identificador-autorizado-BBBB',
        tipo: 'qr',
        usuarioId: autorizado.id,
        semilla: 'SEMILLA-SECRETA-AUTORIZADO',
      );
      await api.crearCredencial(
        auto.vehiculoId,
        identificador: 'E2801190A5030064033D0001',
        estado: 'revocada',
      );
    });

    test(
      'datos, fotos, credenciales, usuarios y solicitud pendiente',
      () async {
        final respuesta = await detalle(titular, auto.vehiculoId);

        expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
        final vehiculo = objeto(respuesta)['vehiculo'] as Map<String, dynamic>;
        expect(vehiculo, {
          'id': auto.vehiculoId,
          'tipo': 'auto',
          'placa': 'AUT-100',
          'marca': 'Nissan',
          'modelo': 'Versa 2020',
          'color': 'Gris',
          'estado': 'activo',
          'foto_id': isA<String>(),
          'es_titular': true,
          'numero_serie': null,
          'foto_placa_id': null,
          'credenciales': [
            {
              'id': tag,
              'tipo': 'tag_propio',
              'estado': 'activa',
              'terminacion': 'C8B7',
              'vigencia': null,
            },
            {
              'id': qrTitular,
              'tipo': 'qr',
              'estado': 'activa',
              'terminacion': 'AAAA',
              'vigencia': null,
            },
            {
              'id': qrAutorizado,
              'tipo': 'qr',
              'estado': 'activa',
              'terminacion': 'BBBB',
              'vigencia': null,
            },
            {
              'id': isA<String>(),
              'tipo': 'tag_propio',
              'estado': 'revocada',
              'terminacion': '0001',
              'vigencia': null,
            },
          ],
          'usuarios_autorizados': [
            {'nombre': isA<String>(), 'es_titular': true},
            {'nombre': isA<String>(), 'es_titular': false},
          ],
          'solicitud_pendiente': false,
        });
        expect(VehiculoDetalle.fromJson(vehiculo).credenciales, hasLength(4));
      },
    );

    test('nunca sale la semilla ni el identificador completo', () async {
      for (final cuenta in [titular, autorizado]) {
        final texto = utf8.decode(
          (await detalle(cuenta, auto.vehiculoId)).bytes,
        );

        expect(texto, isNot(contains('SEMILLA')));
        expect(texto, isNot(contains('semilla')));
        expect(texto, isNot(contains('identificador')));
        expect(texto, isNot(contains('E2801190A5030064033D')));
      }
    });

    test('un usuario autorizado ve los tags y solo su propio QR', () async {
      final respuesta = await detalle(autorizado, auto.vehiculoId);

      expect(respuesta.estado, HttpStatus.ok);
      final vehiculo = objeto(respuesta)['vehiculo'] as Map<String, dynamic>;
      expect(vehiculo['es_titular'], isFalse);
      final credenciales = (vehiculo['credenciales'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(credenciales.map((c) => c['id']), contains(tag));
      expect(credenciales.where((c) => c['tipo'] == 'qr').map((c) => c['id']), [
        qrAutorizado,
      ]);
    });

    test(
      'la moto trae la foto de su placa y la bici su número de serie',
      () async {
        final deMoto =
            objeto(await detalle(titular, moto.vehiculoId))['vehiculo']
                as Map<String, dynamic>;
        final deBici =
            objeto(await detalle(titular, bici.vehiculoId))['vehiculo']
                as Map<String, dynamic>;

        expect(deMoto['foto_placa_id'], isA<String>());
        expect(deMoto['credenciales'], isEmpty);
        expect(deBici['placa'], isNull);
        expect(deBici['numero_serie'], 'BN-77');
        expect(deBici['usuarios_autorizados'], hasLength(1));
      },
    );

    test('con el alta en revisión: pendiente y solicitud_pendiente', () async {
      final vehiculo =
          objeto(await detalle(titular, enRevision.vehiculoId))['vehiculo']
              as Map<String, dynamic>;

      expect(vehiculo['estado'], 'pendiente');
      expect(vehiculo['solicitud_pendiente'], isTrue);
    });

    test('otro usuario → 404, igual que si el vehículo no existiera', () async {
      final ajeno = await detalle(otro, auto.vehiculoId);
      final inexistente = await detalle(otro, idInexistente);

      _esperarError(ajeno, HttpStatus.notFound, 'VEHICULO_NO_ENCONTRADO');
      expect(ajeno.json, inexistente.json);
      _esperarError(
        await detalle(otro, 'no-es-uuid'),
        HttpStatus.notFound,
        'VEHICULO_NO_ENCONTRADO',
      );
      // Admin y guardia tampoco lo ven por esta ruta.
      for (final cuenta in [admin, guardia]) {
        _esperarError(
          await detalle(cuenta, auto.vehiculoId),
          HttpStatus.notFound,
          'VEHICULO_NO_ENCONTRADO',
        );
      }
    });

    test('sin token → 401; POST → 405', () async {
      _esperarError(
        await api.get('/vehiculos/${auto.vehiculoId}'),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
      _esperarError(
        await api.post('/vehiculos/${auto.vehiculoId}', token: titular.token),
        HttpStatus.methodNotAllowed,
        'METODO_NO_PERMITIDO',
      );
    });
  });
}
