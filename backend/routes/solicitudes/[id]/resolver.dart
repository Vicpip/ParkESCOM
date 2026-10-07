import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:backend/solicitudes/servicio_solicitudes.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /solicitudes/{id}/resolver` (solo admin): `decision` es `aprobar` o
/// `rechazar`; `comentario` es obligatorio al rechazar. Responde con la
/// solicitud ya resuelta.
Future<Response> onRequest(RequestContext context, String id) =>
    protegida(context, (context) async {
      exigirMetodo(context, HttpMethod.post);
      final solicitud = await context.read<ServicioSolicitudes>().resolver(
        context.read<UsuarioAutenticado>().id,
        id,
        await leerJson(context),
      );
      return Response.json(body: {'solicitud': solicitud.toJson()});
    }, roles: {Rol.admin});
