import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../core/errores/excepcion_api.dart';
import '../../../data/repositories/auth_repository.dart';
import 'sesion_viewmodel.dart';
import 'validacion_auth.dart';

/// Nombres de los campos del inicio de sesión.
abstract final class CampoLogin {
  static const correo = 'correo';
  static const password = 'password';
}

/// Estado de la pantalla de inicio de sesión.
class EstadoLogin {
  const EstadoLogin({
    this.enviando = false,
    this.error,
    this.erroresCampos = const {},
  });

  final bool enviando;

  /// Error del último intento (credenciales, demasiados intentos, red).
  final ExcepcionApi? error;

  /// Código de error de cada campo que no pasó la validación local.
  final Map<String, String> erroresCampos;
}

class LoginViewModel extends Notifier<EstadoLogin> {
  @override
  EstadoLogin build() => const EstadoLogin();

  /// Inicia sesión. Si sale bien, la sesión queda abierta y el router lleva
  /// al usuario a su inicio.
  Future<void> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    if (state.enviando) return;
    final errores = {
      CampoLogin.correo: ?codigoCorreoAcceso(correo),
      CampoLogin.password: ?codigoPasswordAcceso(password),
    };
    if (errores.isNotEmpty) {
      state = EstadoLogin(erroresCampos: errores);
      return;
    }
    state = const EstadoLogin(enviando: true);
    try {
      final usuario = await ref
          .read(authRepositoryProvider)
          .iniciarSesion(correo: normalizarCorreo(correo), password: password);
      if (!ref.mounted) return;
      state = const EstadoLogin();
      ref.read(sesionProvider.notifier).establecer(usuario);
    } on ExcepcionApi catch (error) {
      if (!ref.mounted) return;
      state = EstadoLogin(error: error);
    }
  }

  /// El usuario corrigió [campo]: su error local ya no aplica.
  void limpiarErrorCampo(String campo) {
    if (!state.erroresCampos.containsKey(campo)) return;
    state = EstadoLogin(
      error: state.error,
      erroresCampos: {...state.erroresCampos}..remove(campo),
    );
  }
}

final loginProvider = NotifierProvider.autoDispose<LoginViewModel, EstadoLogin>(
  LoginViewModel.new,
);
