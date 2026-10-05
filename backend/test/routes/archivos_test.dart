@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:backend/archivos/almacen_archivos.dart';
import 'package:backend/auth/usuario.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import '../soporte/servidor_pruebas.dart';

/// PNG real de 1×1 px.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// Inicio de un JPEG (firma y cabecera JFIF) con relleno.
final _jpeg = [
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, //
  ...List.filled(64, 0x20),
  0xFF, 0xD9,
];

final _nombreGenerado = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png)$',
);

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
  late Cuenta dueno;
  late Cuenta otro;
  late Cuenta guardia;
  late Cuenta admin;

  /// Sube [contenido] como [cuenta] y devuelve el id del archivo.
  Future<String> subir(
    Cuenta cuenta, {
    String proposito = 'perfil',
    List<int>? contenido,
  }) async {
    final respuesta = await api.subir(
      contenido ?? _png,
      proposito: proposito,
      token: cuenta.token,
    );
    expect(respuesta.estado, HttpStatus.created, reason: '${respuesta.json}');
    return _objeto(respuesta)['id'] as String;
  }

  Future<Respuesta> descargar(String id, Cuenta cuenta) =>
      api.get('/archivos/$id', token: cuenta.token);

  Future<ResultRow> fila(String id) async {
    final filas = await api.pool.execute(
      Sql.named(
        'SELECT ruta, tipo_mime, tamano_bytes, dueno_id::text, '
        'proposito::text FROM archivos WHERE id = @id:uuid',
      ),
      parameters: {'id': id},
    );
    return filas.single;
  }

  List<String> enDisco(Directory carpeta) => carpeta.existsSync()
      ? carpeta
            .listSync()
            .map((e) => e.uri.pathSegments.lastWhere((s) => s.isNotEmpty))
            .toList()
      : [];

  setUpAll(() async {
    api = await ServidorPruebas.levantar();
    dueno = await api.crearCuenta();
    otro = await api.crearCuenta();
    guardia = await api.crearCuenta(rol: Rol.guardia);
    admin = await api.crearCuenta(rol: Rol.admin);
  });
  tearDownAll(() => api.cerrar());

  group('POST /archivos', () {
    test(
      'una imagen válida → 201 con id, archivo en disco y renglón',
      () async {
        final respuesta = await api.subir(_png, token: dueno.token);

        expect(
          respuesta.estado,
          HttpStatus.created,
          reason: '${respuesta.json}',
        );
        expect(_objeto(respuesta).keys, ['id']);
        final id = _objeto(respuesta)['id'] as String;

        final renglon = await fila(id);
        expect(renglon[0], '$id.png');
        expect(renglon[1], 'image/png');
        expect(renglon[2], _png.length);
        expect(renglon[3], dueno.id);
        expect(renglon[4], 'perfil');
        final enDisco = File(
          '${api.carpetaUploads.path}${Platform.pathSeparator}$id.png',
        );
        expect(enDisco.readAsBytesSync(), _png);
      },
    );

    test('el campo proposito puede ir antes o después del archivo', () async {
      final respuesta = await api.subir(
        _png,
        proposito: 'vehiculo',
        token: dueno.token,
        propositoPrimero: true,
      );
      expect(respuesta.estado, HttpStatus.created, reason: '${respuesta.json}');
      expect((await fila(_objeto(respuesta)['id'] as String))[4], 'vehiculo');
    });

    test(
      'el tipo sale del contenido: un JPEG declarado como PNG es JPEG',
      () async {
        final respuesta = await api.subir(
          _jpeg,
          token: dueno.token,
          nombre: 'engaño.png',
        );
        expect(respuesta.estado, HttpStatus.created);
        final id = _objeto(respuesta)['id'] as String;
        final renglon = await fila(id);
        expect(renglon[0], '$id.jpg');
        expect(renglon[1], 'image/jpeg');
      },
    );

    test('un .txt renombrado a .jpg → 415 ARCHIVO_INVALIDO', () async {
      final antes = enDisco(api.carpetaUploads).length;
      final respuesta = await api.subir(
        utf8.encode('Esto es un archivo de texto, no una imagen.\n'),
        token: dueno.token,
        nombre: 'foto.jpg',
        tipoDeclarado: 'image/jpeg',
      );

      _esperarError(
        respuesta,
        HttpStatus.unsupportedMediaType,
        'ARCHIVO_INVALIDO',
      );
      expect(enDisco(api.carpetaUploads), hasLength(antes));
    });

    test('un archivo vacío → 415 ARCHIVO_INVALIDO', () async {
      _esperarError(
        await api.subir(const [], token: dueno.token),
        HttpStatus.unsupportedMediaType,
        'ARCHIVO_INVALIDO',
      );
    });

    test('más de 2 MB → 413 ARCHIVO_MUY_GRANDE', () async {
      final antes = enDisco(api.carpetaUploads).length;
      // 3 MB: lo rechaza el Content-Length, sin leer el cuerpo.
      final grande = [..._png, ...List.filled(3 * 1024 * 1024, 0)];
      _esperarError(
        await api.subir(grande, token: dueno.token),
        HttpStatus.requestEntityTooLarge,
        'ARCHIVO_MUY_GRANDE',
      );

      // 2 MB y un byte: cabe en el margen del formulario, pero el archivo en
      // sí rebasa el límite.
      final apenas = [
        ..._png,
        ...List.filled(tamanoMaximoArchivo + 1 - _png.length, 0),
      ];
      _esperarError(
        await api.subir(apenas, token: dueno.token),
        HttpStatus.requestEntityTooLarge,
        'ARCHIVO_MUY_GRANDE',
      );
      expect(enDisco(api.carpetaUploads), hasLength(antes));
    });

    test('exactamente 2 MB sí se acepta', () async {
      final justo = [
        ..._png,
        ...List.filled(tamanoMaximoArchivo - _png.length, 0),
      ];
      final id = await subir(dueno, contenido: justo);
      expect((await fila(id))[2], tamanoMaximoArchivo);
    });

    test('sin token → 401 NO_AUTENTICADO', () async {
      _esperarError(
        await api.subir(_png),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
    });

    test('sin archivo o con un propósito desconocido → 422', () async {
      final sinProposito = await api.subir(
        _png,
        proposito: null,
        token: dueno.token,
      );
      _esperarError(
        sinProposito,
        HttpStatus.unprocessableEntity,
        'VALIDACION',
      );
      expect((_objeto(sinProposito)['error'] as Map)['campos'], {
        'proposito': 'PROPOSITO_INVALIDO',
      });

      final inventado = await api.subir(
        _png,
        proposito: 'selfie',
        token: dueno.token,
      );
      _esperarError(inventado, HttpStatus.unprocessableEntity, 'VALIDACION');
    });

    test('un cuerpo que no es multipart → 400 SOLICITUD_INVALIDA', () async {
      _esperarError(
        await api.pedir(
          'POST',
          '/archivos',
          token: dueno.token,
          cabeceras: {HttpHeaders.contentTypeHeader: 'application/json'},
          cuerpo: utf8.encode('{"archivo": "foto.png"}'),
        ),
        HttpStatus.badRequest,
        'SOLICITUD_INVALIDA',
      );
    });

    test('sin Content-Length (envío por trozos) → 411', () async {
      // `post` escribe el JSON sin anunciar su tamaño.
      _esperarError(
        await api.post('/archivos', cuerpo: {'a': 1}, token: dueno.token),
        HttpStatus.lengthRequired,
        'LONGITUD_REQUERIDA',
      );
    });
  });

  group('GET /archivos/{id}', () {
    late String fotoPerfil;
    late String fotoVehiculo;
    late String fotoCredencial;

    setUpAll(() async {
      fotoPerfil = await subir(dueno);
      fotoVehiculo = await subir(
        dueno,
        proposito: 'vehiculo',
        contenido: _jpeg,
      );
      fotoCredencial = await subir(dueno, proposito: 'credencial_escolar');
    });

    test('el dueño → 200 con el binario y las cabeceras', () async {
      final png = await descargar(fotoPerfil, dueno);
      expect(png.estado, HttpStatus.ok);
      expect(png.bytes, _png);
      expect(png.cabeceras.value('content-type'), 'image/png');
      expect(png.cabeceras.value('cache-control'), 'private, max-age=3600');
      expect(png.cabeceras.value('x-content-type-options'), 'nosniff');

      final jpeg = await descargar(fotoVehiculo, dueno);
      expect(jpeg.estado, HttpStatus.ok);
      expect(jpeg.bytes, _jpeg);
      expect(jpeg.cabeceras.value('content-type'), 'image/jpeg');

      expect((await descargar(fotoCredencial, dueno)).estado, HttpStatus.ok);
    });

    test('otro usuario → 403 SIN_PERMISO en cualquier propósito', () async {
      for (final id in [fotoPerfil, fotoVehiculo, fotoCredencial]) {
        _esperarError(
          await descargar(id, otro),
          HttpStatus.forbidden,
          'SIN_PERMISO',
        );
      }
    });

    test(
      'guardia ve la foto de un vehículo, pero no una credencial escolar',
      () async {
        final vehiculo = await descargar(fotoVehiculo, guardia);
        expect(vehiculo.estado, HttpStatus.ok);
        expect(vehiculo.bytes, _jpeg);
        expect((await descargar(fotoPerfil, guardia)).estado, HttpStatus.ok);

        _esperarError(
          await descargar(fotoCredencial, guardia),
          HttpStatus.forbidden,
          'SIN_PERMISO',
        );
      },
    );

    test('admin ve ambas', () async {
      expect((await descargar(fotoVehiculo, admin)).estado, HttpStatus.ok);
      final credencial = await descargar(fotoCredencial, admin);
      expect(credencial.estado, HttpStatus.ok);
      expect(credencial.bytes, _png);
    });

    test('sin token → 401', () async {
      _esperarError(
        await api.get('/archivos/$fotoPerfil'),
        HttpStatus.unauthorized,
        'NO_AUTENTICADO',
      );
    });

    test('un id que no existe o no es UUID → 404', () async {
      _esperarError(
        await descargar('00000000-0000-4000-8000-000000000000', dueno),
        HttpStatus.notFound,
        'ARCHIVO_NO_ENCONTRADO',
      );
      _esperarError(
        await descargar('no-es-un-uuid', dueno),
        HttpStatus.notFound,
        'ARCHIVO_NO_ENCONTRADO',
      );
    });
  });

  group('path traversal', () {
    /// Carpeta padre de `uploads`: nada debe escribirse ni leerse ahí.
    late Directory padre;
    late File secreto;

    setUpAll(() {
      padre = api.carpetaUploads.parent;
      secreto = File('${padre.path}${Platform.pathSeparator}secreto.png')
        ..writeAsBytesSync(_png);
    });

    test('el nombre del cliente se ignora: no se escribe fuera', () async {
      for (final nombre in [
        '../../fuera.png',
        r'..\..\fuera.png',
        '/etc/passwd',
        r'C:\Windows\fuera.png',
        '....//fuera.png',
        '%2e%2e%2ffuera.png',
      ]) {
        final respuesta = await api.subir(
          _png,
          token: dueno.token,
          nombre: nombre,
        );
        expect(respuesta.estado, HttpStatus.created, reason: nombre);
        final ruta = (await fila(_objeto(respuesta)['id'] as String))[0];
        expect(ruta, matches(_nombreGenerado), reason: nombre);
      }

      // En la carpeta padre siguen solo `uploads` y el archivo de la prueba.
      expect(enDisco(padre), unorderedEquals(['uploads', 'secreto.png']));
      expect(
        enDisco(api.carpetaUploads),
        everyElement(matches(_nombreGenerado)),
      );
    });

    test('un id con ../ no llega al disco → 404', () async {
      for (final id in [
        '..%2Fsecreto.png',
        '..%5Csecreto.png',
        '%2e%2e%2fsecreto.png',
        '..%252Fsecreto.png',
        'secreto.png',
      ]) {
        final respuesta = await descargar(id, admin);
        expect(respuesta.estado, HttpStatus.notFound, reason: id);
        expect(respuesta.bytes, isNot(_png), reason: id);
      }
      final conDiagonal = await api.get(
        '/archivos/../secreto.png',
        token: admin.token,
      );
      expect(conDiagonal.estado, HttpStatus.notFound);
    });

    test(
      'un renglón con una ruta que sale de la carpeta no se sirve',
      () async {
        for (final ruta in [
          '../secreto.png',
          r'..\secreto.png',
          secreto.absolute.path,
          'sub/../../secreto.png',
        ]) {
          final filas = await api.pool.execute(
            Sql.named(
              'INSERT INTO archivos '
              '(ruta, tipo_mime, tamano_bytes, dueno_id, proposito) '
              "VALUES (@ruta, 'image/png', @tamano, @dueno:uuid, 'perfil') "
              'RETURNING id::text',
            ),
            parameters: {
              'ruta': ruta,
              'tamano': _png.length,
              'dueno': dueno.id,
            },
          );
          final respuesta = await descargar(filas.single[0]! as String, dueno);
          _esperarError(
            respuesta,
            HttpStatus.notFound,
            'ARCHIVO_NO_ENCONTRADO',
          );
        }
      },
    );
  });
}
