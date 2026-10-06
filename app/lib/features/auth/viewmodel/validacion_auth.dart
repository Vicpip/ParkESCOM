import 'package:shared/shared.dart';

import '../../../core/config/entorno.dart';
import '../../../core/errores/codigos_error.dart';

/// Validación de los formularios de acceso con las reglas de `shared`. Cada
/// función devuelve el código del error o `null`; el texto sale de
/// `mensajes_error.dart`.

/// Correo de inicio de sesión y de recuperación: solo se revisa el formato,
/// porque el dominio lo decide la API.
String? codigoCorreoAcceso(String correo) {
  if (correo.trim().isEmpty) return CodigoError.campoRequerido;
  final codigo = validarCorreo(correo, dominiosPermitidos: const []);
  return codigo == CodigoValidacion.correoInvalido ? codigo : null;
}

/// Contraseña de inicio de sesión: solo que no esté vacía (las reglas
/// aplican al crearla).
String? codigoPasswordAcceso(String password) =>
    password.isEmpty ? CodigoError.campoRequerido : null;

String? codigoNombre(String nombre) => validarNombre(nombre);

/// Correo de registro: formato y dominio institucional.
String? codigoCorreoRegistro(String correo) {
  if (correo.trim().isEmpty) return CodigoError.campoRequerido;
  return validarCorreo(correo, dominiosPermitidos: Entorno.dominiosPermitidos);
}

String? codigoBoletaOEmpleado(String valor) {
  if (valor.trim().isEmpty) return CodigoError.campoRequerido;
  return validarBoletaOEmpleado(valor.trim());
}

/// Contraseña nueva: mínimo 8 caracteres, letra, número y máximo 72 bytes.
String? codigoPasswordNueva(String password) {
  if (password.isEmpty) return CodigoError.campoRequerido;
  return validarPassword(password);
}
