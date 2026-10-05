@TestOn('vm')
library;

import 'package:backend/config/entorno.dart';
import 'package:backend/db/conexion.dart';
import 'package:backend/db/migrador.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

/// SQLSTATE de violación de unicidad.
const _unicidad = '23505';

/// Borra y vuelve a crear la base de pruebas para empezar desde cero.
Future<void> _recrearBase(String urlPruebas) async {
  final uri = Uri.parse(urlPruebas);
  final base = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(base)) {
    fail('DATABASE_URL_TEST debe terminar en un nombre de base simple.');
  }
  final urlPrincipal = leerEntorno('DATABASE_URL');
  if (urlPrincipal != null &&
      Uri.parse(urlPrincipal).pathSegments.firstOrNull == base) {
    fail(
      'DATABASE_URL_TEST apunta a la misma base que DATABASE_URL; '
      'las pruebas la borrarían.',
    );
  }

  final admin = await abrirConexion(
    uri.replace(path: '/postgres').toString(),
  );
  try {
    await admin.execute('DROP DATABASE IF EXISTS "$base" WITH (FORCE)');
    await admin.execute('CREATE DATABASE "$base"');
  } finally {
    await admin.close();
  }
}

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

  Future<String> crearVehiculo() =>
      insertar("INSERT INTO vehiculos (tipo) VALUES ('auto')");

  Future<String> crearMovimiento(String vehiculoId, {String? id}) => insertar(
    'INSERT INTO movimientos '
    '(id, vehiculo_id, puerta_id, sentido, hora_dispositivo, fuente, '
    'resultado) VALUES (coalesce(@id:uuid, gen_random_uuid()), '
    "@vehiculo:uuid, @puerta:uuid, 'entrada', now(), 'rfid', 'aceptado')",
    {'id': id, 'vehiculo': vehiculoId, 'puerta': puertaId},
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
    final url = exigirEntorno('DATABASE_URL_TEST');
    await _recrearBase(url);
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

    expect(await contar('schema_migrations'), 1);
    expect(await contar('puertas'), 2);
    expect(await contar('zonas'), 3);
  });

  test('anti-passback: una segunda estancia abierta falla', () async {
    final vehiculo = await crearVehiculo();
    Future<String> abrirEstancia() async => insertar(
      'INSERT INTO estancias (vehiculo_id, entrada_id) '
      'VALUES (@vehiculo:uuid, @entrada:uuid)',
      {'vehiculo': vehiculo, 'entrada': await crearMovimiento(vehiculo)},
    );

    await abrirEstancia();
    await expectLater(abrirEstancia(), _fallaCon(_unicidad));
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
          "VALUES ('prueba', 'Incidente de prueba') RETURNING folio",
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
}
