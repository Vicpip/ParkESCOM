import 'package:postgres/postgres.dart';

/// Pool de conexiones a PostgreSQL que comparten todas las rutas de la API.
typedef PoolDb = Pool<void>;

/// Abre una conexión a PostgreSQL a partir de una URL
/// `postgres://usuario:password@host:puerto/base`.
///
/// Si la URL no trae el parámetro `sslmode` se usa `disable`: la base local
/// y la del VPS se alcanzan por localhost o por la red interna de Docker,
/// sin TLS. Para otro caso, agrega `?sslmode=require` a la URL.
Future<Connection> abrirConexion(String url) =>
    Connection.openFromUrl(_conSslMode(url));

/// Crea un pool de conexiones con la misma regla de `sslmode` que
/// [abrirConexion]. Las conexiones se abren hasta que se usan.
PoolDb abrirPool(String url) => Pool.withUrl(_conSslMode(url));

String _conSslMode(String url) {
  if (Uri.parse(url).queryParameters.containsKey('sslmode')) return url;
  final separador = url.contains('?') ? '&' : '?';
  return '$url${separador}sslmode=disable';
}
