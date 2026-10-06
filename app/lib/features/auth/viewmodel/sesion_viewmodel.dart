import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errores/excepcion_api.dart';
import '../../../core/red/cliente_api.dart';
import '../../../data/modelos/usuario.dart';
import '../../../data/repositories/auth_repository.dart';

/// Estado de la sesión en el dispositivo.
sealed class EstadoSesion {
  const EstadoSesion();
}

/// Se está comprobando si hay una sesión guardada.
class SesionVerificando extends EstadoSesion {
  const SesionVerificando();
}

/// Hay tokens guardados, pero no se pudo comprobar la sesión (sin red). La
/// sesión se conserva y se puede reintentar.
class SesionSinVerificar extends EstadoSesion {
  const SesionSinVerificar(this.error);

  final ExcepcionApi error;
}

/// No hay sesión.
class SinSesion extends EstadoSesion {
  const SinSesion();
}

/// Sesión abierta.
class ConSesion extends EstadoSesion {
  const ConSesion(this.usuario);

  final Usuario usuario;
}

/// Sesión de la app. El router la escucha para decidir a dónde va cada rol.
class SesionViewModel extends Notifier<EstadoSesion> {
  // Cada cambio de sesión invalida las comprobaciones que sigan en camino.
  int _version = 0;

  @override
  EstadoSesion build() {
    final aviso = ref.watch(avisoSesionExpiradaProvider);
    aviso.escuchar(_expirar);
    ref.onDispose(aviso.dejarDeEscuchar);
    final version = ++_version;
    unawaited(Future.microtask(() => _comprobar(version)));
    return const SesionVerificando();
  }

  /// Vuelve a comprobar la sesión guardada (botón "Reintentar" del arranque).
  Future<void> verificar() {
    state = const SesionVerificando();
    return _comprobar(++_version);
  }

  /// Deja la sesión abierta con [usuario] (tras iniciar sesión o registrarse)
  /// o actualiza sus datos.
  void establecer(Usuario usuario) {
    _version++;
    state = ConSesion(usuario);
  }

  /// Cierra la sesión en la API y en el dispositivo.
  Future<void> cerrarSesion() async {
    _version++;
    await ref.read(authRepositoryProvider).cerrarSesion();
    if (!ref.mounted) return;
    state = const SinSesion();
  }

  void _expirar() {
    _version++;
    state = const SinSesion();
  }

  Future<void> _comprobar(int version) async {
    if (version != _version || !ref.mounted) return;
    EstadoSesion nuevo;
    try {
      final usuario = await ref.read(authRepositoryProvider).restaurarSesion();
      nuevo = usuario == null ? const SinSesion() : ConSesion(usuario);
    } on ExcepcionApi catch (error) {
      nuevo = SesionSinVerificar(error);
    }
    if (version != _version || !ref.mounted) return;
    state = nuevo;
  }
}

final sesionProvider = NotifierProvider<SesionViewModel, EstadoSesion>(
  SesionViewModel.new,
);
