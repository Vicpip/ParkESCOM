import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/componentes/cargando.dart';
import '../../../core/componentes/error_red.dart';
import '../../../core/theme/medidas.dart';
import '../viewmodel/sesion_viewmodel.dart';
import 'widgets/marca.dart';

/// Arranque: mientras se comprueba la sesión. El router redirige en cuanto
/// se sabe si hay sesión y con qué rol.
class SplashView extends ConsumerWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    return Scaffold(
      body: SafeArea(
        child: switch (sesion) {
          SesionSinVerificar(:final error) => ErrorRed(
            error: error,
            alReintentar: ref.read(sesionProvider.notifier).verificar,
          ),
          _ => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MarcaParkEscom(),
                SizedBox(height: Medidas.espacioXl),
                Cargando(),
              ],
            ),
          ),
        },
      ),
    );
  }
}
