import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../../core/errores/excepcion_api.dart';
import '../../../data/repositories/auth_repository.dart';
import 'validacion_auth.dart';

/// Estado de la pantalla de recuperación de contraseña.
class EstadoRecuperar {
  const EstadoRecuperar({
    this.enviando = false,
    this.enviado = false,
    this.error,
    this.errorCorreo,
  });

  final bool enviando;

  /// La API aceptó la solicitud. No dice si la cuenta existe.
  final bool enviado;

  final ExcepcionApi? error;

  /// Código de error del correo si no pasó la validación local.
  final String? errorCorreo;
}

class RecuperarViewModel extends Notifier<EstadoRecuperar> {
  @override
  EstadoRecuperar build() => const EstadoRecuperar();

  /// Pide el correo con el enlace para restablecer la contraseña.
  Future<void> enviar(String correo) async {
    if (state.enviando) return;
    final errorCorreo = codigoCorreoAcceso(correo);
    if (errorCorreo != null) {
      state = EstadoRecuperar(errorCorreo: errorCorreo);
      return;
    }
    state = const EstadoRecuperar(enviando: true);
    try {
      await ref
          .read(authRepositoryProvider)
          .solicitarRecuperacion(normalizarCorreo(correo));
      if (!ref.mounted) return;
      state = const EstadoRecuperar(enviado: true);
    } on ExcepcionApi catch (error) {
      if (!ref.mounted) return;
      state = EstadoRecuperar(error: error);
    }
  }

  /// El usuario cambió el correo: se quitan el error y el aviso de envío.
  void alCambiarCorreo() {
    if (state.enviando) return;
    if (state.enviado || state.error != null || state.errorCorreo != null) {
      state = const EstadoRecuperar();
    }
  }
}

final recuperarProvider =
    NotifierProvider.autoDispose<RecuperarViewModel, EstadoRecuperar>(
      RecuperarViewModel.new,
    );
