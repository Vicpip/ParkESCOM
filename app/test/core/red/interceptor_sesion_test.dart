import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/core/red/interceptor_sesion.dart';
import 'package:parkescom/data/modelos/sesion.dart';
import 'package:parkescom/data/sources/local/almacen_tokens.dart';

/// Servidor falso: responde según la ruta y el token de la petición.
class _Servidor implements HttpClientAdapter {
  /// Qué responde `POST /auth/refresh`.
  Future<ResponseBody> Function(RequestOptions) alRenovar = (_) async =>
      _json(200, {'access_token': 'acceso-2', 'refresh_token': 'refresh-2'});

  int renovaciones = 0;
  final refreshRecibidos = <Object?>[];

  /// Retiene la respuesta de `/lenta` cuando llega con el token viejo.
  final esperaLenta = Completer<void>();

  /// `ruta token` de cada petición que no es de renovación.
  final peticiones = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      renovaciones++;
      refreshRecibidos.add((options.data as Map)['refresh_token']);
      // La renovación tarda: los demás 401 llegan mientras sigue en curso.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return alRenovar(options);
    }
    final token = options.headers['Authorization'];
    peticiones.add('${options.path} $token');
    if (options.path == '/lenta' && token == 'Bearer acceso-1') {
      await esperaLenta.future;
    }
    if (options.path == '/auth/login') {
      return _json(401, {
        'error': {'code': 'CREDENCIALES_INVALIDAS', 'message': 'x'},
      });
    }
    if (token == 'Bearer acceso-2') return _json(200, {'ok': true});
    return _json(401, {
      'error': {'code': 'NO_AUTENTICADO', 'message': 'x'},
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int estado, Object cuerpo) => ResponseBody.fromString(
  jsonEncode(cuerpo),
  estado,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late _Servidor servidor;
  late AlmacenTokensMemoria almacen;
  late Dio dio;
  late int expiraciones;

  setUp(() {
    servidor = _Servidor();
    almacen = AlmacenTokensMemoria(
      const Tokens(acceso: 'acceso-1', refresh: 'refresh-1'),
    );
    expiraciones = 0;
    final opciones = BaseOptions(baseUrl: 'http://api.prueba');
    final sinSesion = Dio(opciones)..httpClientAdapter = servidor;
    dio = Dio(opciones)
      ..httpClientAdapter = servidor
      ..interceptors.add(
        InterceptorSesion(
          almacen: almacen,
          dioSinSesion: sinSesion,
          alExpirar: () => expiraciones++,
        ),
      );
  });

  test('varios 401 simultáneos disparan una sola renovación', () async {
    final respuestas = await Future.wait([
      for (var i = 0; i < 5; i++) dio.get<dynamic>('/dato/$i'),
    ]);

    expect(servidor.renovaciones, 1);
    expect(servidor.refreshRecibidos, ['refresh-1']);
    expect(
      respuestas.map((respuesta) => respuesta.statusCode),
      everyElement(200),
    );
    // Cada petición se hizo una vez con el token viejo y otra con el nuevo.
    expect(
      servidor.peticiones.where((p) => p.endsWith('Bearer acceso-1')),
      hasLength(5),
    );
    expect(
      servidor.peticiones.where((p) => p.endsWith('Bearer acceso-2')),
      hasLength(5),
    );
    final tokens = await almacen.leer();
    expect(tokens?.acceso, 'acceso-2');
    expect(tokens?.refresh, 'refresh-2');
    expect(expiraciones, 0);
  });

  test('un 401 que llega después de la renovación solo se repite', () async {
    // Sale con el token viejo y su 401 llega cuando la sesión ya se renovó.
    final lenta = dio.get<dynamic>('/lenta');
    await dio.get<dynamic>('/dato');
    expect(servidor.renovaciones, 1);

    servidor.esperaLenta.complete();
    final respuesta = await lenta;

    expect(respuesta.statusCode, 200);
    expect(servidor.renovaciones, 1);
    expect(servidor.refreshRecibidos, ['refresh-1']);
  });

  test('renovación fallida: limpia la sesión y avisa una sola vez', () async {
    servidor.alRenovar = (_) async => _json(401, {
      'error': {'code': 'REFRESH_INVALIDO', 'message': 'x'},
    });

    final resultados = await Future.wait([
      for (var i = 0; i < 3; i++)
        dio
            .get<dynamic>('/dato/$i')
            .then<Object>((respuesta) => respuesta)
            .catchError((Object error) => error),
    ]);

    expect(servidor.renovaciones, 1);
    expect(resultados, everyElement(isA<DioException>()));
    // A quien hizo la petición le llega el 401 original, ya tipado.
    final error = ExcepcionApi.deDio(resultados.first as DioException);
    expect(error.codigo, CodigoError.noAutenticado);
    expect(error.esDeSesion, isTrue);
    expect(await almacen.leer(), isNull);
    expect(expiraciones, 1);
  });

  test('sin red al renovar: la sesión se conserva', () async {
    servidor.alRenovar = (opciones) async => throw DioException.connectionError(
      requestOptions: opciones,
      reason: 'sin red',
    );

    Object? error;
    try {
      await dio.get<dynamic>('/dato');
    } on DioException catch (e) {
      error = e;
    }

    expect(ExcepcionApi.deDio(error! as DioException).esDeRed, isTrue);
    expect((await almacen.leer())?.refresh, 'refresh-1');
    expect(expiraciones, 0);
  });

  test('las rutas de acceso no llevan token ni disparan renovación', () async {
    Object? error;
    try {
      await dio.post<dynamic>(
        '/auth/login',
        data: {'correo': 'a@ipn.mx', 'password': 'x'},
      );
    } on DioException catch (e) {
      error = e;
    }

    expect(
      ExcepcionApi.deDio(error! as DioException).codigo,
      CodigoError.credencialesInvalidas,
    );
    expect(servidor.peticiones, ['/auth/login null']);
    expect(servidor.renovaciones, 0);
    expect((await almacen.leer())?.acceso, 'acceso-1');
  });

  test('sin tokens guardados: el 401 pasa tal cual', () async {
    await almacen.borrar();

    await expectLater(dio.get<dynamic>('/dato'), throwsA(isA<DioException>()));
    expect(servidor.renovaciones, 0);
    expect(expiraciones, 0);
  });

  test('un formulario multipart se puede repetir tras renovar', () async {
    final respuesta = await dio.post<dynamic>(
      '/archivos',
      data: FormData.fromMap({
        'proposito': 'perfil',
        'archivo': MultipartFile.fromBytes([1, 2, 3], filename: 'foto'),
      }),
    );

    expect(respuesta.statusCode, 200);
    expect(servidor.renovaciones, 1);
  });
}
