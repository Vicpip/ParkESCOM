@TestOn('vm')
library;

import 'package:backend/db/conexion.dart';
import 'package:backend/db/migrador.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../soporte/base_pruebas.dart';

/// SQLSTATE de violación de unicidad.
const _unicidad = '23505';

/// SQLSTATE de violación de un CHECK.
const _check = '23514';

/// SQLSTATE de violación de NOT NULL.
const _noNulo = '23502';

/// SQLSTATE de un valor que no pertenece al enum.
const _valorInvalido = '22P02';

Matcher _fallaCon(String sqlstate) => throwsA(
  isA<ServerException>().having((e) => e.code, 'SQLSTATE', sqlstate),
);

void main() {
  late Connection db;
  late Migrador migrador;
  late String puertaId;
  var consecutivo = 0;

  Future<String> insertar(
    String sql, [
    Map<String, Object?>? parametros,
  ]) async {
    final filas = await db.execute(
      Sql.named('$sql RETURNING id::text'),
      parameters: parametros,
    );
    return filas.single[0]! as String;
  }

  Future<String> crearUsuario() {
    consecutivo++;
    return insertar(
      'INSERT INTO usuarios (correo, hash_password, nombre, boleta_o_empleado) '
      "VALUES (@correo, 'hash', 'Usuario de prueba', @boleta)",
      {
        'correo': 'prueba$consecutivo@alumno.ipn.mx',
        'boleta': 'B$consecutivo',
      },
    );
  }

  Future<String> crearVehiculo({String? placa, String estado = 'pendiente'}) =>
      insertar(
        'INSERT INTO vehiculos (tipo, placa, estado) '
        "VALUES ('auto', @placa:text, CAST(@estado:text AS estado_registro))",
        {'placa': placa, 'estado': estado},
      );

  Future<String> crearMovimiento(
    String? vehiculoId, {
    String? id,
    String? pase,
    String? puerta,
    String sentido = 'entrada',
  }) => insertar(
    'INSERT INTO movimientos '
    '(id, vehiculo_id, pase_id, puerta_id, sentido, hora_dispositivo, fuente, '
    'resultado) VALUES (coalesce(@id:uuid, gen_random_uuid()), '
    '@vehiculo:uuid, @pase:uuid, @puerta:uuid, '
    "CAST(@sentido:text AS sentido), now(), 'rfid', 'aceptado')",
    {
      'id': id,
      'vehiculo': vehiculoId,
      'pase': pase,
      'puerta': puerta ?? puertaId,
      'sentido': sentido,
    },
  );

  Future<String> crearPase() async => insertar(
    'INSERT INTO pases (solicitante_id, visitante, ventana_inicio, '
    "ventana_fin) VALUES (@solicitante:uuid, 'Visitante de prueba', now(), "
    "now() + interval '2 hours')",
    {'solicitante': await crearUsuario()},
  );

  /// Abre una estancia con un movimiento de entrada nuevo.
  Future<String> abrirEstancia({String? vehiculo, String? pase}) async =>
      insertar(
        'INSERT INTO estancias (vehiculo_id, pase_id, entrada_id) '
        'VALUES (@vehiculo:uuid, @pase:uuid, @entrada:uuid)',
        {
          'vehiculo': vehiculo,
          'pase': pase,
          'entrada': await crearMovimiento(vehiculo, pase: pase),
        },
      );

  Future<String> crearCredencial(
    String vehiculoId,
    String identificador,
  ) => insertar(
    'INSERT INTO credenciales (vehiculo_id, tipo, identificador) '
    "VALUES (@vehiculo:uuid, 'tag_propio', @identificador)",
    {'vehiculo': vehiculoId, 'identificador': identificador},
  );

  setUpAll(() async {
    final url = await recrearBaseDePruebas();
    db = await abrirConexion(url);
    migrador = Migrador(db, raizDb: Migrador.buscarRaizDb());
    await migrador.migrar();
    await migrador.sembrar();
    final filas = await db.execute(
      "SELECT id::text FROM puertas WHERE nombre = 'Puerta A'",
    );
    puertaId = filas.single[0]! as String;
  });

  tearDownAll(() => db.close());

  test('la migración es idempotente', () async {
    expect(await migrador.migrar(), isEmpty);
    await migrador.sembrar();

    Future<int> contar(String tabla) async {
      final filas = await db.execute('SELECT count(*)::int FROM $tabla');
      return filas.single[0]! as int;
    }

    expect(await contar('schema_migrations'), 5);
    expect(await contar('puertas'), 2);
    expect(await contar('zonas'), 3);
  });

  test('anti-passback: una segunda estancia abierta falla', () async {
    final vehiculo = await crearVehiculo();

    await abrirEstancia(vehiculo: vehiculo);
    await expectLater(abrirEstancia(vehiculo: vehiculo), _fallaCon(_unicidad));
  });

  test('una sola credencial activa por (tipo, identificador)', () async {
    final vehiculo = await crearVehiculo();
    final primera = await crearCredencial(vehiculo, 'E2801160600002');

    await expectLater(
      crearCredencial(vehiculo, 'E2801160600002'),
      _fallaCon(_unicidad),
    );

    await db.execute(
      Sql.named(
        "UPDATE credenciales SET estado = 'revocada' WHERE id = @id:uuid",
      ),
      parameters: {'id': primera},
    );
    await expectLater(crearCredencial(vehiculo, 'E2801160600002'), completes);
  });

  test('dos movimientos con el mismo id fallan', () async {
    final vehiculo = await crearVehiculo();
    const id = '0b9d3c2e-6a4f-4f0e-9d53-1c2b7a8e4f10';

    await crearMovimiento(vehiculo, id: id);
    await expectLater(
      crearMovimiento(vehiculo, id: id),
      _fallaCon(_unicidad),
    );
  });

  test('un segundo titular para el mismo vehículo falla', () async {
    final vehiculo = await crearVehiculo();
    Future<void> agregarTitular(String usuario) => db.execute(
      Sql.named(
        'INSERT INTO vehiculo_usuarios (vehiculo_id, usuario_id, es_titular) '
        'VALUES (@vehiculo:uuid, @usuario:uuid, true)',
      ),
      parameters: {'vehiculo': vehiculo, 'usuario': usuario},
    );

    await agregarTitular(await crearUsuario());
    await expectLater(
      agregarTitular(await crearUsuario()),
      _fallaCon(_unicidad),
    );
  });

  test(
    'los folios de incidentes se generan solos y son consecutivos',
    () async {
      final folios = <int>[];
      for (var i = 0; i < 3; i++) {
        final filas = await db.execute(
          'INSERT INTO incidentes (tipo, descripcion) '
          "VALUES ('otro', 'Incidente de prueba') RETURNING folio",
        );
        folios.add(filas.single[0]! as int);
      }

      expect(folios, [1, 2, 3]);
    },
  );

  test(
    'el trigger actualiza actualizado_en al modificar una credencial',
    () async {
      final credencial = await crearCredencial(
        await crearVehiculo(),
        'E2801160600099',
      );
      Future<DateTime> actualizadoEn() async {
        final filas = await db.execute(
          Sql.named(
            'SELECT actualizado_en FROM credenciales WHERE id = @id:uuid',
          ),
          parameters: {'id': credencial},
        );
        return filas.single[0]! as DateTime;
      }

      final antes = await actualizadoEn();
      await db.execute(
        Sql.named(
          "UPDATE credenciales SET estado = 'perdida' WHERE id = @id:uuid",
        ),
        parameters: {'id': credencial},
      );

      expect((await actualizadoEn()).isAfter(antes), isTrue);
    },
  );

  test('la placa solo es única entre vehículos que no están de baja', () async {
    await crearVehiculo(placa: 'ABC-123', estado: 'baja');

    await expectLater(
      crearVehiculo(placa: 'ABC-123', estado: 'activo'),
      completes,
    );
    await expectLater(
      crearVehiculo(placa: 'ABC-123', estado: 'activo'),
      _fallaCon(_unicidad),
    );
    await expectLater(crearVehiculo(placa: 'ABC-123'), _fallaCon(_unicidad));
  });

  test('una credencial sin vehículo falla', () async {
    await expectLater(
      insertar(
        'INSERT INTO credenciales (usuario_id, tipo, identificador) '
        "VALUES (@usuario:uuid, 'tag_propio', 'E2801160600100')",
        {'usuario': await crearUsuario()},
      ),
      _fallaCon(_noNulo),
    );
  });

  test('un QR sin usuario falla; con usuario y vehículo se acepta', () async {
    final vehiculo = await crearVehiculo();
    Future<String> crearQr(String? usuario) => insertar(
      'INSERT INTO credenciales (vehiculo_id, usuario_id, tipo, '
      "identificador) VALUES (@vehiculo:uuid, @usuario:uuid, 'qr', @id)",
      {'vehiculo': vehiculo, 'usuario': usuario, 'id': 'qr-$vehiculo'},
    );

    await expectLater(crearQr(null), _fallaCon(_check));
    await expectLater(crearQr(await crearUsuario()), completes);
  });

  test('un solo QR activo por cada par usuario-vehículo', () async {
    final vehiculo = await crearVehiculo();
    final usuario = await crearUsuario();
    var emitidos = 0;
    Future<String> crearQr(String usuarioId) => insertar(
      'INSERT INTO credenciales (vehiculo_id, usuario_id, tipo, '
      "identificador) VALUES (@vehiculo:uuid, @usuario:uuid, 'qr', @id)",
      {
        'vehiculo': vehiculo,
        'usuario': usuarioId,
        'id': 'qr-$vehiculo-${emitidos++}',
      },
    );

    final primero = await crearQr(usuario);
    await expectLater(crearQr(usuario), _fallaCon(_unicidad));

    // Otro usuario autorizado sobre el mismo vehículo sí tiene su propio QR.
    await expectLater(crearQr(await crearUsuario()), completes);

    // Con el primero revocado se puede emitir uno nuevo para el mismo par.
    await db.execute(
      Sql.named(
        "UPDATE credenciales SET estado = 'revocada' WHERE id = @id:uuid",
      ),
      parameters: {'id': primero},
    );
    await expectLater(crearQr(usuario), completes);
  });

  test('una estancia exige exactamente un vehículo o un pase', () async {
    final vehiculo = await crearVehiculo();
    final pase = await crearPase();
    Future<String> abrirCon({String? vehiculo, String? pase}) async => insertar(
      'INSERT INTO estancias (vehiculo_id, pase_id, entrada_id) '
      'VALUES (@vehiculo:uuid, @pase:uuid, @entrada:uuid)',
      {
        'vehiculo': vehiculo,
        'pase': pase,
        'entrada': await crearMovimiento(null),
      },
    );

    await expectLater(abrirCon(), _fallaCon(_check));
    await expectLater(
      abrirCon(vehiculo: vehiculo, pase: pase),
      _fallaCon(_check),
    );
  });

  test('un pase con estancia abierta no puede abrir otra', () async {
    final pase = await crearPase();

    await abrirEstancia(pase: pase);
    await expectLater(abrirEstancia(pase: pase), _fallaCon(_unicidad));
  });

  test('un incidente con un tipo fuera del enum falla', () async {
    await expectLater(
      db.execute(
        'INSERT INTO incidentes (tipo, descripcion) '
        "VALUES ('prueba', 'Incidente de prueba')",
      ),
      _fallaCon(_valorInvalido),
    );
  });

  test('un vehículo entra por la Puerta A y sale por la Puerta B', () async {
    final puertas = await db.execute(
      'SELECT nombre, id::text, tipos_vehiculo::text[] FROM puertas '
      'ORDER BY nombre',
    );
    expect(puertas.map((fila) => fila[0]), ['Puerta A', 'Puerta B']);
    for (final fila in puertas) {
      expect(
        fila[2],
        unorderedEquals(['auto', 'moto', 'bici', 'scooter']),
        reason: '${fila[0]} acepta todos los tipos de vehículo',
      );
    }
    final puertaB = puertas.last[1]! as String;

    final vehiculo = await crearVehiculo();
    final estancia = await abrirEstancia(vehiculo: vehiculo);
    final salida = await crearMovimiento(
      vehiculo,
      puerta: puertaB,
      sentido: 'salida',
    );
    await db.execute(
      Sql.named(
        'UPDATE estancias SET salida_id = @salida:uuid WHERE id = @id:uuid',
      ),
      parameters: {'salida': salida, 'id': estancia},
    );

    final filas = await db.execute(
      Sql.named(
        'SELECT pe.nombre, ps.nombre FROM estancias e '
        'JOIN movimientos me ON me.id = e.entrada_id '
        'JOIN puertas pe ON pe.id = me.puerta_id '
        'JOIN movimientos ms ON ms.id = e.salida_id '
        'JOIN puertas ps ON ps.id = ms.puerta_id '
        'WHERE e.id = @id:uuid',
      ),
      parameters: {'id': estancia},
    );
    expect(filas.single, ['Puerta A', 'Puerta B']);

    // Con la estancia cerrada, el vehículo puede volver a entrar.
    await expectLater(abrirEstancia(vehiculo: vehiculo), completes);
  });

  group('solicitudes', () {
    Future<String> crearSolicitud(
      String usuario,
      String? vehiculo, {
      String tipo = 'cambio',
      String estado = 'pendiente',
    }) => insertar(
      'INSERT INTO solicitudes (usuario_id, vehiculo_id, tipo, estado) '
      'VALUES (@usuario:uuid, @vehiculo:uuid, '
      'CAST(@tipo:text AS tipo_solicitud), '
      'CAST(@estado:text AS estado_solicitud))',
      {
        'usuario': usuario,
        'vehiculo': vehiculo,
        'tipo': tipo,
        'estado': estado,
      },
    );

    test('dos solicitudes pendientes sobre el mismo vehículo fallan', () async {
      final usuario = await crearUsuario();
      final vehiculo = await crearVehiculo();

      await crearSolicitud(usuario, vehiculo);
      await expectLater(
        crearSolicitud(usuario, vehiculo, tipo: 'baja'),
        _fallaCon(_unicidad),
      );
      // Tampoco si la pide otro usuario: la regla es por vehículo.
      await expectLater(
        crearSolicitud(await crearUsuario(), vehiculo),
        _fallaCon(_unicidad),
      );
    });

    test('una aprobada y una pendiente conviven', () async {
      final usuario = await crearUsuario();
      final vehiculo = await crearVehiculo();

      await crearSolicitud(usuario, vehiculo, tipo: 'alta', estado: 'aprobada');
      await crearSolicitud(usuario, vehiculo, estado: 'rechazada');
      await expectLater(crearSolicitud(usuario, vehiculo), completes);
    });

    test('al resolverse la pendiente se puede crear otra', () async {
      final usuario = await crearUsuario();
      final vehiculo = await crearVehiculo();
      final primera = await crearSolicitud(usuario, vehiculo);

      await db.execute(
        Sql.named(
          "UPDATE solicitudes SET estado = 'aprobada' WHERE id = @id:uuid",
        ),
        parameters: {'id': primera},
      );

      await expectLater(crearSolicitud(usuario, vehiculo), completes);
    });

    test('vehículos distintos tienen cada uno su pendiente', () async {
      final usuario = await crearUsuario();

      await crearSolicitud(usuario, await crearVehiculo());
      await expectLater(
        crearSolicitud(usuario, await crearVehiculo()),
        completes,
      );
    });

    test('las solicitudes sin vehículo no chocan entre sí', () async {
      final usuario = await crearUsuario();

      await crearSolicitud(usuario, null, tipo: 'alta');
      await expectLater(crearSolicitud(usuario, null, tipo: 'alta'), completes);
    });

    test('existen los dos índices de la migración 005', () async {
      final filas = await db.execute(
        'SELECT indexname, indexdef FROM pg_indexes WHERE tablename = '
        "'solicitudes' AND indexname <> 'solicitudes_pkey' ORDER BY indexname",
      );
      final indices = {
        for (final fila in filas) fila[0]! as String: fila[1]! as String,
      };

      expect(indices.keys, [
        'solicitudes_una_pendiente',
        'solicitudes_usuario_creado_idx',
      ]);
      expect(indices['solicitudes_una_pendiente'], contains('UNIQUE'));
      expect(
        indices['solicitudes_usuario_creado_idx'],
        contains('(usuario_id, creado_en DESC)'),
      );
    });
  });

  group('archivos.proposito', () {
    var archivos = 0;

    Future<String> crearArchivo(String? proposito) {
      archivos++;
      return insertar(
        'INSERT INTO archivos (ruta, tipo_mime, tamano_bytes, proposito) '
        "VALUES (@ruta, 'image/png', 10, "
        'CAST(@proposito:text AS proposito_archivo))',
        {'ruta': 'esquema-$archivos.png', 'proposito': proposito},
      );
    }

    test('el enum tiene exactamente los cinco propósitos', () async {
      final filas = await db.execute(
        'SELECT unnest(enum_range(NULL::proposito_archivo))::text',
      );
      expect(filas.map((fila) => fila[0]), [
        'perfil',
        'credencial_escolar',
        'vehiculo',
        'placa',
        'incidente',
      ]);
    });

    test('acepta cada propósito del enum', () async {
      for (final proposito in [
        'perfil',
        'credencial_escolar',
        'vehiculo',
        'placa',
        'incidente',
      ]) {
        await expectLater(crearArchivo(proposito), completes);
      }
    });

    test('un archivo sin propósito falla', () async {
      await expectLater(crearArchivo(null), _fallaCon(_noNulo));
    });

    test('un propósito fuera del enum falla', () async {
      await expectLater(crearArchivo('otro'), _fallaCon(_valorInvalido));
    });
  });
}
