import '../../data/modelos/usuario.dart';
import '../../features/auth/viewmodel/sesion_viewmodel.dart';

/// Rutas de la app.
abstract final class Rutas {
  /// Arranque: se comprueba la sesión.
  static const arranque = '/';

  static const login = '/login';

  // Registro y recuperación cuelgan del inicio de sesión para que "atrás"
  // regrese a él.
  static const registro = '/login/registro';
  static const recuperar = '/login/recuperar';

  // Usuario.
  static const inicio = '/inicio';
  static const vehiculos = '/vehiculos';
  static const historial = '/historial';
  static const perfil = '/perfil';

  // Guardia y administración.
  static const caseta = '/caseta';
  static const admin = '/admin';
}

const _publicas = {Rutas.login, Rutas.registro, Rutas.recuperar};

const _porRol = {
  Rol.usuario: {Rutas.inicio, Rutas.vehiculos, Rutas.historial, Rutas.perfil},
  Rol.guardia: {Rutas.caseta},
  Rol.admin: {Rutas.admin},
};

/// Primera pantalla de cada rol.
String inicioDe(Rol rol) => switch (rol) {
  Rol.usuario => Rutas.inicio,
  Rol.guardia => Rutas.caseta,
  Rol.admin => Rutas.admin,
};

/// A dónde debe ir quien está en [ubicacion] con la sesión [sesion], o
/// `null` si puede quedarse.
String? redirigirPorSesion(EstadoSesion sesion, String ubicacion) {
  switch (sesion) {
    case SesionVerificando() || SesionSinVerificar():
      return ubicacion == Rutas.arranque ? null : Rutas.arranque;
    case SinSesion():
      return _publicas.contains(ubicacion) ? null : Rutas.login;
    case ConSesion(:final usuario):
      // Quien dejó el registro a medias puede volver a subir sus fotos.
      if (ubicacion == Rutas.registro && usuario.debeCompletarRegistro) {
        return null;
      }
      return _porRol[usuario.rol]!.contains(ubicacion)
          ? null
          : inicioDe(usuario.rol);
  }
}
