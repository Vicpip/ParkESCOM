import 'dart:io';

import 'package:backend/auth/servicio_auth.dart';
import 'package:backend/http/error_api.dart';
import 'package:dart_frog/dart_frog.dart';

/// `POST /auth/registro`: crea la cuenta (pendiente) y abre sesión.
Future<Response> onRequest(RequestContext context) async {
  exigirMetodo(context, HttpMethod.post);
  final json = await leerJson(context);
  final sesion = await context.read<ServicioAuth>().registrar(
    nombre: campoTexto(json, 'nombre'),
    correo: campoTexto(json, 'correo'),
    boletaOEmpleado: campoTexto(json, 'boleta_o_empleado'),
    password: campoTexto(json, 'password'),
  );
  return Response.json(statusCode: HttpStatus.created, body: sesion.toJson());
}
