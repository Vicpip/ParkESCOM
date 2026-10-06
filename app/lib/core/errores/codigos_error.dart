/// Códigos de error de la API (`error.code`) y los que la app agrega para
/// fallas que no vienen del servidor.
abstract final class CodigoError {
  // De la API.
  static const validacion = 'VALIDACION';
  static const dominioNoPermitido = 'DOMINIO_NO_PERMITIDO';
  static const correoYaRegistrado = 'CORREO_YA_REGISTRADO';
  static const boletaYaRegistrada = 'BOLETA_YA_REGISTRADA';
  static const credencialesInvalidas = 'CREDENCIALES_INVALIDAS';
  static const demasiadosIntentos = 'DEMASIADOS_INTENTOS';
  static const enlaceInvalido = 'ENLACE_INVALIDO';
  static const refreshInvalido = 'REFRESH_INVALIDO';
  static const noAutenticado = 'NO_AUTENTICADO';
  static const sinPermiso = 'SIN_PERMISO';
  static const passwordActualIncorrecta = 'PASSWORD_ACTUAL_INCORRECTA';
  static const solicitudInvalida = 'SOLICITUD_INVALIDA';
  static const rutaNoEncontrada = 'RUTA_NO_ENCONTRADA';
  static const metodoNoPermitido = 'METODO_NO_PERMITIDO';
  static const errorInterno = 'ERROR_INTERNO';
  static const archivoMuyGrande = 'ARCHIVO_MUY_GRANDE';
  static const archivoInvalido = 'ARCHIVO_INVALIDO';
  static const longitudRequerida = 'LONGITUD_REQUERIDA';
  static const archivoNoEncontrado = 'ARCHIVO_NO_ENCONTRADO';
  static const perfilBloqueado = 'PERFIL_BLOQUEADO';

  // Por campo, dentro de VALIDACION, que no están en `shared`.
  static const archivoFaltante = 'ARCHIVO_FALTANTE';
  static const propositoInvalido = 'PROPOSITO_INVALIDO';
  static const fotoInvalida = 'FOTO_INVALIDA';

  // Propios de la app.

  /// No hubo respuesta del servidor: sin red, servidor caído o tiempo agotado.
  static const sinConexion = 'SIN_CONEXION';

  /// El servidor respondió algo que la app no entiende.
  static const respuestaInesperada = 'RESPUESTA_INESPERADA';

  /// No se pudo abrir la cámara o la galería.
  static const fotoNoDisponible = 'FOTO_NO_DISPONIBLE';

  /// Campo obligatorio sin llenar.
  static const campoRequerido = 'CAMPO_REQUERIDO';

  /// Falta elegir una foto obligatoria.
  static const fotoRequerida = 'FOTO_REQUERIDA';

  /// Falta aceptar el aviso de privacidad.
  static const avisoRequerido = 'AVISO_REQUERIDO';
}
