import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/data/modelos/foto.dart';
import 'package:parkescom/data/modelos/usuario.dart';
import 'package:parkescom/data/repositories/auth_repository.dart';
import 'package:parkescom/data/repositories/fotos_repository.dart';
import 'package:parkescom/data/repositories/perfil_repository.dart';

/// Usuario de prueba; por omisión, pendiente y sin fotos (recién registrado).
Usuario usuarioDePrueba({
  Rol rol = Rol.usuario,
  EstadoCuenta estado = EstadoCuenta.pendiente,
  String? fotoTitularId,
  String? fotoCredencialId,
}) => Usuario(
  id: '11111111-1111-4111-8111-111111111111',
  nombre: 'Ana Prueba',
  correo: 'ana@alumno.ipn.mx',
  boletaOEmpleado: '2024630001',
  rol: rol,
  estado: estado,
  fotoTitularId: fotoTitularId,
  fotoCredencialId: fotoCredencialId,
);

/// Usuario activo y con sus dos fotos.
Usuario usuarioCompleto({Rol rol = Rol.usuario}) => usuarioDePrueba(
  rol: rol,
  estado: EstadoCuenta.activo,
  fotoTitularId: 'foto-titular',
  fotoCredencialId: 'foto-credencial',
);

/// PNG transparente de 1 x 1, para que la miniatura se pueda dibujar.
const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

Foto fotoDePrueba() => Foto(Uint8List.fromList(_png));

/// Repositorio de autenticación falso: cada operación devuelve lo
/// configurado o lanza el error configurado, y cuenta sus llamadas.
class AuthRepositoryFalso implements AuthRepository {
  /// Sesión guardada en el "dispositivo".
  Usuario? sesionGuardada;

  /// Si no es `null`, [restaurarSesion] espera a que se complete.
  Completer<void>? esperaRestaurar;

  ExcepcionApi? errorRestaurar;
  ExcepcionApi? errorLogin;
  ExcepcionApi? errorRegistro;
  ExcepcionApi? errorRecuperacion;

  Usuario usuarioLogin = usuarioCompleto();
  Usuario usuarioRegistro = usuarioDePrueba();

  int restauraciones = 0;
  int inicios = 0;
  int registros = 0;
  int cierres = 0;
  final correosRecuperacion = <String>[];
  String? ultimoCorreo;

  @override
  Future<Usuario?> restaurarSesion() async {
    restauraciones++;
    await esperaRestaurar?.future;
    final error = errorRestaurar;
    if (error != null) throw error;
    return sesionGuardada;
  }

  @override
  Future<Usuario> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    inicios++;
    ultimoCorreo = correo;
    final error = errorLogin;
    if (error != null) throw error;
    return sesionGuardada = usuarioLogin;
  }

  @override
  Future<Usuario> registrar({
    required String nombre,
    required String correo,
    required String boletaOEmpleado,
    required String password,
  }) async {
    registros++;
    ultimoCorreo = correo;
    final error = errorRegistro;
    if (error != null) throw error;
    return sesionGuardada = usuarioRegistro;
  }

  @override
  Future<void> cerrarSesion() async {
    cierres++;
    sesionGuardada = null;
  }

  @override
  Future<void> solicitarRecuperacion(String correo) async {
    correosRecuperacion.add(correo);
    final error = errorRecuperacion;
    if (error != null) throw error;
  }
}

/// Repositorio de fotos falso. Las subidas responden, en orden, con lo que
/// haya en [respuestas] para ese propósito: un id (`String`) o un error
/// ([ExcepcionApi]). Sin respuestas configuradas, la subida funciona.
class FotosRepositoryFalso implements FotosRepository {
  Foto? fotoElegida = fotoDePrueba();
  ExcepcionApi? errorElegir;

  final respuestas = <PropositoFoto, List<Object>>{};
  final subidas = <PropositoFoto>[];

  @override
  Future<Foto?> elegir(OrigenFoto origen) async {
    final error = errorElegir;
    if (error != null) throw error;
    return fotoElegida;
  }

  @override
  Future<String> subir(Foto foto, PropositoFoto proposito) async {
    subidas.add(proposito);
    final pendientes = respuestas[proposito];
    final respuesta = pendientes == null || pendientes.isEmpty
        ? 'id-${proposito.valor}-${subidas.length}'
        : pendientes.removeAt(0);
    if (respuesta is ExcepcionApi) throw respuesta;
    return respuesta as String;
  }
}

/// Repositorio de perfil falso: lanza los [errores] en orden y después
/// funciona.
class PerfilRepositoryFalso implements PerfilRepository {
  final errores = <ExcepcionApi>[];
  final asignaciones = <(String, String)>[];

  @override
  Future<Usuario> asignarFotos({
    required String fotoTitularId,
    required String fotoCredencialId,
  }) async {
    asignaciones.add((fotoTitularId, fotoCredencialId));
    if (errores.isNotEmpty) throw errores.removeAt(0);
    return usuarioDePrueba(
      fotoTitularId: fotoTitularId,
      fotoCredencialId: fotoCredencialId,
    );
  }
}

/// Los tres repositorios falsos y los overrides para inyectarlos.
class Falsos {
  final auth = AuthRepositoryFalso();
  final fotos = FotosRepositoryFalso();
  final perfil = PerfilRepositoryFalso();

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    fotosRepositoryProvider.overrideWithValue(fotos),
    perfilRepositoryProvider.overrideWithValue(perfil),
  ];
}
