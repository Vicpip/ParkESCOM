import 'dart:io';

import 'package:backend/config/entorno.dart';
import 'package:backend/dependencias.dart';
import 'package:dart_frog/dart_frog.dart';

/// Dart Frog lo llama una vez al arrancar: si falta configuración, la API se
/// detiene aquí con un mensaje claro en vez de fallar en la primera petición.
Future<void> init(InternetAddress ip, int port) async {
  try {
    dependenciasDeProduccion();
  } on ErrorDeConfiguracion catch (error) {
    stderr.writeln(error.mensaje);
    exit(1);
  }
}

/// Punto de entrada que Dart Frog exige junto con [init]; sirve la API sin
/// cambios.
Future<HttpServer> run(Handler handler, InternetAddress ip, int port) =>
    serve(handler, ip, port);
