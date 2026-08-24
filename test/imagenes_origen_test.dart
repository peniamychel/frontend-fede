import 'package:fede/ui/productores/imagenes_productor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('subir una foto permite usar cámara o galería', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagenesProductor(
              productorId: 1,
              imagenes: const [],
              alCambiar: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Subir foto'));
      await tester.pumpAndSettle();

      expect(find.text('Tomar foto'), findsOneWidget);
      expect(find.text('Abrir la cámara del dispositivo'), findsOneWidget);
      expect(find.text('Elegir de galería'), findsOneWidget);
      expect(find.text('Seleccionar una imagen guardada'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
