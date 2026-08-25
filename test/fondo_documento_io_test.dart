import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:fede/core/fondo_ia.dart';
import 'package:fede/models/imagen.dart';

void main() {
  test('firma o sello se prepara localmente como PNG transparente', () async {
    final origen = img.Image(width: 120, height: 60, numChannels: 4);
    img.fill(origen, color: img.ColorRgba8(250, 250, 245, 255));
    for (var y = 25; y < 35; y++) {
      for (var x = 20; x < 100; x++) {
        origen.setPixelRgba(x, y, 20, 30, 40, 255);
      }
    }

    final resultado = await prepararDocumentoSinFondo(
      bytes: Uint8List.fromList(img.encodePng(origen)),
      recorte: const Recorte(x: 0, y: 0, ancho: 120, alto: 60),
      quitarFondo: true,
      tipoMime: 'image/png',
      intensidad: .55,
      ladoMaximo: 600,
      pesoMaximo: 200 * 1024,
    );

    final preparada = img.decodePng(resultado.bytes)!;
    expect(preparada.getPixel(0, 0).a, 0);
    expect(preparada.getPixel(50, 30).a, greaterThan(0));
    expect(resultado.bytes.length, lessThanOrEqualTo(200 * 1024));
  });
}
