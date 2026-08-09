/// Las dos variantes que el servidor deriva de **una sola** foto subida.
///
/// No son dos cosas que el usuario elija: sube una imagen y el backend genera
/// las dos. Este enum existe para pedir la que corresponda al mostrarla.
enum TipoImagen {
  miniatura('MINIATURA', 'Miniatura'),
  original('ORIGINAL', 'Fotografía');

  const TipoImagen(this.valor, this.etiqueta);

  /// Como viaja en la URL y en el JSON.
  final String valor;

  final String etiqueta;

  static TipoImagen? desde(Object? crudo) {
    if (crudo == null) return null;
    final texto = '$crudo';
    for (final t in values) {
      if (t.valor == texto) return t;
    }
    return null;
  }
}

/// Región de la imagen que se quiere conservar, en píxeles de la imagen
/// original tal como está en el archivo.
///
/// Viaja al servidor como cuatro números y el recorte se aplica allá, sobre la
/// foto en su resolución completa. Recortar en el navegador obligaría a
/// trabajar sobre una copia ya reducida y se perdería detalle justo en la parte
/// que interesa.
class Recorte {
  const Recorte({
    required this.x,
    required this.y,
    required this.ancho,
    required this.alto,
  });

  final int x;
  final int y;
  final int ancho;
  final int alto;

  /// Si el recorte abarca prácticamente toda la imagen no vale la pena
  /// mandarlo: el resultado sería el mismo y el servidor se ahorra el paso.
  bool esCompleto(int anchoImagen, int altoImagen) {
    const margen = 2;
    return x <= margen &&
        y <= margen &&
        ancho >= anchoImagen - margen * 2 &&
        alto >= altoImagen - margen * 2;
  }

  Map<String, dynamic> get query => {
        'recorteX': x,
        'recorteY': y,
        'recorteAncho': ancho,
        'recorteAlto': alto,
      };

  @override
  String toString() => '$ancho × $alto desde ($x, $y)';
}

/// Qué pasó al subir una foto.
///
/// Trae el peso de lo que se envió además del de lo guardado, para poder
/// mostrarle al usuario cuánto se redujo: es lo que explica por qué no hizo
/// falta que comprimiera nada antes de subir.
class ImagenSubida {
  const ImagenSubida({
    required this.tamanoSubidoBytes,
    required this.anchoSubido,
    required this.altoSubido,
    required this.original,
    required this.miniatura,
  });

  final int tamanoSubidoBytes;
  final int anchoSubido;
  final int altoSubido;
  final Imagen original;
  final Imagen miniatura;

  int get tamanoGuardadoBytes =>
      original.tamanoBytes + miniatura.tamanoBytes;

  int get porcentajeReduccion => tamanoSubidoBytes <= 0
      ? 0
      : (100 - (tamanoGuardadoBytes * 100 ~/ tamanoSubidoBytes)).clamp(0, 100);

  /// Si el servidor efectivamente achicó algo. Con una foto ya chica puede no
  /// haber ahorro, y decir «se redujo un 0 %» sería ruido.
  bool get huboReduccion => tamanoGuardadoBytes < tamanoSubidoBytes;

  factory ImagenSubida.desdeJson(Map<String, dynamic> json) => ImagenSubida(
        tamanoSubidoBytes: (json['tamanoSubidoBytes'] as num?)?.toInt() ?? 0,
        anchoSubido: (json['anchoSubido'] as num?)?.toInt() ?? 0,
        altoSubido: (json['altoSubido'] as num?)?.toInt() ?? 0,
        original: Imagen.desdeJson(
            (json['original'] as Map<String, dynamic>?) ?? const {}),
        miniatura: Imagen.desdeJson(
            (json['miniatura'] as Map<String, dynamic>?) ?? const {}),
      );
}

/// Formatea un peso en bytes para mostrarlo.
String pesoLegible(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1048576).toStringAsFixed(2)} MB';
}

/// Metadata de una imagen guardada, con la dirección del archivo.
///
/// Los bytes no viven en la base: están en el almacén del servidor y se piden a
/// [url]. Esa dirección incluye un identificador aleatorio que cambia cada vez
/// que se reemplaza la foto, así que la caché se invalida sola y no hacen falta
/// parámetros de versión.
class Imagen {
  const Imagen({
    required this.tipo,
    required this.url,
    required this.tipoMime,
    required this.tamanoBytes,
    required this.ancho,
    required this.alto,
    required this.nombreOriginal,
    required this.actualizadaEn,
  });

  final TipoImagen tipo;

  /// Ruta relativa al servidor, tal como la devuelve la API.
  final String url;

  final String tipoMime;
  final int tamanoBytes;
  final int ancho;
  final int alto;
  final String? nombreOriginal;
  final DateTime? actualizadaEn;

  String get tamanoLegible => pesoLegible(tamanoBytes);

  String get dimensiones => '$ancho × $alto';

  factory Imagen.desdeJson(Map<String, dynamic> json) => Imagen(
        tipo: TipoImagen.desde(json['tipo']) ?? TipoImagen.original,
        url: json['url'] as String? ?? '',
        tipoMime: json['tipoMime'] as String? ?? 'image/jpeg',
        tamanoBytes: (json['tamanoBytes'] as num?)?.toInt() ?? 0,
        ancho: (json['ancho'] as num?)?.toInt() ?? 0,
        alto: (json['alto'] as num?)?.toInt() ?? 0,
        nombreOriginal: json['nombreOriginal'] as String?,
        actualizadaEn: switch (json['actualizadaEn']) {
          final String s => DateTime.tryParse(s),
          _ => null,
        },
      );
}
