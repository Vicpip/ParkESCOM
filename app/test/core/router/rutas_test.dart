import 'package:flutter_test/flutter_test.dart';
import 'package:parkescom/core/errores/codigos_error.dart';
import 'package:parkescom/core/errores/excepcion_api.dart';
import 'package:parkescom/core/router/rutas.dart';
import 'package:parkescom/data/modelos/usuario.dart';
import 'package:parkescom/features/auth/viewmodel/sesion_viewmodel.dart';

import '../../apoyo/falsos.dart';

void main() {
  test('mientras se comprueba la sesión todo va al arranque', () {
    const estados = [
      SesionVerificando(),
      SesionSinVerificar(ExcepcionApi(CodigoError.sinConexion)),
    ];
    for (final sesion in estados) {
      expect(redirigirPorSesion(sesion, Rutas.arranque), isNull);
      expect(redirigirPorSesion(sesion, Rutas.perfil), '/?de=%2Fperfil');
      expect(redirigirPorSesion(sesion, Rutas.login), '/?de=%2Flogin');
    }
  });

  test('sin sesión solo se ven las pantallas de acceso', () {
    const sesion = SinSesion();
    expect(redirigirPorSesion(sesion, Rutas.login), isNull);
    expect(redirigirPorSesion(sesion, Rutas.registro), isNull);
    expect(redirigirPorSesion(sesion, Rutas.recuperar), isNull);
    expect(redirigirPorSesion(sesion, Rutas.arranque), Rutas.login);
    expect(redirigirPorSesion(sesion, Rutas.perfil), Rutas.login);
    expect(redirigirPorSesion(sesion, Rutas.admin), Rutas.login);
  });

  test('cada rol entra a su inicio y no a las pantallas de otro', () {
    final usuario = ConSesion(usuarioCompleto());
    expect(redirigirPorSesion(usuario, Rutas.arranque), Rutas.inicio);
    expect(redirigirPorSesion(usuario, Rutas.login), Rutas.inicio);
    expect(redirigirPorSesion(usuario, Rutas.historial), isNull);
    expect(redirigirPorSesion(usuario, Rutas.caseta), Rutas.inicio);
    expect(redirigirPorSesion(usuario, Rutas.admin), Rutas.inicio);

    final guardia = ConSesion(usuarioCompleto(rol: Rol.guardia));
    expect(redirigirPorSesion(guardia, Rutas.arranque), Rutas.caseta);
    expect(redirigirPorSesion(guardia, Rutas.caseta), isNull);
    expect(redirigirPorSesion(guardia, Rutas.inicio), Rutas.caseta);
    expect(redirigirPorSesion(guardia, Rutas.admin), Rutas.caseta);

    final admin = ConSesion(usuarioCompleto(rol: Rol.admin));
    expect(redirigirPorSesion(admin, Rutas.arranque), Rutas.admin);
    expect(redirigirPorSesion(admin, Rutas.vehiculos), Rutas.admin);
  });

  test('el registro solo sigue abierto para quien no ha subido sus fotos', () {
    final sinFotos = ConSesion(usuarioDePrueba());
    expect(redirigirPorSesion(sinFotos, Rutas.registro), isNull);

    final conFotos = ConSesion(
      usuarioDePrueba(fotoTitularId: 'a', fotoCredencialId: 'b'),
    );
    expect(redirigirPorSesion(conFotos, Rutas.registro), Rutas.inicio);

    // Con la cuenta activa el perfil ya no se puede editar desde la app.
    final activoSinFotos = ConSesion(
      usuarioDePrueba(estado: EstadoCuenta.activo),
    );
    expect(redirigirPorSesion(activoSinFotos, Rutas.registro), Rutas.inicio);
  });

  test('tras comprobar la sesión se vuelve a la ruta que se pidió', () {
    final usuario = ConSesion(usuarioCompleto());
    expect(
      redirigirPorSesion(usuario, Rutas.arranque, origen: Rutas.perfil),
      Rutas.perfil,
    );
    // Una ruta de otro rol o desconocida no se respeta.
    expect(
      redirigirPorSesion(usuario, Rutas.arranque, origen: Rutas.admin),
      Rutas.inicio,
    );
    expect(
      redirigirPorSesion(usuario, Rutas.arranque, origen: 'https://x.mx'),
      Rutas.inicio,
    );

    const sinSesion = SinSesion();
    expect(
      redirigirPorSesion(sinSesion, Rutas.arranque, origen: Rutas.recuperar),
      Rutas.recuperar,
    );
    expect(
      redirigirPorSesion(sinSesion, Rutas.arranque, origen: Rutas.perfil),
      Rutas.login,
    );
  });
}
