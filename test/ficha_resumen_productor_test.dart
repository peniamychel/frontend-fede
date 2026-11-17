import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fede/models/productor.dart';
import 'package:fede/ui/productores/ficha_resumen_productor.dart';

ProductorDetalle ejemplo({bool largo = false}) => ProductorDetalle.desdeJson({
  'productor': {
    'id': 42,
    'nombres': largo ? 'MARÍA DEL CARMEN ALEJANDRA GUADALUPE' : 'MARÍA',
    'apellidos': largo
        ? 'NOGALES FERNÁNDEZ DE LA CRUZ PEREDO'
        : 'NOGALES PEREDO',
    'ci': '6408786',
    'centralNombre': '13 DE JUNIO',
    'sindicatoNombre': largo
        ? 'SINDICATO AGRARIO DE PRODUCTORES PRIMERO DE MAYO DE CARRASCO TROPICAL'
        : '1RO DE MAYO',
    'numeroLote': '11 A',
  },
});

void main() {
  testWidgets(
    'genera PNG con foto completa, fondo claro y tamaño para compartir',
    (tester) async {
      final fuente = img.Image(width: 160, height: 320);
      img.fill(fuente, color: img.ColorRgb8(200, 40, 30));
      final bytes = await tester.runAsync(
        () => generarFichaResumenProductor(
          ejemplo(),
          fotografia: Uint8List.fromList(img.encodePng(fuente)),
        ),
      );
      final imagen = img.decodePng(bytes!);
      expect(imagen, isNotNull);
      expect(imagen!.width, 1080);
      expect(imagen.height, greaterThan(700));
      expect(imagen.getPixel(0, 0).r, 255);
      expect(imagen.getPixel(156, 300).r, 200);
      expect(imagen.getPixel(156, 300).g, 40);
      // Contain: el retrato vertical conserva márgenes a sus lados.
      expect(imagen.getPixel(56, 300).r, 240);
      expect(imagen.getPixel(56, 300).g, 243);
    },
  );

  testWidgets(
    'adapta la altura a nombres largos y admite ficha sin fotografía',
    (tester) async {
      final corto = await tester.runAsync(
        () => generarFichaResumenProductor(ejemplo()),
      );
      final largo = await tester.runAsync(
        () => generarFichaResumenProductor(ejemplo(largo: true)),
      );
      expect(
        img.decodePng(largo!)!.height,
        greaterThan(img.decodePng(corto!)!.height),
      );
      const destino = String.fromEnvironment('FICHA_RESUMEN_PREVIA');
      if (destino.isNotEmpty) {
        await tester.runAsync(() => File(destino).writeAsBytes(largo));
      }
    },
  );
}
