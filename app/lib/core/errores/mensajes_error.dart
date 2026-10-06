import 'package:shared/shared.dart';

import 'codigos_error.dart';

/// Único lugar donde los códigos de error se traducen a textos para el
/// usuario (español de México).

/// Pantalla desde la que se muestra un error. Algunos códigos se explican
/// distinto según lo que el usuario estaba haciendo.
enum ContextoError { general, inicioSesion, recuperacion }

const _mensajeGenerico = 'Ocurrió un error. Intenta de nuevo.';

const _mensajes = <String, String>{
  CodigoError.validacion: 'Revisa los datos marcados.',
  CodigoError.dominioNoPermitido:
      'Usa tu correo institucional para registrarte.',
  CodigoError.correoYaRegistrado: 'Ya existe una cuenta con ese correo.',
  CodigoError.boletaYaRegistrada:
      'Ya existe una cuenta con esa boleta o número de empleado.',
  CodigoError.credencialesInvalidas: 'El correo o la contraseña no coinciden.',
  CodigoError.demasiadosIntentos:
      'Demasiados intentos. Espera unos minutos e intenta de nuevo.',
  CodigoError.enlaceInvalido:
      'El enlace ya no es válido. Pide uno nuevo para restablecer tu '
      'contraseña.',
  CodigoError.refreshInvalido: 'Tu sesión terminó. Inicia sesión de nuevo.',
  CodigoError.noAutenticado: 'Tu sesión terminó. Inicia sesión de nuevo.',
  CodigoError.sinPermiso: 'No tienes permiso para realizar esta acción.',
  CodigoError.passwordActualIncorrecta: 'La contraseña actual no es correcta.',
  CodigoError.solicitudInvalida:
      'No pudimos procesar la solicitud. Intenta de nuevo.',
  CodigoError.rutaNoEncontrada:
      'No encontramos lo que buscas. Actualiza la app e intenta de nuevo.',
  CodigoError.metodoNoPermitido:
      'No pudimos procesar la solicitud. Intenta de nuevo.',
  CodigoError.errorInterno:
      'Tuvimos un problema en el servidor. Intenta de nuevo en unos minutos.',
  CodigoError.archivoMuyGrande:
      'La foto pesa más de 2 MB. Elige otra o toma una nueva.',
  CodigoError.archivoInvalido:
      'El archivo no es una foto válida. Usa una imagen JPG o PNG.',
  CodigoError.longitudRequerida: 'No pudimos enviar la foto. Intenta de nuevo.',
  CodigoError.archivoNoEncontrado: 'No encontramos esa foto.',
  CodigoError.perfilBloqueado:
      'Para cambiar tus datos o fotos, contacta a Administración.',
  CodigoError.sinConexion:
      'No pudimos conectar con el servidor. Revisa tu conexión a internet e '
      'intenta de nuevo.',
  CodigoError.respuestaInesperada:
      'Recibimos una respuesta que no esperábamos. Intenta de nuevo.',
  CodigoError.fotoNoDisponible:
      'No pudimos abrir la cámara o la galería. Revisa los permisos de la '
      'app e intenta de nuevo.',
};

const _mensajesPorContexto = <ContextoError, Map<String, String>>{
  ContextoError.inicioSesion: {
    CodigoError.demasiadosIntentos:
        'Demasiados intentos fallidos con este correo. Espera unos minutos '
        'antes de volver a intentar.',
  },
  ContextoError.recuperacion: {
    CodigoError.demasiadosIntentos:
        'Ya pediste varios enlaces para este correo. Usa el más reciente o '
        'intenta más tarde.',
  },
};

const _mensajesCampo = <String, String>{
  CodigoValidacion.nombreVacio: 'Escribe tu nombre completo.',
  CodigoValidacion.nombreMuyLargo:
      'El nombre no puede pasar de 120 caracteres.',
  CodigoValidacion.correoInvalido:
      'Escribe un correo válido, como nombre@alumno.ipn.mx.',
  CodigoValidacion.dominioNoPermitido: 'Usa tu correo institucional.',
  CodigoValidacion.boletaInvalida: 'La boleta tiene 10 dígitos.',
  CodigoValidacion.numeroEmpleadoInvalido:
      'El número de empleado tiene de 4 a 10 dígitos.',
  CodigoValidacion.boletaOEmpleadoInvalido:
      'Escribe tu boleta (10 dígitos) o tu número de empleado (4 a 10 '
      'dígitos).',
  CodigoValidacion.passwordMuyCorta: 'Usa al menos 8 caracteres.',
  CodigoValidacion.passwordMuyLarga:
      'La contraseña es demasiado larga. Usa una más corta.',
  CodigoValidacion.passwordSinLetra: 'Incluye al menos una letra.',
  CodigoValidacion.passwordSinNumero: 'Incluye al menos un número.',
  CodigoError.correoYaRegistrado: 'Ya existe una cuenta con ese correo.',
  CodigoError.boletaYaRegistrada:
      'Ya existe una cuenta con esa boleta o número de empleado.',
  CodigoError.archivoFaltante: 'Falta la foto.',
  CodigoError.propositoInvalido: 'No pudimos enviar la foto. Intenta de nuevo.',
  CodigoError.fotoInvalida: 'No pudimos usar esa foto. Súbela de nuevo.',
  CodigoError.campoRequerido: 'Este campo es obligatorio.',
  CodigoError.fotoRequerida: 'Esta foto es obligatoria.',
  CodigoError.avisoRequerido:
      'Para crear tu cuenta debes aceptar el aviso de privacidad.',
};

/// Texto para el usuario del error [codigo]. Si la app no conoce el código
/// usa [respaldo] (el mensaje que mandó la API) y, si no hay, uno genérico.
String mensajeDeError(
  String codigo, {
  ContextoError contexto = ContextoError.general,
  String? respaldo,
}) =>
    _mensajesPorContexto[contexto]?[codigo] ??
    _mensajes[codigo] ??
    respaldo ??
    _mensajeGenerico;

/// Texto para el usuario del código de error de un campo, o `null` si
/// [codigo] es `null` (campo válido).
String? mensajeDeCampo(String? codigo) =>
    codigo == null ? null : _mensajesCampo[codigo] ?? 'Revisa este dato.';
