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
import '../viewmodel/login_viewmodel.dart';
import '../viewmodel/validacion_auth.dart';
import 'widgets/marca.dart';

/// Inicio de sesión.
class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enviar() {
    _formulario.currentState?.validate();
    ref
        .read(loginProvider.notifier)
        .iniciarSesion(correo: _correo.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(loginProvider);
    final vm = ref.read(loginProvider.notifier);
    final tema = Theme.of(context);
    final error = estado.error;
    return Scaffold(
      body: Form(
        key: _formulario,
        child: AutofillGroup(
          child: LienzoFormulario(
            hijos: [
              const SizedBox(height: Medidas.espacioLg),
              const MarcaParkEscom(),
              const SizedBox(height: Medidas.espacioXl),
              Text('Inicia sesión', style: tema.textTheme.titleLarge),
              const SizedBox(height: Medidas.espacioMd),
              if (error != null) ...[
                Aviso(
                  tipo: TipoAviso.error,
                  mensaje: error.mensaje(ContextoError.inicioSesion),
                ),
                const SizedBox(height: Medidas.espacioMd),
              ],
              CampoTexto(
                etiqueta: 'Correo institucional',
                controlador: _correo,
                icono: Icons.alternate_email,
                teclado: TextInputType.emailAddress,
                accionTeclado: TextInputAction.next,
                autocompletar: const [AutofillHints.username],
                habilitado: !estado.enviando,
                validador: (valor) =>
                    mensajeDeCampo(codigoCorreoAcceso(valor ?? '')),
                errorExterno: mensajeDeCampo(
                  estado.erroresCampos[CampoLogin.correo],
                ),
                alCambiar: (_) => vm.limpiarErrorCampo(CampoLogin.correo),
              ),
              const SizedBox(height: Medidas.espacioMd),
              CampoPassword(
                etiqueta: 'Contraseña',
                controlador: _password,
                accionTeclado: TextInputAction.done,
                habilitado: !estado.enviando,
                validador: (valor) =>
                    mensajeDeCampo(codigoPasswordAcceso(valor ?? '')),
                errorExterno: mensajeDeCampo(
                  estado.erroresCampos[CampoLogin.password],
                ),
                alCambiar: (_) => vm.limpiarErrorCampo(CampoLogin.password),
                alEnviar: (_) => _enviar(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: estado.enviando
                      ? null
                      : () => context.go(Rutas.recuperar),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              const SizedBox(height: Medidas.espacioSm),
              FilledButton(
                onPressed: estado.enviando ? null : _enviar,
                child: estado.enviando
                    ? const ProgresoBoton()
                    : const Text('Iniciar sesión'),
              ),
              const SizedBox(height: Medidas.espacioLg),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '¿No tienes una cuenta?',
                    style: tema.textTheme.bodyLarge?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: estado.enviando
                        ? null
                        : () => context.go(Rutas.registro),
                    child: const Text('Crear cuenta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
