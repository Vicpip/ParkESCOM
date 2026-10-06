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

/// Parámetro con el que el arranque recuerda la ruta que se quería abrir.
const parametroOrigen = 'de';

/// A dónde debe ir quien está en [ubicacion] con la sesión [sesion], o
/// `null` si puede quedarse.
///
/// Mientras se comprueba la sesión todo pasa por el arranque, que guarda en
/// [parametroOrigen] la ruta pedida; [origen] es ese valor y, ya con la
/// sesión resuelta, se vuelve a esa ruta si el rol puede verla.
String? redirigirPorSesion(
  EstadoSesion sesion,
  String ubicacion, {
  String? origen,
}) {
  final enArranque = ubicacion == Rutas.arranque;
  switch (sesion) {
    case SesionVerificando() || SesionSinVerificar():
      if (enArranque) return null;
      return Uri(
        path: Rutas.arranque,
        queryParameters: {parametroOrigen: ubicacion},
      ).toString();
    case SinSesion():
      if (_publicas.contains(ubicacion)) return null;
      return enArranque && _publicas.contains(origen) ? origen : Rutas.login;
    case ConSesion(:final usuario):
      // Quien dejó el registro a medias puede volver a subir sus fotos.
      if (ubicacion == Rutas.registro && usuario.debeCompletarRegistro) {
        return null;
      }
      final permitidas = _porRol[usuario.rol]!;
      if (permitidas.contains(ubicacion)) return null;
      return enArranque && permitidas.contains(origen)
          ? origen
          : inicioDe(usuario.rol);
  }
}
