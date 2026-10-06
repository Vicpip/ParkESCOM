import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../core/errores/codigos_error.dart';
import '../../../core/errores/excepcion_api.dart';
import '../../../data/modelos/foto.dart';
import '../../../data/modelos/usuario.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/fotos_repository.dart';
import '../../../data/repositories/perfil_repository.dart';
import 'sesion_viewmodel.dart';
import 'validacion_auth.dart';

/// Nombres de los campos del registro. Los cuatro primeros son los de la
/// API; los demás solo existen en la app.
abstract final class CampoRegistro {
  static const nombre = 'nombre';
  static const correo = 'correo';
  static const boletaOEmpleado = 'boleta_o_empleado';
  static const password = 'password';
  static const fotoTitular = 'foto_titular';
  static const fotoCredencial = 'foto_credencial';
  static const aviso = 'aviso';
}

/// Las dos fotos que pide el registro.
enum TipoFotoRegistro { titular, credencial }

/// En qué parte del registro está el usuario.
enum EtapaRegistro {
  /// Aún no existe la cuenta: se capturan datos y fotos.
  datos,

  /// La cuenta ya existe y la sesión está abierta; falta subir o asignar las
  /// fotos. Desde aquí nunca se vuelve a registrar.
  fotos,

  /// Cuenta creada con sus dos fotos.
  completo,
}

const _sinCambio = Object();

/// Estado de la pantalla de registro.
class EstadoRegistro {
  const EstadoRegistro({
    this.etapa = EtapaRegistro.datos,
    this.enviando = false,
    this.fotoTitular,
    this.fotoCredencial,
    this.idTitular,
    this.idCredencial,
    this.erroresCampos = const {},
    this.error,
    this.errorFotoTitular,
    this.errorFotoCredencial,
  });

  final EtapaRegistro etapa;
  final bool enviando;

  /// Fotos elegidas en el dispositivo.
  final Foto? fotoTitular;
  final Foto? fotoCredencial;

  /// Ids de las fotos que ya se subieron; una foto con id no se vuelve a
  /// subir en un reintento.
  final String? idTitular;
  final String? idCredencial;

  /// Código de error de cada campo ([CampoRegistro]).
  final Map<String, String> erroresCampos;

  /// Error general: el del registro o el de asignar las fotos al perfil.
  final ExcepcionApi? error;

  /// Error al elegir o subir cada foto.
  final ExcepcionApi? errorFotoTitular;
  final ExcepcionApi? errorFotoCredencial;

  bool get titularSubida => idTitular != null;
  bool get credencialSubida => idCredencial != null;

  EstadoRegistro copyWith({
    EtapaRegistro? etapa,
    bool? enviando,
    Object? fotoTitular = _sinCambio,
    Object? fotoCredencial = _sinCambio,
    Object? idTitular = _sinCambio,
    Object? idCredencial = _sinCambio,
    Map<String, String>? erroresCampos,
    Object? error = _sinCambio,
    Object? errorFotoTitular = _sinCambio,
    Object? errorFotoCredencial = _sinCambio,
  }) => EstadoRegistro(
    etapa: etapa ?? this.etapa,
    enviando: enviando ?? this.enviando,
    fotoTitular: identical(fotoTitular, _sinCambio)
        ? this.fotoTitular
        : fotoTitular as Foto?,
    fotoCredencial: identical(fotoCredencial, _sinCambio)
        ? this.fotoCredencial
        : fotoCredencial as Foto?,
    idTitular: identical(idTitular, _sinCambio)
        ? this.idTitular
        : idTitular as String?,
    idCredencial: identical(idCredencial, _sinCambio)
        ? this.idCredencial
        : idCredencial as String?,
    erroresCampos: erroresCampos ?? this.erroresCampos,
    error: identical(error, _sinCambio) ? this.error : error as ExcepcionApi?,
    errorFotoTitular: identical(errorFotoTitular, _sinCambio)
        ? this.errorFotoTitular
        : errorFotoTitular as ExcepcionApi?,
    errorFotoCredencial: identical(errorFotoCredencial, _sinCambio)
        ? this.errorFotoCredencial
        : errorFotoCredencial as ExcepcionApi?,
  );
}

/// Registro en dos pasos: crear la cuenta y después subir las dos fotos y
/// asignarlas al perfil. Si el segundo paso falla, la cuenta ya existe: se
/// conserva la sesión y solo se reintenta lo que faltó.
class RegistroViewModel extends Notifier<EstadoRegistro> {
  @override
  EstadoRegistro build() {
    // Quien entra con la sesión abierta y sin fotos (cerró la app a medio
    // registro) continúa directo en el paso de las fotos.
    final sesion = ref.read(sesionProvider);
    if (sesion is ConSesion && sesion.usuario.debeCompletarRegistro) {
      return EstadoRegistro(
        etapa: EtapaRegistro.fotos,
        idTitular: sesion.usuario.fotoTitularId,
        idCredencial: sesion.usuario.fotoCredencialId,
      );
    }
    return const EstadoRegistro();
  }

  /// Abre la cámara o la galería para la foto [tipo].
  Future<void> elegirFoto(TipoFotoRegistro tipo, OrigenFoto origen) async {
    if (state.enviando) return;
    final esTitular = tipo == TipoFotoRegistro.titular;
    final campo = esTitular
        ? CampoRegistro.fotoTitular
        : CampoRegistro.fotoCredencial;
    try {
      final foto = await ref.read(fotosRepositoryProvider).elegir(origen);
      if (foto == null || !ref.mounted) return;
      final errores = {...state.erroresCampos}..remove(campo);
      // Una foto nueva reemplaza a la anterior, aunque ya se hubiera subido.
      state = esTitular
          ? state.copyWith(
              fotoTitular: foto,
              idTitular: null,
              errorFotoTitular: null,
              erroresCampos: errores,
            )
          : state.copyWith(
              fotoCredencial: foto,
              idCredencial: null,
              errorFotoCredencial: null,
              erroresCampos: errores,
            );
    } on ExcepcionApi catch (error) {
      if (!ref.mounted) return;
      state = esTitular
          ? state.copyWith(errorFotoTitular: error)
          : state.copyWith(errorFotoCredencial: error);
    }
  }

  /// Crea la cuenta y, enseguida, sube las fotos.
  Future<void> registrar({
    required String nombre,
    required String correo,
    required String boletaOEmpleado,
    required String password,
    required bool aceptoAviso,
  }) async {
    if (state.enviando || state.etapa != EtapaRegistro.datos) return;
    final errores = {
      CampoRegistro.nombre: ?codigoNombre(nombre),
      CampoRegistro.correo: ?codigoCorreoRegistro(correo),
      CampoRegistro.boletaOEmpleado: ?codigoBoletaOEmpleado(boletaOEmpleado),
      CampoRegistro.password: ?codigoPasswordNueva(password),
      if (state.fotoTitular == null)
        CampoRegistro.fotoTitular: CodigoError.fotoRequerida,
      if (state.fotoCredencial == null)
        CampoRegistro.fotoCredencial: CodigoError.fotoRequerida,
      if (!aceptoAviso) CampoRegistro.aviso: CodigoError.avisoRequerido,
    };
    if (errores.isNotEmpty) {
      state = state.copyWith(
        erroresCampos: errores,
        error: const ExcepcionApi(CodigoError.validacion),
      );
      return;
    }

    state = state.copyWith(enviando: true, erroresCampos: {}, error: null);
    final Usuario usuario;
    try {
      usuario = await ref
          .read(authRepositoryProvider)
          .registrar(
            nombre: nombre.trim(),
            correo: normalizarCorreo(correo),
            boletaOEmpleado: boletaOEmpleado.trim(),
            password: password,
          );
    } on ExcepcionApi catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        enviando: false,
        erroresCampos: _camposDe(error),
        error: error,
      );
      return;
    }
    if (!ref.mounted) return;

    // La cuenta ya existe: a partir de aquí solo quedan las fotos.
    state = state.copyWith(etapa: EtapaRegistro.fotos);
    ref.read(sesionProvider.notifier).establecer(usuario);
    await _subirFotos();
  }

  /// Reintenta lo que haya faltado: subir las fotos que no tienen id y
  /// asignarlas al perfil. Nunca vuelve a registrar.
  Future<void> reintentar() async {
    if (state.enviando || state.etapa != EtapaRegistro.fotos) return;
    await _subirFotos();
  }

  /// El usuario corrigió [campo]: su error ya no aplica.
  void limpiarErrorCampo(String campo) {
    if (!state.erroresCampos.containsKey(campo)) return;
    state = state.copyWith(
      erroresCampos: {...state.erroresCampos}..remove(campo),
    );
  }

  Future<void> _subirFotos() async {
    state = state.copyWith(
      enviando: true,
      erroresCampos: {},
      error: null,
      errorFotoTitular: null,
      errorFotoCredencial: null,
    );
    final fotos = ref.read(fotosRepositoryProvider);
    final faltantes = <String, String>{};

    // Se intentan las dos aunque falle la primera, para que el usuario vea
    // de una vez todo lo que debe corregir.
    var idTitular = state.idTitular;
    ExcepcionApi? errorTitular;
    if (idTitular == null) {
      final foto = state.fotoTitular;
      if (foto == null) {
        faltantes[CampoRegistro.fotoTitular] = CodigoError.fotoRequerida;
      } else {
        try {
          idTitular = await fotos.subir(foto, PropositoFoto.perfil);
        } on ExcepcionApi catch (error) {
          errorTitular = error;
        }
        if (!ref.mounted) return;
      }
    }

    var idCredencial = state.idCredencial;
    ExcepcionApi? errorCredencial;
    if (idCredencial == null) {
      final foto = state.fotoCredencial;
      if (foto == null) {
        faltantes[CampoRegistro.fotoCredencial] = CodigoError.fotoRequerida;
      } else {
        try {
          idCredencial = await fotos.subir(
            foto,
            PropositoFoto.credencialEscolar,
          );
        } on ExcepcionApi catch (error) {
          errorCredencial = error;
        }
        if (!ref.mounted) return;
      }
    }

    state = state.copyWith(
      idTitular: idTitular,
      idCredencial: idCredencial,
      errorFotoTitular: errorTitular,
      errorFotoCredencial: errorCredencial,
      erroresCampos: faltantes,
    );
    if (idTitular == null || idCredencial == null) {
      state = state.copyWith(enviando: false);
      return;
    }

    try {
      final usuario = await ref
          .read(perfilRepositoryProvider)
          .asignarFotos(
            fotoTitularId: idTitular,
            fotoCredencialId: idCredencial,
          );
      if (!ref.mounted) return;
      state = state.copyWith(enviando: false, etapa: EtapaRegistro.completo);
      ref.read(sesionProvider.notifier).establecer(usuario);
    } on ExcepcionApi catch (error) {
      if (!ref.mounted) return;
      // Si la API rechazó una foto ya subida, en el reintento se sube otra
      // vez.
      state = state.copyWith(
        enviando: false,
        error: error,
        idTitular: error.campos.containsKey('foto_titular_id')
            ? null
            : idTitular,
        idCredencial: error.campos.containsKey('foto_credencial_id')
            ? null
            : idCredencial,
      );
    }
  }

  /// Errores de la API que pertenecen a un campo del formulario.
  static Map<String, String> _camposDe(ExcepcionApi error) =>
      switch (error.codigo) {
        CodigoError.validacion => error.campos,
        CodigoError.correoYaRegistrado ||
        CodigoError.dominioNoPermitido => {CampoRegistro.correo: error.codigo},
        CodigoError.boletaYaRegistrada => {
          CampoRegistro.boletaOEmpleado: error.codigo,
        },
        _ => const {},
      };
}

final registroProvider =
    NotifierProvider.autoDispose<RegistroViewModel, EstadoRegistro>(
      RegistroViewModel.new,
    );
