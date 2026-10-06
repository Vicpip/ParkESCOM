import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/medidas.dart';

/// Mensaje de error que va debajo de un campo: ícono de advertencia y texto
/// en rojo (nunca solo color).
class MensajeErrorCampo extends StatelessWidget {
  const MensajeErrorCampo(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline,
          size: Medidas.iconoSm,
          color: tema.colorScheme.error,
        ),
        const SizedBox(width: Medidas.espacioXs),
        Expanded(
          child: Text(
            mensaje,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

/// Campo de texto del sistema de diseño: etiqueta arriba y el error, en
/// tiempo real, debajo del campo.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.etiqueta,
    this.controlador,
    this.validador,
    this.errorExterno,
    this.alCambiar,
    this.alEnviar,
    this.ayuda,
    this.icono,
    this.sufijo,
    this.ocultar = false,
    this.habilitado = true,
    this.teclado,
    this.accionTeclado,
    this.autocompletar,
    this.formatos,
    this.capitalizacion = TextCapitalization.none,
  });

  final String etiqueta;
  final TextEditingController? controlador;

  /// Devuelve el mensaje de error o `null`. Se evalúa mientras el usuario
  /// escribe.
  final FormFieldValidator<String>? validador;

  /// Error que no sale de [validador] (por ejemplo, el que respondió la
  /// API). Mientras no sea `null` se muestra en lugar del de [validador].
  final String? errorExterno;

  final ValueChanged<String>? alCambiar;
  final ValueChanged<String>? alEnviar;
  final String? ayuda;
  final IconData? icono;
  final Widget? sufijo;
  final bool ocultar;
  final bool habilitado;
  final TextInputType? teclado;
  final TextInputAction? accionTeclado;
  final Iterable<String>? autocompletar;
  final List<TextInputFormatter>? formatos;
  final TextCapitalization capitalizacion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final icono = this.icono;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: tema.textTheme.labelMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Medidas.espacioXs),
        TextFormField(
          controller: controlador,
          validator: validador,
          forceErrorText: errorExterno,
          errorBuilder: (_, mensaje) => MensajeErrorCampo(mensaje),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: alCambiar,
          onFieldSubmitted: alEnviar,
          obscureText: ocultar,
          enabled: habilitado,
          keyboardType: teclado,
          textInputAction: accionTeclado,
          autofillHints: autocompletar,
          inputFormatters: formatos,
          textCapitalization: capitalizacion,
          autocorrect: false,
          enableSuggestions: !ocultar,
          style: tema.textTheme.bodyLarge,
          decoration: InputDecoration(
            helperText: ayuda,
            prefixIcon: icono == null ? null : Icon(icono),
            suffixIcon: sufijo,
          ),
        ),
      ],
    );
  }
}

/// Campo de contraseña con botón para mostrarla u ocultarla.
class CampoPassword extends StatefulWidget {
  const CampoPassword({
    super.key,
    required this.etiqueta,
    this.controlador,
    this.validador,
    this.errorExterno,
    this.alCambiar,
    this.alEnviar,
    this.ayuda,
    this.habilitado = true,
    this.accionTeclado,
    this.esNueva = false,
  });

  final String etiqueta;
  final TextEditingController? controlador;
  final FormFieldValidator<String>? validador;
  final String? errorExterno;
  final ValueChanged<String>? alCambiar;
  final ValueChanged<String>? alEnviar;
  final String? ayuda;
  final bool habilitado;
  final TextInputAction? accionTeclado;

  /// `true` al crear una contraseña (para el autocompletado del sistema).
  final bool esNueva;

  @override
  State<CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<CampoPassword> {
  bool _oculta = true;

  @override
  Widget build(BuildContext context) {
    return CampoTexto(
      etiqueta: widget.etiqueta,
      controlador: widget.controlador,
      validador: widget.validador,
      errorExterno: widget.errorExterno,
      alCambiar: widget.alCambiar,
      alEnviar: widget.alEnviar,
      ayuda: widget.ayuda,
      habilitado: widget.habilitado,
      accionTeclado: widget.accionTeclado,
      icono: Icons.lock_outline,
      ocultar: _oculta,
      teclado: TextInputType.visiblePassword,
      autocompletar: [
        widget.esNueva ? AutofillHints.newPassword : AutofillHints.password,
      ],
      sufijo: IconButton(
        onPressed: () => setState(() => _oculta = !_oculta),
        tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(
          _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    );
  }
}
