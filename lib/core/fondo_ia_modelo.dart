import 'dart:typed_data';

/// PNG producido localmente antes de subir una imagen al servidor.
class ImagenPngPreparada {
  const ImagenPngPreparada(this.bytes);

  final Uint8List bytes;

  int get tamanoBytes => bytes.length;
}

/// PNG cuadrado de una fotografía de credencial.
class FotoSinFondo extends ImagenPngPreparada {
  const FotoSinFondo(super.bytes);
}
