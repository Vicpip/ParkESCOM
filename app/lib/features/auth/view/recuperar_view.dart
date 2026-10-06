import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/componentes/aviso.dart';
import '../../../core/componentes/campo_texto.dart';
import '../../../core/componentes/cargando.dart';
import '../../../core/componentes/lienzo_formulario.dart';
import '../../../core/errores/mensajes_error.dart';
import '../../../core/router/rutas.dart';
import '../../../core/theme/medidas.dart';
import '../viewmodel/recuperar_viewmodel.dart';
import '../viewmodel/validacion_auth.dart';

/// Recuperar contraseña: pide el correo con el enlace para restablecerla.
class RecuperarView extends ConsumerStatefulWidget {
  const RecuperarView({super.key});

  @override
  ConsumerState<RecuperarView> createState() => _RecuperarViewState();
}

class _RecuperarViewState extends ConsumerState<RecuperarView> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  void _enviar() {
    _formulario.currentState?.validate();
    ref.read(recuperarProvider.notifier).enviar(_correo.text);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(recuperarProvider);
    final vm = ref.read(recuperarProvider.notifier);
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final error = estado.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Form(
        key: _formulario,
        child: LienzoFormulario(
          hijos: [
            Center(
              child: Container(
                width: Medidas.circuloEstado,
                height: Medidas.circuloEstado,
                decoration: BoxDecoration(
                  color: esquema.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_reset,
                  size: Medidas.iconoLg,
                  color: esquema.primary,
                ),
              ),
            ),
            const SizedBox(height: Medidas.espacioMd),
            Text(
              '¿Olvidaste tu contraseña?',
              textAlign: TextAlign.center,
              style: tema.textTheme.headlineSmall,
            ),
            const SizedBox(height: Medidas.espacioSm),
            Text(
              'Escribe tu correo institucional y te enviaremos un enlace '
              'para crear una contraseña nueva.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Medidas.espacioLg),
            CampoTexto(
              etiqueta: 'Correo institucional',
              controlador: _correo,
              icono: Icons.alternate_email,
              teclado: TextInputType.emailAddress,
              accionTeclado: TextInputAction.done,
              autocompletar: const [AutofillHints.email],
              habilitado: !estado.enviando,
              validador: (valor) =>
                  mensajeDeCampo(codigoCorreoAcceso(valor ?? '')),
              errorExterno: mensajeDeCampo(estado.errorCorreo),
              alCambiar: (_) => vm.alCambiarCorreo(),
              alEnviar: (_) => _enviar(),
            ),
            const SizedBox(height: Medidas.espacioMd),
            FilledButton.icon(
              onPressed: estado.enviando ? null : _enviar,
              icon: estado.enviando
                  ? const ProgresoBoton()
                  : const Icon(Icons.send_outlined),
              label: const Text('Enviar enlace'),
            ),
            if (estado.enviado) ...[
              const SizedBox(height: Medidas.espacioMd),
              // El mismo texto exista o no la cuenta: no se revela cuál es.
              const Aviso(
                tipo: TipoAviso.exito,
                titulo: 'Revisa tu correo',
                mensaje:
                    'Si el correo está registrado, te enviamos un enlace '
                    'para restablecer tu contraseña. Revisa también el '
                    'correo no deseado. El enlace deja de funcionar a los '
                    '15 minutos.',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: Medidas.espacioMd),
              Aviso(
                tipo: TipoAviso.error,
                mensaje: error.mensaje(ContextoError.recuperacion),
              ),
            ],
            const SizedBox(height: Medidas.espacioMd),
            TextButton.icon(
              onPressed: () => context.go(Rutas.login),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver a iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
