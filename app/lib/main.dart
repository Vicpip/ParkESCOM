import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/errores/errores_globales.dart';
import 'core/formato/fechas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  instalarManejoGlobalDeErrores();
  // Rutas sin "#": el enlace de recuperación de contraseña llega como
  // /restablecer?token=...
  usePathUrlStrategy();
  await iniciarFormatoFechas();
  runApp(const ProviderScope(child: AplicacionParkEscom()));
}
