import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Configuración regional de toda la app.
const localeApp = 'es_MX';

/// Carga los datos de fechas de `es_MX`. Se llama una vez al arrancar.
Future<void> iniciarFormatoFechas() async {
  await initializeDateFormatting(localeApp);
  Intl.defaultLocale = localeApp;
}

/// Hora en formato de 24 horas: `13:15`.
String formatearHora(DateTime fecha) =>
    DateFormat.Hm(localeApp).format(fecha.toLocal());

/// Fecha corta: `6 oct 2026`.
String formatearFecha(DateTime fecha) =>
    DateFormat.yMMMd(localeApp).format(fecha.toLocal());

/// Fecha y hora: `6 oct 2026, 13:15`.
String formatearFechaHora(DateTime fecha) =>
    '${formatearFecha(fecha)}, ${formatearHora(fecha)}';
