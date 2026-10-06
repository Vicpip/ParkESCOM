import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/componentes/aviso.dart';
import '../../../core/componentes/campo_texto.dart';
import '../../../core/componentes/cargando.dart';
import '../../../core/componentes/lienzo_formulario.dart';
import '../../../core/config/entorno.dart';
import '../../../core/errores/mensajes_error.dart';
import '../../../core/router/rutas.dart';
import '../../../core/theme/medidas.dart';
import '../viewmodel/registro_viewmodel.dart';
import '../viewmodel/validacion_auth.dart';
import 'widgets/aviso_privacidad.dart';
import 'widgets/tarjeta_foto.dart';

/// Registro: datos, foto del titular, foto de la credencial y aviso de
/// privacidad. Si la cuenta ya existe y faltan las fotos, solo muestra el
/// paso de las fotos.
class RegistroView extends ConsumerStatefulWidget {
  const RegistroView({super.key});

  @override
  ConsumerState<RegistroView> createState() => _RegistroViewState();
}

class _RegistroViewState extends ConsumerState<RegistroView> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _boleta = TextEditingController();
  final _password = TextEditingController();
  bool _aceptoAviso = false;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _boleta.dispose();
    _password.dispose();
    super.dispose();
  }

  void _registrar() {
    _formulario.currentState?.validate();
    ref
        .read(registroProvider.notifier)
        .registrar(
          nombre: _nombre.text,
          correo: _correo.text,
          boletaOEmpleado: _boleta.text,
          password: _password.text,
          aceptoAviso: _aceptoAviso,
        );
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(registroProvider);
    final enFotos = estado.etapa != EtapaRegistro.datos;
    return Scaffold(
      appBar: AppBar(
        title: Text(enFotos ? 'Completa tu registro' : 'Crear cuenta'),
      ),
      body: Form(
        key: _formulario,
        child: LienzoFormulario(
          hijos: enFotos ? _pasoFotos(estado) : _pasoDatos(estado),
        ),
      ),
    );
  }

  List<Widget> _pasoDatos(EstadoRegistro estado) {
    final vm = ref.read(registroProvider.notifier);
    final tema = Theme.of(context);
    final error = estado.error;
    final errorAviso = mensajeDeCampo(
      estado.erroresCampos[CampoRegistro.aviso],
    );
    String? externo(String campo) =>
        mensajeDeCampo(estado.erroresCampos[campo]);
    final dominios = Entorno.dominiosPermitidos
        .map((dominio) => '@$dominio')
        .join(' o ');

    return [
      Text(
        'Regístrate con tu correo institucional. Administración revisará '
        'tus datos y tu credencial antes de activar tu cuenta.',
        style: tema.textTheme.bodyLarge?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: Medidas.espacioLg),
      Text('Tus datos', style: tema.textTheme.titleMedium),
      const SizedBox(height: Medidas.espacioMd),
      CampoTexto(
        etiqueta: 'Nombre completo',
        controlador: _nombre,
        icono: Icons.person_outline,
        ayuda: 'Como aparece en tu credencial.',
        teclado: TextInputType.name,
        capitalizacion: TextCapitalization.words,
        accionTeclado: TextInputAction.next,
        autocompletar: const [AutofillHints.name],
        habilitado: !estado.enviando,
        validador: (valor) => mensajeDeCampo(codigoNombre(valor ?? '')),
        errorExterno: externo(CampoRegistro.nombre),
        alCambiar: (_) => vm.limpiarErrorCampo(CampoRegistro.nombre),
      ),
      const SizedBox(height: Medidas.espacioMd),
      CampoTexto(
        etiqueta: 'Correo institucional',
        controlador: _correo,
        icono: Icons.alternate_email,
        ayuda: 'Debe terminar en $dominios.',
        teclado: TextInputType.emailAddress,
        accionTeclado: TextInputAction.next,
        autocompletar: const [AutofillHints.email],
        habilitado: !estado.enviando,
        validador: (valor) => mensajeDeCampo(codigoCorreoRegistro(valor ?? '')),
        errorExterno: externo(CampoRegistro.correo),
        alCambiar: (_) => vm.limpiarErrorCampo(CampoRegistro.correo),
      ),
      const SizedBox(height: Medidas.espacioMd),
      CampoTexto(
        etiqueta: 'Boleta o número de empleado',
        controlador: _boleta,
        icono: Icons.badge_outlined,
        ayuda: 'Boleta de 10 dígitos o número de empleado de 4 a 10 dígitos.',
        teclado: TextInputType.number,
        accionTeclado: TextInputAction.next,
        formatos: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        habilitado: !estado.enviando,
        validador: (valor) =>
            mensajeDeCampo(codigoBoletaOEmpleado(valor ?? '')),
        errorExterno: externo(CampoRegistro.boletaOEmpleado),
        alCambiar: (_) => vm.limpiarErrorCampo(CampoRegistro.boletaOEmpleado),
      ),
      const SizedBox(height: Medidas.espacioMd),
      CampoPassword(
        etiqueta: 'Contraseña',
        controlador: _password,
        esNueva: true,
        ayuda: 'Mínimo 8 caracteres, con al menos una letra y un número.',
        accionTeclado: TextInputAction.done,
        habilitado: !estado.enviando,
        validador: (valor) => mensajeDeCampo(codigoPasswordNueva(valor ?? '')),
        errorExterno: externo(CampoRegistro.password),
        alCambiar: (_) => vm.limpiarErrorCampo(CampoRegistro.password),
      ),
      const SizedBox(height: Medidas.espacioLg),
      Text('Tus fotos', style: tema.textTheme.titleMedium),
      const SizedBox(height: Medidas.espacioMd),
      ..._tarjetasFoto(estado),
      const SizedBox(height: Medidas.espacioMd),
      Row(
        children: [
          Checkbox(
            value: _aceptoAviso,
            semanticLabel: 'Acepto el aviso de privacidad',
            onChanged: estado.enviando
                ? null
                : (valor) {
                    setState(() => _aceptoAviso = valor ?? false);
                    vm.limpiarErrorCampo(CampoRegistro.aviso);
                  },
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('He leído y acepto el', style: tema.textTheme.bodyLarge),
                TextButton(
                  onPressed: () => mostrarAvisoPrivacidad(context),
                  child: const Text('aviso de privacidad'),
                ),
              ],
            ),
          ),
        ],
      ),
      if (errorAviso != null) MensajeErrorCampo(errorAviso),
      const SizedBox(height: Medidas.espacioMd),
      if (error != null) ...[
        Aviso(tipo: TipoAviso.error, mensaje: error.mensaje()),
        const SizedBox(height: Medidas.espacioMd),
      ],
      FilledButton(
        onPressed: estado.enviando ? null : _registrar,
        child: estado.enviando
            ? const ProgresoBoton()
            : const Text('Crear cuenta'),
      ),
      const SizedBox(height: Medidas.espacioMd),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '¿Ya tienes una cuenta?',
            style: tema.textTheme.bodyLarge?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: estado.enviando ? null : () => context.go(Rutas.login),
            child: const Text('Inicia sesión'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _pasoFotos(EstadoRegistro estado) {
    final error = estado.error;
    return [
      const Aviso(
        tipo: TipoAviso.exito,
        titulo: 'Tu cuenta ya fue creada',
        mensaje:
            'Solo falta subir tus fotos para que Administración pueda '
            'revisar tu registro.',
      ),
      const SizedBox(height: Medidas.espacioMd),
      ..._tarjetasFoto(estado),
      const SizedBox(height: Medidas.espacioMd),
      if (error != null) ...[
        Aviso(tipo: TipoAviso.error, mensaje: error.mensaje()),
        const SizedBox(height: Medidas.espacioMd),
      ],
      FilledButton.icon(
        onPressed: estado.enviando
            ? null
            : ref.read(registroProvider.notifier).reintentar,
        icon: estado.enviando
            ? const ProgresoBoton()
            : const Icon(Icons.cloud_upload_outlined),
        label: Text(estado.enviando ? 'Subiendo fotos' : 'Subir fotos'),
      ),
      const SizedBox(height: Medidas.espacioSm),
      TextButton(
        onPressed: estado.enviando ? null : () => context.go(Rutas.inicio),
        child: const Text('Continuar después'),
      ),
    ];
  }

  List<Widget> _tarjetasFoto(EstadoRegistro estado) {
    final vm = ref.read(registroProvider.notifier);
    return [
      TarjetaFoto(
        titulo: 'Foto del titular',
        ayuda: 'Tu rostro de frente y con buena luz.',
        foto: estado.fotoTitular,
        subida: estado.titularSubida,
        habilitada: !estado.enviando,
        error:
            estado.errorFotoTitular?.mensaje() ??
            mensajeDeCampo(estado.erroresCampos[CampoRegistro.fotoTitular]),
        alElegir: (origen) => vm.elegirFoto(TipoFotoRegistro.titular, origen),
      ),
      const SizedBox(height: Medidas.espacioMd),
      TarjetaFoto(
        titulo: 'Foto de tu credencial',
        ayuda:
            'Tu credencial escolar o de empleado, completa y legible. Solo '
            'la ve Administración.',
        foto: estado.fotoCredencial,
        subida: estado.credencialSubida,
        habilitada: !estado.enviando,
        error:
            estado.errorFotoCredencial?.mensaje() ??
            mensajeDeCampo(estado.erroresCampos[CampoRegistro.fotoCredencial]),
        alElegir: (origen) =>
            vm.elegirFoto(TipoFotoRegistro.credencial, origen),
      ),
    ];
  }
}
