import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

/// Calcula el hash bcrypt de [password] con el [costo] indicado.
///
/// Corre en otro isolate porque bcrypt es lento a propósito y bloquearía al
/// servidor mientras calcula.
Future<String> hashearPassword(String password, {required int costo}) =>
    Isolate.run(
      () => BCrypt.hashpw(password, BCrypt.gensalt(logRounds: costo)),
    );

/// Compara [password] contra un [hash] bcrypt, también en otro isolate.
Future<bool> verificarPassword(String password, String hash) =>
    Isolate.run(() => BCrypt.checkpw(password, hash));
