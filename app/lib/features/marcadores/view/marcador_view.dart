import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/componentes/estado_vacio.dart';
import '../../auth/viewmodel/sesion_viewmodel.dart';

/// Pantalla marcadora de una sección que todavía no se construye. Con
/// [mostrarCuenta] enseña de quién es la sesión y permite cerrarla.
class MarcadorView extends ConsumerWidget {
  const MarcadorView({
    super.key,
    required this.titulo,
    required this.icono,
    this.descripcion,
    this.mostrarCuenta = false,
  });

  final String titulo;
  final IconData icono;
  final String? descripcion;
  final bool mostrarCuenta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);
    final usuario = mostrarCuenta && sesion is ConSesion
        ? sesion.usuario
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: EstadoVacio(
        icono: icono,
        titulo: usuario?.nombre ?? titulo,
        descripcion: usuario?.correo ?? descripcion,
        accion: usuario == null
            ? null
            : OutlinedButton.icon(
                onPressed: ref.read(sesionProvider.notifier).cerrarSesion,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
      ),
    );
  }
}
