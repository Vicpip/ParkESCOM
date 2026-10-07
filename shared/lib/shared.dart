/// Código compartido entre la app y el backend de ParkESCOM: modelos, motor
/// de validación, TOTP y verificación de pases.
///
/// Es Dart puro: no depende de Flutter ni de `dart:io`.
library;

export 'src/modelos/enumeraciones.dart';
export 'src/modelos/solicitud.dart';
export 'src/modelos/vehiculo.dart';
export 'src/validacion/codigos_validacion.dart';
export 'src/validacion/datos_vehiculo.dart';
export 'src/validacion/validadores.dart';
