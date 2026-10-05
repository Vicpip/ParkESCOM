import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:dart_frog/dart_frog.dart';

/// `GET /auth/me`: datos del usuario autenticado.
Future<Response> onRequest(RequestContext context) =>
    protegida(context, _manejar);

Future<Response> _manejar(RequestContext context) async {
  exigirMetodo(context, HttpMethod.get);
  final usuario = await context.read<ServicioAuth>().obtenerUsuario(
    context.read<UsuarioAutenticado>().id,
  );
  return Response.json(body: {'usuario': usuario.toJson()});
}
