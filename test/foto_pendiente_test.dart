import 'dart:math';
import 'dart:typed_data';

import 'package:fede/core/ajustes_fotografia.dart';
import 'package:fede/core/foto_pendiente.dart';
import 'package:fede/models/imagen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('recorta la región elegida y guarda JPEG cuadrado sin ampliar', () {
    final origen = img.Image(width: 140, height: 100);
    img.fill(origen, color: img.ColorRgb8(220, 20, 20));
    img.fillRect(
      origen,
      x1: 40,
      y1: 0,
      x2: 139,
      y2: 99,
      color: img.ColorRgb8(20, 200, 40),
    );
    final bytes = prepararFotoPendiente(
      SolicitudFotoPendiente(
        Uint8List.fromList(img.encodePng(origen)),
        const Recorte(x: 40, y: 0, ancho: 100, alto: 100),
        const AjustesFotografia(),
      ),
    );
    final salida = img.decodeJpg(bytes)!;
    expect(salida.width, 100);
    expect(salida.height, 100);
    expect(salida.getPixel(50, 50).g, greaterThan(180));
    expect(salida.getPixel(50, 50).r, lessThan(40));
    expect(bytes.length, lessThanOrEqualTo(400 * 1024));
  });

  test(
    'foto detallada conserva resolución para editar y pesa hasta 400 KB',
    () {
      final azar = Random(123);
      final origen = img.Image(width: 1800, height: 1800);
      for (final pixel in origen) {
        pixel.setRgb(azar.nextInt(256), azar.nextInt(256), azar.nextInt(256));
      }
      final bytes = prepararFotoPendiente(
        SolicitudFotoPendiente(
          Uint8List.fromList(img.encodeJpg(origen, quality: 95)),
          const Recorte(x: 0, y: 0, ancho: 1800, alto: 1800),
          const AjustesFotografia(),
        ),
      );
      final salida = img.decodeJpg(bytes)!;
      expect(salida.width, salida.height);
      expect(salida.width, greaterThan(600));
      expect(salida.width, lessThanOrEqualTo(1600));
      expect(bytes.length, lessThanOrEqualTo(400 * 1024));
    },
  );

  test('rechaza recortes fuera de la imagen o no cuadrados', () {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 30)),
    );
    for (final recorte in [
      const Recorte(x: 0, y: 0, ancho: 40, alto: 30),
      const Recorte(x: -1, y: 0, ancho: 20, alto: 20),
      const Recorte(x: 20, y: 0, ancho: 30, alto: 30),
      const Recorte(x: 0, y: 0, ancho: 0, alto: 0),
    ]) {
      expect(
        () => prepararFotoPendiente(
          SolicitudFotoPendiente(bytes, recorte, const AjustesFotografia()),
        ),
        throwsStateError,
      );
    }
  });
}
