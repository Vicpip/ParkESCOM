/// Tamaños del sistema de diseño (ritmo de 8 px). Ninguna pantalla escribe
/// un tamaño a mano: todos salen de aquí.
abstract final class Medidas {
  static const double espacioXs = 4;
  static const double espacioSm = 8;
  static const double espacioMd = 16;
  static const double espacioLg = 24;
  static const double espacioXl = 32;

  /// Esquinas de botones, campos, tarjetas y diálogos.
  static const double radio = 12;

  /// Esquinas superiores de la barra de navegación y de las hojas inferiores.
  static const double radioGrande = 16;

  /// Esquinas de los elementos pequeños (casillas, líneas de skeleton).
  static const double radioChico = 4;

  /// Alto mínimo de un botón.
  static const double altoBoton = 48;

  /// Padding horizontal de un botón.
  static const double paddingBoton = 20;

  /// Alto de un campo de texto.
  static const double altoCampo = 52;

  /// Alto de la barra de navegación inferior.
  static const double altoBarraNavegacion = 64;

  static const double bordeFino = 1;
  static const double bordeFoco = 2;

  static const double iconoSm = 16;
  static const double iconoMd = 24;
  static const double iconoLg = 36;

  /// Círculo que rodea el ícono de un estado (vacío, error).
  static const double circuloEstado = 72;

  /// Logotipo de las pantallas de acceso.
  static const double logotipo = 88;

  /// Miniatura de una foto elegida en un formulario.
  static const double miniaturaFoto = 88;

  /// Indicador de progreso dentro de un botón.
  static const double progresoBoton = 20;

  /// Alto de una línea de texto en un skeleton.
  static const double lineaSkeleton = 16;

  /// Desde este ancho la navegación pasa de barra inferior a riel lateral.
  static const double anchoTablet = 600;

  /// Ancho máximo de un formulario en pantallas grandes.
  static const double anchoFormulario = 480;
}
