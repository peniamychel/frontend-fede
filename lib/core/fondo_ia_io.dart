import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

import '../models/imagen.dart';
import 'fondo_ia_modelo.dart';

const _ladoMaximo = 600;
const _pesoMaximo = 300 * 1024;
const _tamanos = [600, 512, 448, 384, 320, 256];

/// Prepara la foto enteramente en el teléfono. ML Kit calcula qué píxeles
/// pertenecen a la persona y Dart compone el PNG con transparencia.
Future<FotoSinFondo> prepararFotoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
}) async {
  if (!fondoIaDisponible) {
    throw UnsupportedError(
      'La eliminación de fondo solo está disponible en Android y iOS.',
    );
  }

  final decodificada = img.decodeImage(bytes);
  if (decodificada == null) {
    throw StateError('No se pudo abrir la fotografía.');
  }
  final orientada = img.bakeOrientation(decodificada);
  final cuadrado = _validarRecorte(recorte, orientada);
  final recortada = img.copyCrop(
    orientada,
    x: cuadrado.x,
    y: cuadrado.y,
    width: cuadrado.lado,
    height: cuadrado.lado,
  );
  var preparada = img
      .copyResize(
        recortada,
        width: _ladoMaximo,
        height: _ladoMaximo,
        interpolation: img.Interpolation.cubic,
      )
      .convert(numChannels: 4);

  if (quitarFondo) {
    preparada = await _aplicarMascara(preparada);
  }

  Uint8List? ultimo;
  for (final lado in _tamanos) {
    final salida = lado == _ladoMaximo
        ? preparada
        : img.copyResize(
            preparada,
            width: lado,
            height: lado,
            interpolation: img.Interpolation.cubic,
          );
    final png = Uint8List.fromList(img.encodePng(salida));
    ultimo = png;
    if (png.length <= _pesoMaximo) return FotoSinFondo(png);
  }

  throw StateError(
    'No se pudo reducir la fotografía a 300 KB. '
    'Probá con una imagen más nítida y uniforme. '
    'Último tamaño: ${ultimo?.length ?? 0} bytes.',
  );
}

Future<img.Image> _aplicarMascara(img.Image origen) async {
  final rgba = Uint8List.fromList(
    origen.getBytes(order: img.ChannelOrder.rgba),
  );
  final segmentador = SelfieSegmenter(
    mode: SegmenterMode.single,
    enableRawSizeMask: false,
  );
  SegmentationMask? mascara;
  try {
    mascara = await segmentador.processImage(
      InputImage.fromBitmap(
        bitmap: rgba,
        width: origen.width,
        height: origen.height,
      ),
    );
  } finally {
    await segmentador.close();
  }
  if (mascara == null || mascara.confidences.isEmpty) {
    throw StateError('No se pudo detectar a la persona en la fotografía.');
  }

  // Aunque normalmente ML Kit devuelve una máscara del mismo tamaño, se
  // interpola para tolerar modelos o dispositivos que entreguen tamaño crudo.
  for (var y = 0; y < origen.height; y++) {
    final my = ((y + 0.5) * mascara.height / origen.height - 0.5)
        .round()
        .clamp(0, mascara.height - 1);
    for (var x = 0; x < origen.width; x++) {
      final mx = ((x + 0.5) * mascara.width / origen.width - 0.5)
          .round()
          .clamp(0, mascara.width - 1);
      final confianza = mascara.confidences[my * mascara.width + mx]
          .clamp(0.0, 1.0);
      final pixel = origen.getPixel(x, y);
      pixel.a = (pixel.a * confianza).round();
    }
  }
  return origen;
}

({int x, int y, int lado}) _validarRecorte(
  Recorte recorte,
  img.Image imagen,
) {
  if (recorte.ancho <= 0 ||
      recorte.alto <= 0 ||
      recorte.x < 0 ||
      recorte.y < 0 ||
      recorte.x + recorte.ancho > imagen.width ||
      recorte.y + recorte.alto > imagen.height) {
    throw StateError('El recorte de la fotografía no es válido.');
  }
  final lado = math.min(recorte.ancho, recorte.alto);
  return (
    x: recorte.x + (recorte.ancho - lado) ~/ 2,
    y: recorte.y + (recorte.alto - lado) ~/ 2,
    lado: lado,
  );
}

Future<ImagenPngPreparada> prepararDocumentoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
  required double intensidad,
  required int ladoMaximo,
  required int pesoMaximo,
}) {
  throw UnsupportedError(
    'La preparación transparente de firmas y sellos está disponible por '
    'ahora en la versión web.',
  );
}

bool get fondoIaDisponible => Platform.isAndroid || Platform.isIOS;

bool get fondoDocumentoDisponible => false;
