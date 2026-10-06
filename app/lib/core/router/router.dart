import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/view/login_view.dart';
import '../../features/auth/view/recuperar_view.dart';
import '../../features/auth/view/registro_view.dart';
import '../../features/auth/view/splash_view.dart';
import '../../features/auth/viewmodel/sesion_viewmodel.dart';
import '../../features/inicio/view/inicio_view.dart';
import '../../features/marcadores/view/marcador_view.dart';
import 'rutas.dart';
import 'shell_usuario.dart';

/// Router de la app: redirige según la sesión y el rol cada vez que cambian.
final routerProvider = Provider<GoRouter>((ref) {
  final cambios = ValueNotifier<int>(0);
  ref.listen(sesionProvider, (_, _) => cambios.value++);

  final router = GoRouter(
    initialLocation: Rutas.arranque,
    refreshListenable: cambios,
    redirect: (_, estado) =>
        redirigirPorSesion(ref.read(sesionProvider), estado.matchedLocation),
    errorBuilder: (_, _) => const MarcadorView(
      titulo: 'Página no encontrada',
      icono: Icons.search_off,
      descripcion: 'La dirección que abriste no existe.',
    ),
    routes: [
      GoRoute(path: Rutas.arranque, builder: (_, _) => const SplashView()),
      GoRoute(
        path: Rutas.login,
        builder: (_, _) => const LoginView(),
        routes: [
          GoRoute(path: 'registro', builder: (_, _) => const RegistroView()),
          GoRoute(path: 'recuperar', builder: (_, _) => const RecuperarView()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navegacion) => ShellUsuario(navegacion: navegacion),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.inicio,
                builder: (_, _) => const InicioView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.vehiculos,
                builder: (_, _) => const MarcadorView(
                  titulo: 'Vehículos',
                  icono: Icons.directions_car_outlined,
                  descripcion: 'Aquí verás tus vehículos.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.historial,
                builder: (_, _) => const MarcadorView(
                  titulo: 'Historial',
                  icono: Icons.history,
                  descripcion: 'Aquí verás tus entradas y salidas.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.perfil,
                builder: (_, _) => const MarcadorView(
                  titulo: 'Perfil',
                  icono: Icons.person_outline,
                  mostrarCuenta: true,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Rutas.caseta,
        builder: (_, _) => const MarcadorView(
          titulo: 'Caseta',
          icono: Icons.sensors,
          descripcion: 'Aquí estará el modo caseta.',
          mostrarCuenta: true,
        ),
      ),
      GoRoute(
        path: Rutas.admin,
        builder: (_, _) => const MarcadorView(
          titulo: 'Administración',
          icono: Icons.admin_panel_settings_outlined,
          descripcion: 'Aquí estará el panel de administración.',
          mostrarCuenta: true,
        ),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    cambios.dispose();
  });
  return router;
});
