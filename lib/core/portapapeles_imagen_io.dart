import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:image/image.dart' as img;

void suprimirMenuNativoImagen() {}

Future<void> copiarImagenPortapapeles(Uint8List bytes) async {
  if (defaultTargetPlatform != TargetPlatform.windows) {
    throw UnsupportedError('Copiar imágenes está disponible en Windows y web.');
  }
  final imagen = img.decodeImage(bytes);
  if (imagen == null) throw StateError('No se pudo abrir la fotografía.');
  final orientada = img.bakeOrientation(imagen);
  final bmp = img.encodeBmp(
    orientada.convert(format: img.Format.uint8, numChannels: 4),
  );
  // CF_DIBV5 recibe el encabezado y los píxeles, sin el encabezado de archivo BMP.
  await const MethodChannel('federa/portapapeles').invokeMethod<void>(
    'copiarImagen',
    {'png': img.encodePng(orientada), 'dib': Uint8List.sublistView(bmp, 14)},
  );
}
