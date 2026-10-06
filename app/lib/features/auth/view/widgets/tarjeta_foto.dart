import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/componentes/campo_texto.dart';
import '../../../../core/theme/colores.dart';
import '../../../../core/theme/medidas.dart';
import '../../../../data/modelos/foto.dart';

/// Tarjeta para elegir una foto obligatoria: miniatura, estado y botón.
class TarjetaFoto extends StatelessWidget {
  const TarjetaFoto({
    super.key,
    required this.titulo,
    required this.ayuda,
    required this.alElegir,
    this.foto,
    this.subida = false,
    this.error,
    this.habilitada = true,
  });

  final String titulo;
  final String ayuda;
  final Foto? foto;

  /// La foto ya está en el servidor.
  final bool subida;

  /// Mensaje de error de esta foto.
  final String? error;

  final bool habilitada;
  final ValueChanged<OrigenFoto> alElegir;

  Future<void> _elegir(BuildContext context) async {
    // En el navegador solo hay selector de archivos.
    if (kIsWeb) return alElegir(OrigenFoto.galeria);
    final origen = await showModalBottomSheet<OrigenFoto>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(OrigenFoto.camara),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(OrigenFoto.galeria),
            ),
          ],
        ),
      ),
    );
    if (origen != null) alElegir(origen);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final estados = ColoresEstado.de(context);
    final foto = this.foto;
    final error = this.error;
    final hayFoto = foto != null || subida;
    final marcador = Icon(
      subida ? Icons.image_outlined : Icons.add_a_photo_outlined,
      size: Medidas.iconoLg,
      color: esquema.primary,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Medidas.espacioMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Medidas.radio),
                  child: Container(
                    width: Medidas.miniaturaFoto,
                    height: Medidas.miniaturaFoto,
                    color: esquema.primaryContainer,
                    child: foto == null
                        ? marcador
                        : Image.memory(
                            foto.bytes,
                            fit: BoxFit.cover,
                            semanticLabel: titulo,
                            errorBuilder: (_, _, _) => marcador,
                          ),
                  ),
                ),
                const SizedBox(width: Medidas.espacioMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: tema.textTheme.titleSmall),
                      const SizedBox(height: Medidas.espacioXs),
                      Text(
                        ayuda,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                      if (subida) ...[
                        const SizedBox(height: Medidas.espacioXs),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: Medidas.iconoSm,
                              color: estados.exito,
                            ),
                            const SizedBox(width: Medidas.espacioXs),
                            Expanded(
                              child: Text(
                                'Foto subida',
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: estados.sobreContenedorExito,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Medidas.espacioSm),
            OutlinedButton.icon(
              onPressed: habilitada ? () => _elegir(context) : null,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(hayFoto ? 'Cambiar foto' : 'Agregar foto'),
            ),
            if (error != null) ...[
              const SizedBox(height: Medidas.espacioSm),
              MensajeErrorCampo(error),
            ],
          ],
        ),
      ),
    );
  }
}
