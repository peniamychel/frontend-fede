import 'dart:typed_data';

import 'package:fede/core/ajustes_fotografia.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List png(img.Image imagen) => Uint8List.fromList(img.encodePng(imagen));

void main() {
  test('sin ajustes conserva exactamente los bytes originales', () {
    final original = png(img.Image(width: 4, height: 3, numChannels: 4));
    expect(
      aplicarAjustesFotografia(
        SolicitudAjustesFotografia(original, const AjustesFotografia()),
      ),
      same(original),
    );
  });

  test('brillo y contraste cambian los colores sin modificar el alfa', () {
    final original = img.Image(width: 3, height: 1, numChannels: 4)
      ..setPixelRgba(0, 0, 40, 60, 80, 0)
      ..setPixelRgba(1, 0, 100, 120, 140, 128)
      ..setPixelRgba(2, 0, 180, 200, 220, 255);
    final bytes = png(original);
    final brillante = img.decodePng(
      aplicarAjustesFotografia(
        SolicitudAjustesFotografia(bytes, const AjustesFotografia(brillo: 0.3)),
      ),
    )!;
    final contraste = img.decodePng(
      aplicarAjustesFotografia(
        SolicitudAjustesFotografia(
          bytes,
          const AjustesFotografia(contraste: 0.3),
        ),
      ),
    )!;
    expect(brillante.getPixel(1, 0).r, greaterThan(100));
    expect(contraste.getPixel(2, 0).r, greaterThan(180));
    expect(contraste.getPixel(0, 0).r, lessThan(40));
    for (final resultado in [brillante, contraste]) {
      expect(resultado.width, original.width);
      expect(resultado.height, original.height);
      for (var x = 0; x < original.width; x++) {
        expect(resultado.getPixel(x, 0).a, original.getPixel(x, 0).a);
      }
    }
    expect(original.getPixel(1, 0).r, 100);
  });

  test('saturación mínima genera grises y conserva transparencia', () {
    final original = img.Image(width: 1, height: 1, numChannels: 4)
      ..setPixelRgba(0, 0, 170, 80, 30, 93);
    final gris = img
        .decodePng(
          aplicarAjustesFotografia(
            SolicitudAjustesFotografia(
              png(original),
              const AjustesFotografia(saturacion: -1),
            ),
          ),
        )!
        .getPixel(0, 0);
    expect(gris.r, gris.g);
    expect(gris.g, gris.b);
    expect(gris.a, 93);
  });

  test(
    'nitidez realza detalle sin volver opaco el fondo ni crear halos negros',
    () {
      final original = img.Image(width: 5, height: 5, numChannels: 4);
      img.fill(original, color: img.ColorRgba8(100, 100, 100, 128));
      original.setPixelRgba(2, 2, 140, 140, 140, 200);
      final salida = img.decodePng(
        aplicarAjustesFotografia(
          SolicitudAjustesFotografia(
            png(original),
            const AjustesFotografia(nitidez: 1),
          ),
        ),
      )!;
      expect(salida.getPixel(2, 2).r, greaterThan(140));
      for (final p in salida) {
        expect(p.a, original.getPixel(p.x, p.y).a);
      }

      final borde = img.Image(width: 3, height: 3, numChannels: 4)
        ..setPixelRgba(1, 1, 100, 150, 200, 128);
      final sinHalo = img.decodePng(
        aplicarAjustesFotografia(
          SolicitudAjustesFotografia(
            png(borde),
            const AjustesFotografia(nitidez: 1),
          ),
        ),
      )!;
      expect(sinHalo.getPixel(1, 1).r, 100);
      expect(sinHalo.getPixel(1, 1).g, 150);
      expect(sinHalo.getPixel(1, 1).b, 200);
      expect(sinHalo.getPixel(0, 0).a, 0);
    },
  );

  test(
    'vista previa reduce el tamaño conservando proporción y archivo original',
    () {
      final original = img.Image(width: 800, height: 1200, numChannels: 4);
      final bytes = png(original);
      final salida = img.decodePng(prepararBaseAjustesFotografia(bytes))!;
      expect(salida.height, 400);
      expect(salida.width / salida.height, closeTo(800 / 1200, 0.01));
      expect(img.decodePng(bytes)!.height, 1200);
    },
  );

  test('cada ajuste parte del mismo original y no acumula filtros', () {
    final original = img.Image(width: 3, height: 3, numChannels: 4);
    img.fill(original, color: img.ColorRgba8(90, 100, 110, 160));
    final bytes = png(original);
    const ajustes = AjustesFotografia(
      brillo: 0.2,
      contraste: 0.1,
      nitidez: 0.3,
    );
    final primero = aplicarAjustesFotografia(
      SolicitudAjustesFotografia(bytes, ajustes),
    );
    final segundo = aplicarAjustesFotografia(
      SolicitudAjustesFotografia(bytes, ajustes),
    );
    expect(primero, orderedEquals(segundo));
    expect(
      aplicarAjustesFotografia(
        SolicitudAjustesFotografia(bytes, const AjustesFotografia()),
      ),
      same(bytes),
    );
  });
}
