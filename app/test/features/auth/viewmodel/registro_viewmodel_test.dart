import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/data/modelos/foto.dart';
import 'package:parkescom/features/auth/viewmodel/registro_viewmodel.dart';
import 'package:parkescom/features/auth/viewmodel/sesion_viewmodel.dart';

import '../../../apoyo/falsos.dart';

void main() {
  late Falsos falsos;
  late ProviderContainer contenedor;

  setUp(() {
    falsos = Falsos();
    contenedor = ProviderContainer.test(overrides: falsos.overrides);
    contenedor.listen(registroProvider, (_, _) {});
  });

  RegistroViewModel vm() => contenedor.read(registroProvider.notifier);
  EstadoRegistro estado() => contenedor.read(registroProvider);

  Future<void> elegirFotos() async {
    await vm().elegirFoto(TipoFotoRegistro.titular, OrigenFoto.camara);
    await vm().elegirFoto(TipoFotoRegistro.credencial, OrigenFoto.galeria);
  }

  Future<void> registrar({
    String correo = 'ana@alumno.ipn.mx',
    String password = 'secreta123',
    bool aceptoAviso = true,
  }) => vm().registrar(
    nombre: 'Ana Prueba',
    correo: correo,
    boletaOEmpleado: '2024630001',
    password: password,
    aceptoAviso: aceptoAviso,
  );

  test('éxito: registra, sube las dos fotos y las asigna al perfil', () async {
    await elegirFotos();
    await registrar();

    expect(falsos.auth.registros, 1);
    expect(falsos.fotos.subidas, [
      PropositoFoto.perfil,
      PropositoFoto.credencialEscolar,
    ]);
    expect(falsos.perfil.asignaciones, hasLength(1));
    expect(estado().etapa, EtapaRegistro.completo);
    expect(estado().enviando, isFalse);
    final sesion = contenedor.read(sesionProvider) as ConSesion;
    expect(sesion.usuario.faltanFotos, isFalse);
  });

  test('validación: sin fotos, sin aviso y con datos inválidos no se '
      'registra', () async {
    await vm().registrar(
      nombre: ' ',
      correo: 'ana@gmail.com',
      boletaOEmpleado: '12',
      // 8 caracteres, pero sin número.
      password: 'sololetras',
      aceptoAviso: false,
    );

    expect(estado().erroresCampos, {
      CampoRegistro.nombre: 'NOMBRE_VACIO',
      CampoRegistro.correo: 'DOMINIO_NO_PERMITIDO',
      CampoRegistro.boletaOEmpleado: 'BOLETA_O_EMPLEADO_INVALIDO',
      CampoRegistro.password: 'PASSWORD_SIN_NUMERO',
      CampoRegistro.fotoTitular: CodigoError.fotoRequerida,
      CampoRegistro.fotoCredencial: CodigoError.fotoRequerida,
      CampoRegistro.aviso: CodigoError.avisoRequerido,
    });
    expect(estado().etapa, EtapaRegistro.datos);
    expect(falsos.auth.registros, 0);
  });

  test('validación: la contraseña no puede pasar de 72 bytes', () async {
    await elegirFotos();
    // 37 letras con acento son 74 bytes en UTF-8, aunque sean 38 caracteres.
    await registrar(password: '${'á' * 37}1');

    expect(estado().erroresCampos, {
      CampoRegistro.password: 'PASSWORD_MUY_LARGA',
    });
    expect(falsos.auth.registros, 0);
  });

  test('correo ya registrado: el error va al campo y no hay cuenta', () async {
    falsos.auth.errorRegistro = const ExcepcionApi(
      CodigoError.correoYaRegistrado,
      estadoHttp: 409,
    );
    await elegirFotos();
    await registrar();

    expect(estado().etapa, EtapaRegistro.datos);
    expect(estado().erroresCampos, {
      CampoRegistro.correo: CodigoError.correoYaRegistrado,
    });
    expect(falsos.fotos.subidas, isEmpty);
    expect(contenedor.read(sesionProvider), isNot(isA<ConSesion>()));
  });

  test('red caída al registrar: no hay cuenta y se puede reintentar', () async {
    falsos.auth.errorRegistro = const ExcepcionApi(CodigoError.sinConexion);
    await elegirFotos();
    await registrar();

    expect(estado().error?.esDeRed, isTrue);
    expect(estado().etapa, EtapaRegistro.datos);

    falsos.auth.errorRegistro = null;
    await registrar();
    expect(estado().etapa, EtapaRegistro.completo);
    expect(falsos.auth.registros, 2);
  });

  test('falla una subida: conserva la sesión y el reintento sube solo la '
      'foto que faltó, sin volver a registrar', () async {
    falsos.fotos.respuestas[PropositoFoto.credencialEscolar] = [
      const ExcepcionApi(CodigoError.archivoMuyGrande, estadoHttp: 413),
    ];
    await elegirFotos();
    await registrar();

    // La cuenta existe y la sesión está abierta, pero falta una foto.
    expect(estado().etapa, EtapaRegistro.fotos);
    expect(estado().enviando, isFalse);
    expect(estado().titularSubida, isTrue);
    expect(estado().credencialSubida, isFalse);
    expect(estado().errorFotoCredencial?.codigo, CodigoError.archivoMuyGrande);
    expect(estado().errorFotoTitular, isNull);
    expect(contenedor.read(sesionProvider), isA<ConSesion>());
    expect(falsos.perfil.asignaciones, isEmpty);

    await vm().reintentar();

    expect(falsos.auth.registros, 1);
    expect(falsos.fotos.subidas, [
      PropositoFoto.perfil,
      PropositoFoto.credencialEscolar,
      PropositoFoto.credencialEscolar,
    ]);
    expect(falsos.perfil.asignaciones, hasLength(1));
    expect(estado().etapa, EtapaRegistro.completo);
    expect(estado().errorFotoCredencial, isNull);
  });

  test('fallan las dos subidas: cada foto muestra su propio error', () async {
    falsos.fotos.respuestas
      ..[PropositoFoto.perfil] = [
        const ExcepcionApi(CodigoError.archivoInvalido, estadoHttp: 415),
      ]
      ..[PropositoFoto.credencialEscolar] = [
        const ExcepcionApi(CodigoError.archivoMuyGrande, estadoHttp: 413),
      ];
    await elegirFotos();
    await registrar();

    expect(estado().errorFotoTitular?.codigo, CodigoError.archivoInvalido);
    expect(estado().errorFotoCredencial?.codigo, CodigoError.archivoMuyGrande);
    expect(
      estado().errorFotoTitular!.mensaje(),
      isNot(estado().errorFotoCredencial!.mensaje()),
    );
  });

  test('falla asignar las fotos: el reintento no vuelve a subirlas', () async {
    falsos.perfil.errores.add(const ExcepcionApi(CodigoError.sinConexion));
    await elegirFotos();
    await registrar();

    expect(estado().etapa, EtapaRegistro.fotos);
    expect(estado().error?.esDeRed, isTrue);
    expect(estado().titularSubida, isTrue);
    expect(estado().credencialSubida, isTrue);

    await vm().reintentar();

    expect(falsos.auth.registros, 1);
    expect(falsos.fotos.subidas, hasLength(2));
    expect(falsos.perfil.asignaciones, hasLength(2));
    expect(estado().etapa, EtapaRegistro.completo);
  });

  test('cambiar una foto ya subida la vuelve a subir', () async {
    falsos.perfil.errores.add(const ExcepcionApi(CodigoError.sinConexion));
    await elegirFotos();
    await registrar();

    await vm().elegirFoto(TipoFotoRegistro.titular, OrigenFoto.galeria);
    expect(estado().titularSubida, isFalse);
    await vm().reintentar();

    expect(falsos.fotos.subidas, [
      PropositoFoto.perfil,
      PropositoFoto.credencialEscolar,
      PropositoFoto.perfil,
    ]);
    expect(estado().etapa, EtapaRegistro.completo);
  });

  test('con sesión abierta y sin fotos: empieza en el paso de fotos', () async {
    falsos.auth.sesionGuardada = usuarioDePrueba();
    final otro = ProviderContainer.test(overrides: falsos.overrides);
    otro.read(sesionProvider);
    await pumpEventQueue();
    otro.listen(registroProvider, (_, _) {});

    expect(otro.read(registroProvider).etapa, EtapaRegistro.fotos);

    // Sin fotos elegidas, el reintento pide las dos y no sube nada.
    await otro.read(registroProvider.notifier).reintentar();
    expect(otro.read(registroProvider).erroresCampos, {
      CampoRegistro.fotoTitular: CodigoError.fotoRequerida,
      CampoRegistro.fotoCredencial: CodigoError.fotoRequerida,
    });
    expect(falsos.fotos.subidas, isEmpty);
    expect(falsos.auth.registros, 0);
  });

  test('no se pudo abrir la cámara: el error queda en esa foto', () async {
    falsos.fotos.errorElegir = const ExcepcionApi(CodigoError.fotoNoDisponible);

    await vm().elegirFoto(TipoFotoRegistro.titular, OrigenFoto.camara);

    expect(estado().errorFotoTitular?.codigo, CodigoError.fotoNoDisponible);
    expect(estado().fotoTitular, isNull);
  });
}
