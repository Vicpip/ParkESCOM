import 'dart:io';

import 'package:backend/config/configuracion.dart';
import 'package:backend/config/entorno.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Correo de texto simple listo para enviarse.
class CorreoSaliente {
  /// Crea el correo para [destinatario] con su [asunto] y su [texto].
  const CorreoSaliente({
    required this.destinatario,
    required this.asunto,
    required this.texto,
  });

  /// Correo de recuperación de contraseña con el [enlace] de un solo uso.
  const CorreoSaliente.restablecimiento({
    required String destinatario,
    required String enlace,
  }) : this(
         destinatario: destinatario,
         asunto: 'Restablece tu contraseña de ParkESCOM',
         texto:
             'Para elegir una contraseña nueva abre este enlace:\n\n'
             '$enlace\n\n'
             'Este enlace vence en 15 minutos. Si no lo pediste, ignora este '
             'mensaje.',
       );

  /// Dirección a la que se envía.
  final String destinatario;

  /// Asunto del mensaje.
  final String asunto;

  /// Cuerpo en texto simple.
  final String texto;
}

/// Puerta de salida de los correos de la API. Las pruebas la sustituyen por
/// una implementación que solo captura los mensajes.
// Una sola operación, pero es el punto de sustitución entre SMTP, consola y
// las pruebas.
// ignore: one_member_abstracts
abstract interface class EnviadorCorreo {
  /// Envía [correo]. Lanza una excepción si no se pudo entregar al servidor.
  Future<void> enviar(CorreoSaliente correo);
}

/// Envía los correos por SMTP con el paquete `mailer`.
class EnviadorSmtp implements EnviadorCorreo {
  /// Crea el enviador hacia [host]:[puerto], con [remitente] como `From`.
  ///
  /// El puerto 465 usa TLS desde el inicio; cualquier otro negocia STARTTLS,
  /// y si el servidor no lo ofrece el envío falla (nunca va sin cifrar).
  EnviadorSmtp({
    required String host,
    required int puerto,
    required this.remitente,
    String? usuario,
    String? password,
  }) : _servidor = SmtpServer(
         host,
         port: puerto,
         ssl: puerto == _puertoTlsImplicito,
         username: usuario,
         password: password,
       );

  static const _puertoTlsImplicito = 465;
  static const _espera = Duration(seconds: 20);

  /// Dirección que aparece como remitente (`SMTP_FROM`).
  final String remitente;

  final SmtpServer _servidor;

  @override
  Future<void> enviar(CorreoSaliente correo) async {
    final mensaje = Message()
      ..from = Address(remitente, 'ParkESCOM')
      ..recipients.add(correo.destinatario)
      ..subject = correo.asunto
      ..text = correo.texto;
    await send(mensaje, _servidor, timeout: _espera);
  }
}

/// Imprime los correos en la consola en vez de enviarlos. Solo existe para
/// desarrollo local sin SMTP: el texto incluye el enlace de recuperación.
class EnviadorConsola implements EnviadorCorreo {
  /// Crea el enviador; [escribir] recibe cada línea (stdout por defecto).
  EnviadorConsola({void Function(String linea)? escribir})
    : _escribir = escribir ?? stdout.writeln;

  final void Function(String linea) _escribir;

  @override
  Future<void> enviar(CorreoSaliente correo) async {
    _escribir(
      '[correo de desarrollo] Para: ${correo.destinatario}\n'
      'Asunto: ${correo.asunto}\n\n${correo.texto}\n',
    );
  }
}

/// Elige el enviador según el [entorno] y las variables `SMTP_*`.
///
/// Con [host] siempre se usa SMTP. Sin [host], en desarrollo los correos se
/// imprimen en consola; en producción no hay alternativa y se lanza
/// [ErrorDeConfiguracion], para que la API no arranque sin poder enviar
/// correos (y nunca imprima un enlace).
EnviadorCorreo crearEnviadorCorreo({
  required Entorno entorno,
  String? host,
  String? puerto,
  String? usuario,
  String? password,
  String? remitente,
}) {
  if (host == null) {
    if (entorno == Entorno.produccion) {
      throw const ErrorDeConfiguracion(
        'Falta la variable de entorno SMTP_HOST: en producción la API no '
        'arranca sin servidor de correo. Para desarrollo local define '
        'ENTORNO=desarrollo y los enlaces de recuperación se imprimen en '
        'consola.',
      );
    }
    return EnviadorConsola();
  }
  if (remitente == null) {
    throw const ErrorDeConfiguracion(
      'Falta la variable de entorno SMTP_FROM (dirección del remitente).',
    );
  }
  final numeroPuerto = puerto == null ? 587 : int.tryParse(puerto);
  if (numeroPuerto == null || numeroPuerto <= 0 || numeroPuerto > 65535) {
    throw const ErrorDeConfiguracion('SMTP_PORT debe ser un número de puerto.');
  }
  return EnviadorSmtp(
    host: host,
    puerto: numeroPuerto,
    remitente: remitente,
    usuario: usuario,
    password: password,
  );
}

/// [crearEnviadorCorreo] con las variables `SMTP_HOST`, `SMTP_PORT`,
/// `SMTP_USER`, `SMTP_PASSWORD` y `SMTP_FROM` del entorno.
EnviadorCorreo enviadorCorreoDesdeEntorno(Entorno entorno) =>
    crearEnviadorCorreo(
      entorno: entorno,
      host: leerEntorno('SMTP_HOST'),
      puerto: leerEntorno('SMTP_PORT'),
      usuario: leerEntorno('SMTP_USER'),
      password: leerEntorno('SMTP_PASSWORD'),
      remitente: leerEntorno('SMTP_FROM'),
    );
