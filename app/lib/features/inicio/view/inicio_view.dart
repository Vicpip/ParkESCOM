import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/componentes/aviso.dart';
import '../../../core/componentes/estado_vacio.dart';
import '../../../core/componentes/lienzo_formulario.dart';
import '../../../core/router/rutas.dart';
import '../../../core/theme/medidas.dart';
import '../../auth/viewmodel/sesion_viewmodel.dart';

/// Inicio del usuario. Por ahora es un marcador: con la cuenta pendiente
/// explica que falta la activación; la credencial llega en una fase
/// posterior.
class InicioView extends ConsumerWidget {
  const InicioView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    final usuario = sesion is ConSesion ? sesion.usuario : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: usuario == null || !usuario.estaPendiente
          ? const EstadoVacio(
              icono: Icons.qr_code_2,
              titulo: 'Tu credencial',
              descripcion: 'Aquí verás tu credencial para entrar y salir.',
            )
          : LienzoFormulario(
              hijos: [
                const Aviso(
                  tipo: TipoAviso.advertencia,
                  titulo: 'Tu cuenta está en revisión',
                  mensaje:
                      'Administración debe activar tu cuenta. Mientras '
                      'tanto no puedes usar tu credencial en las puertas.',
                ),
                if (usuario.debeCompletarRegistro) ...[
                  const SizedBox(height: Medidas.espacioMd),
                  Aviso(
                    tipo: TipoAviso.informacion,
                    titulo: 'Te faltan fotos',
                    mensaje:
                        'Para que Administración pueda revisar tu registro, '
                        'sube tu foto y la de tu credencial.',
                    accion: FilledButton(
                      onPressed: () => context.go(Rutas.registro),
                      child: const Text('Completar registro'),
                    ),
                  ),
                ],
                const SizedBox(height: Medidas.espacioMd),
                OutlinedButton.icon(
                  onPressed: ref.read(sesionProvider.notifier).verificar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
    );
  }
}
