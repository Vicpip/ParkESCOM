import 'package:postgres/postgres.dart';

/// Abre una conexión a PostgreSQL a partir de una URL
/// `postgres://usuario:password@host:puerto/base`.
///
/// Si la URL no trae el parámetro `sslmode` se usa `disable`: la base local
/// y la del VPS se alcanzan por localhost o por la red interna de Docker,
/// sin TLS. Para otro caso, agrega `?sslmode=require` a la URL.
Future<Connection> abrirConexion(String url) {
  final tieneSslMode = Uri.parse(url).queryParameters.containsKey('sslmode');
  if (tieneSslMode) return Connection.openFromUrl(url);
  final separador = url.contains('?') ? '&' : '?';
  return Connection.openFromUrl('$url${separador}sslmode=disable');
}
