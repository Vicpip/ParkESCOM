@TestOn('vm')
library;

import 'dart:io';

import 'package:backend/auth/usuario.dart';
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
  late Cuenta titular;
  late Cuenta autorizado;
  late Cuenta otro;
  late Alta auto;
  var consecutivo = 0;

  Future<String> crearTag({String estado = 'activa'}) => api.crearCredencial(
    auto.vehiculoId,
    identificador: 'E2801190A503006403${1000 + ++consecutivo}',
    estado: estado,
  );

  Future<String> crearQr(Cuenta cuenta, {String? vehiculoId}) =>
      api.crearCredencial(
        vehiculoId ?? auto.vehiculoId,
        identificador: 'qr-${++consecutivo}-ZZ99',
        tipo: 'qr',
        usuarioId: cuenta.id,
        semilla: 'SEMILLA-SECRETA',
      );

  Future<Respuesta> reportar(Cuenta cuenta, String id) =>
      api.post('/credenciales/$id/reportar-perdida', token: cuenta.token);

  setUpAll(() async {
    api = await ServidorPruebas.levantar();
    admin = await api.crearCuenta(rol: Rol.admin);
    titular = await api.crearCuenta();
    autorizado = await api.crearCuenta();
    otro = await api.crearCuenta();
    auto = await api.darDeAlta(titular, aprobadaPor: admin);
    await api.autorizar(auto.vehiculoId, autorizado.id);
  });
  tearDownAll(() => api.cerrar());

  test('el titular reporta un tag: queda perdida y en auditoría', () async {
    final tag = await crearTag();

    final respuesta = await reportar(titular, tag);

    expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
    expect(objeto(respuesta)['credencial'], {
      'id': tag,
      'tipo': 'tag_propio',
      'estado': 'perdida',
      'terminacion': '${1000 + consecutivo}',
      'vigencia': null,
    });
    expect(await api.leer('credenciales', 'estado', tag), 'perdida');

    final renglon = (await api.auditoriaDe(tag)).single;
    expect(renglon.actor, titular.id);
    expect(renglon.accion, 'credencial.reportar_perdida');
    expect(renglon.entidad, 'credenciales');
    expect(renglon.antes, {'estado': 'activa'});
    expect(renglon.despues, {'estado': 'perdida'});
  });

  test('reportarla otra vez → 409 CREDENCIAL_NO_ACTIVA', () async {
    final tag = await crearTag();
    expect((await reportar(titular, tag)).estado, HttpStatus.ok);

    _esperarError(
      await reportar(titular, tag),
      HttpStatus.conflict,
      'CREDENCIAL_NO_ACTIVA',
    );
    expect(await api.auditoriaDe(tag), hasLength(1));
  });

  test('una credencial revocada o vencida → 409 y no cambia', () async {
    for (final estado in ['revocada', 'vencida']) {
      final tag = await crearTag(estado: estado);

      _esperarError(
        await reportar(titular, tag),
        HttpStatus.conflict,
        'CREDENCIAL_NO_ACTIVA',
      );
      expect(await api.leer('credenciales', 'estado', tag), estado);
    }
  });

  test('el dueño de un QR lo reporta aunque no sea titular', () async {
    final qr = await crearQr(autorizado);

    final respuesta = await reportar(autorizado, qr);

    expect(respuesta.estado, HttpStatus.ok, reason: '${respuesta.json}');
    expect(await api.leer('credenciales', 'estado', qr), 'perdida');
    expect((await api.auditoriaDe(qr)).single.actor, autorizado.id);
  });

  test('el titular reporta el QR de un usuario autorizado', () async {
    final qr = await crearQr(autorizado);

    expect((await reportar(titular, qr)).estado, HttpStatus.ok);
    expect(await api.leer('credenciales', 'estado', qr), 'perdida');
  });

  test(
    'un usuario autorizado no reporta el tag ni el QR de otro → 403',
    () async {
      final tag = await crearTag();
      final qrTitular = await crearQr(titular);

      for (final id in [tag, qrTitular]) {
        _esperarError(
          await reportar(autorizado, id),
          HttpStatus.forbidden,
          'SOLO_TITULAR',
        );
        expect(await api.leer('credenciales', 'estado', id), 'activa');
        expect(await api.auditoriaDe(id), isEmpty);
      }
      // Solo cabe un QR activo por usuario y vehículo: se libera para las
      // pruebas que siguen.
      expect((await reportar(titular, qrTitular)).estado, HttpStatus.ok);
    },
  );

  test('un usuario ajeno → 404, igual que si no existiera', () async {
    final tag = await crearTag();

    final ajena = await reportar(otro, tag);
    final inexistente = await reportar(otro, idInexistente);

    _esperarError(ajena, HttpStatus.notFound, 'CREDENCIAL_NO_ENCONTRADA');
    expect(ajena.json, inexistente.json);
    _esperarError(
      await reportar(otro, 'no-es-uuid'),
      HttpStatus.notFound,
      'CREDENCIAL_NO_ENCONTRADA',
    );
    // Ni un admin por esta ruta: no es titular (su vía es el panel web).
    _esperarError(
      await reportar(admin, tag),
      HttpStatus.notFound,
      'CREDENCIAL_NO_ENCONTRADA',
    );
    expect(await api.leer('credenciales', 'estado', tag), 'activa');
  });

  test('la respuesta no trae la semilla ni el identificador', () async {
    final qr = await crearQr(titular);

    final respuesta = await reportar(titular, qr);

    expect(respuesta.estado, HttpStatus.ok);
    expect(
      (objeto(respuesta)['credencial'] as Map<String, dynamic>).keys,
      ['id', 'tipo', 'estado', 'terminacion', 'vigencia'],
    );
  });

  test('sin token → 401; GET → 405', () async {
    final tag = await crearTag();

    _esperarError(
      await api.post('/credenciales/$tag/reportar-perdida'),
      HttpStatus.unauthorized,
      'NO_AUTENTICADO',
    );
    _esperarError(
      await api.get(
        '/credenciales/$tag/reportar-perdida',
        token: titular.token,
      ),
      HttpStatus.methodNotAllowed,
      'METODO_NO_PERMITIDO',
    );
  });
}
