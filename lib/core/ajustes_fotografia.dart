import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Ajustes locales relativos al original; cero conserva cada valor original.
class AjustesFotografia {
  const AjustesFotografia({
    this.brillo = 0,
    this.contraste = 0,
    this.saturacion = 0,
    this.nitidez = 0,
  });

  final double brillo;
  final double contraste;
  final double saturacion;
  final double nitidez;

  bool get modificados =>
      brillo != 0 || contraste != 0 || saturacion != 0 || nitidez != 0;

  AjustesFotografia copiar({
    double? brillo,
    double? contraste,
    double? saturacion,
    double? nitidez,
  }) => AjustesFotografia(
    brillo: brillo ?? this.brillo,
    contraste: contraste ?? this.contraste,
    saturacion: saturacion ?? this.saturacion,
    nitidez: nitidez ?? this.nitidez,
  );
}

class SolicitudAjustesFotografia {
  const SolicitudAjustesFotografia(this.bytes, this.ajustes);
  final Uint8List bytes;
  final AjustesFotografia ajustes;
}

/// Se calcula una vez por editor, a tamaño reducido para mover los controles.
Uint8List prepararBaseAjustesFotografia(Uint8List bytes) {
  final decodificada = img.decodeImage(bytes);
  if (decodificada == null) throw StateError('No se pudo abrir la fotografía.');
  var imagen = img.bakeOrientation(decodificada);
  const maximo = 400;
  if (imagen.width > maximo || imagen.height > maximo) {
    imagen = img.copyResize(
      imagen,
      width: imagen.width >= imagen.height ? maximo : null,
      height: imagen.height > imagen.width ? maximo : null,
      interpolation: img.Interpolation.cubic,
    );
  }
  return Uint8List.fromList(img.encodePng(imagen));
}

/// Función pura para compute: no accede a la red, al almacén ni a modelos IA.
Uint8List aplicarAjustesFotografia(SolicitudAjustesFotografia solicitud) {
  final ajustes = solicitud.ajustes;
  if (!ajustes.modificados) return solicitud.bytes;
  final decodificada = img.decodeImage(solicitud.bytes);
  if (decodificada == null) throw StateError('No se pudo abrir la fotografía.');
  final imagen = decodificada.convert(format: img.Format.uint8, numChannels: 4);
  aplicarAjustesSobreImagen(imagen, ajustes);
  return Uint8List.fromList(img.encodePng(imagen));
}

/// Ajustes sin pasos de codificación intermedios, también para la carga rápida.
void aplicarAjustesSobreImagen(img.Image imagen, AjustesFotografia ajustes) {
  if (ajustes.brillo != 0 ||
      ajustes.contraste != 0 ||
      ajustes.saturacion != 0) {
    img.adjustColor(
      imagen,
      brightness: ajustes.brillo == 0
          ? null
          : 1 + ajustes.brillo.clamp(-0.5, 0.5),
      contrast: ajustes.contraste == 0
          ? null
          : 1 + ajustes.contraste.clamp(-0.5, 0.5),
      saturation: ajustes.saturacion == 0
          ? null
          : 1 + ajustes.saturacion.clamp(-1.0, 1.0),
    );
  }
  if (ajustes.nitidez > 0) {
    _realzarNitidez(imagen, ajustes.nitidez.clamp(0.0, 1.0));
  }
}

/// Máscara de enfoque 3×3. Pondera por alfa para no crear bordes negros en PNG.
/// Solo cambia RGB: conserva incluso los valores de alfa semitransparentes.
void _realzarNitidez(img.Image imagen, double intensidad) {
  final origen = img.Image.from(imagen);
  for (final pixel in imagen) {
    if (pixel.a == 0) continue;
    final centro = origen.getPixel(pixel.x, pixel.y);
    var sumaR = 0.0, sumaG = 0.0, sumaB = 0.0, pesos = 0.0;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final vecino = origen.getPixel(
          (pixel.x + dx).clamp(0, origen.width - 1),
          (pixel.y + dy).clamp(0, origen.height - 1),
        );
        final peso = (dx == 0 ? 2 : 1) * (dy == 0 ? 2 : 1) * vecino.a / 255;
        sumaR += vecino.r * peso;
        sumaG += vecino.g * peso;
        sumaB += vecino.b * peso;
        pesos += peso;
      }
    }
    if (pesos == 0) continue;
    pixel
      ..r = (centro.r + intensidad * 2 * (centro.r - sumaR / pesos)).clamp(
        0,
        255,
      )
      ..g = (centro.g + intensidad * 2 * (centro.g - sumaG / pesos)).clamp(
        0,
        255,
      )
      ..b = (centro.b + intensidad * 2 * (centro.b - sumaB / pesos)).clamp(
        0,
        255,
      );
  }
}
