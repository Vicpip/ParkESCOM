import 'dart:io';

import 'package:backend/archivos/almacen_archivos.dart';
import 'package:backend/archivos/servicio_archivos.dart';
import 'package:backend/auth/usuario.dart';
import 'package:backend/http/error_api.dart';
import 'package:backend/middleware/autenticacion.dart';
import 'package:dart_frog/dart_frog.dart';

/// Lo que el formulario multipart agrega al archivo: delimitadores,
/// cabeceras de cada parte y el campo `proposito`.
const _margenMultipart = 16 * 1024;

/// `POST /archivos`: sube una foto (`multipart/form-data` con los campos
/// `archivo` y `proposito`) y responde 201 con su `id`.
Future<Response> onRequest(RequestContext context) =>
    protegida(context, _manejar);

Future<Response> _manejar(RequestContext context) async {
  exigirMetodo(context, HttpMethod.post);
  final peticion = context.request;

  // El tamaño se revisa antes de leer un solo byte del cuerpo. Sin
  // Content-Length no hay forma de saberlo de antemano, así que se exige.
  final longitud = int.tryParse(
    peticion.headers[HttpHeaders.contentLengthHeader] ?? '',
  );
  if (longitud == null) {
    throw const ErrorApi(
      HttpStatus.lengthRequired,
      'LONGITUD_REQUERIDA',
      'La solicitud debe indicar su tamaño.',
    );
  }
  if (longitud > tamanoMaximoArchivo + _margenMultipart) {
    throw ServicioArchivos.muyGrande;
  }

  final tipo = peticion.headers[HttpHeaders.contentTypeHeader] ?? '';
  if (!tipo.toLowerCase().startsWith('multipart/form-data') ||
      !tipo.contains('boundary=')) {
    throw const ErrorApi.solicitudInvalida();
  }
  final FormData formulario;
  try {
    formulario = await peticion.formData();
  } on Exception {
    throw const ErrorApi.solicitudInvalida();
  }

  // Del archivo solo se usa el contenido: su nombre y su Content-Type los
  // escribe el cliente y se ignoran.
  final archivo = formulario.files['archivo'];
  final proposito = PropositoArchivo.deNombre(formulario.fields['proposito']);
  if (archivo == null || proposito == null) {
    throw ErrorApi.validacion({
      if (archivo == null) 'archivo': 'ARCHIVO_FALTANTE',
      if (proposito == null) 'proposito': 'PROPOSITO_INVALIDO',
    });
  }

  final id = await context.read<ServicioArchivos>().subir(
    duenoId: context.read<UsuarioAutenticado>().id,
    proposito: proposito,
    bytes: await archivo.readAsBytes(),
  );
  return Response.json(statusCode: HttpStatus.created, body: {'id': id});
}
