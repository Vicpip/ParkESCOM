import 'dart:io';

/// Lee una variable de configuración.
///
/// Primero busca en las variables de entorno del proceso. Si no está, busca
/// en un archivo `.env` de la carpeta actual o de la carpeta padre (la raíz
/// del monorepo), para no tener que exportar las variables a mano en
/// desarrollo local. En el VPS las variables llegan por el entorno.
///
/// Devuelve `null` si la variable no existe o está vacía.
String? leerEntorno(String nombre) {
  final delProceso = Platform.environment[nombre];
  if (delProceso != null && delProceso.trim().isNotEmpty) {
    return delProceso.trim();
  }
  final delArchivo = _archivoEnv()[nombre];
  if (delArchivo != null && delArchivo.isNotEmpty) return delArchivo;
  return null;
}

/// Error de configuración del entorno local (variable o carpeta faltante),
/// con un [mensaje] listo para mostrarse en la terminal.
class ErrorDeConfiguracion implements Exception {
  /// Crea el error con su [mensaje].
  const ErrorDeConfiguracion(this.mensaje);

  /// Explicación del problema y de cómo resolverlo.
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Igual que [leerEntorno], pero lanza [ErrorDeConfiguracion] con un mensaje
/// claro si la variable no existe.
String exigirEntorno(String nombre) {
  final valor = leerEntorno(nombre);
  if (valor == null) {
    throw ErrorDeConfiguracion(
      'Falta la variable de entorno $nombre. '
      'Defínela en el entorno o en el archivo .env de la raíz del proyecto '
      '(ver .env.example).',
    );
  }
  return valor;
}

Map<String, String>? _cache;

Map<String, String> _archivoEnv() {
  final cache = _cache;
  if (cache != null) return cache;

  final actual = Directory.current;
  final candidatos = [
    File('${actual.path}/.env'),
    File('${actual.parent.path}/.env'),
  ];
  for (final archivo in candidatos) {
    if (archivo.existsSync()) {
      return _cache = parsearEnv(archivo.readAsStringSync());
    }
  }
  return _cache = const {};
}

/// Convierte el contenido de un archivo `.env` (`NOMBRE=valor` por línea) en
/// un mapa. Ignora líneas vacías y comentarios, y quita comillas envolventes.
Map<String, String> parsearEnv(String contenido) {
  final valores = <String, String>{};
  for (final cruda in contenido.split('\n')) {
    final linea = cruda.trim();
    if (linea.isEmpty || linea.startsWith('#')) continue;
    final igual = linea.indexOf('=');
    if (igual <= 0) continue;
    final nombre = linea.substring(0, igual).trim();
    var valor = linea.substring(igual + 1).trim();
    final entreComillas =
        valor.length >= 2 &&
        ((valor.startsWith('"') && valor.endsWith('"')) ||
            (valor.startsWith("'") && valor.endsWith("'")));
    if (entreComillas) valor = valor.substring(1, valor.length - 1);
    valores[nombre] = valor;
  }
  return valores;
}
