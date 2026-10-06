import 'dart:typed_data';

/// De dónde sale una foto.
enum OrigenFoto { camara, galeria }

/// Para qué se sube una foto; decide quién puede verla y a qué campo se
/// puede asignar. El nombre es el valor de `proposito` en la API.
enum PropositoFoto {
  perfil('perfil'),
  credencialEscolar('credencial_escolar');

  const PropositoFoto(this.valor);

  final String valor;
}

/// Foto elegida por el usuario, ya comprimida a JPEG de menos de 2 MB.
class Foto {
  const Foto(this.bytes);

  final Uint8List bytes;
}
