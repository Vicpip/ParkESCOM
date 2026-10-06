import 'package:flutter/material.dart';

import '../theme/medidas.dart';

/// Bloque gris que pulsa mientras llega el contenido real.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.ancho,
    this.alto = Medidas.lineaSkeleton,
    this.radio = Medidas.radioChico,
  });

  /// `null` ocupa todo el ancho disponible.
  final double? ancho;
  final double alto;
  final double radio;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sin animación si el usuario pidió reducir el movimiento.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulso.stop();
    } else if (!_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.45).animate(_pulso),
      child: Container(
        width: widget.ancho,
        height: widget.alto,
        decoration: BoxDecoration(
          color: esquema.outlineVariant,
          borderRadius: BorderRadius.circular(widget.radio),
        ),
      ),
    );
  }
}

/// Lista de tarjetas en carga: un cuadro y dos líneas por elemento.
class SkeletonLista extends StatelessWidget {
  const SkeletonLista({super.key, this.elementos = 3});

  final int elementos;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: ExcludeSemantics(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Medidas.espacioMd),
          itemCount: elementos,
          separatorBuilder: (_, _) => const SizedBox(height: Medidas.espacioMd),
          itemBuilder: (_, _) => const Card(
            child: Padding(
              padding: EdgeInsets.all(Medidas.espacioMd),
              child: Row(
                children: [
                  Skeleton(
                    ancho: Medidas.altoBoton,
                    alto: Medidas.altoBoton,
                    radio: Medidas.radio,
                  ),
                  SizedBox(width: Medidas.espacioMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(),
                        SizedBox(height: Medidas.espacioSm),
                        FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Skeleton(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
