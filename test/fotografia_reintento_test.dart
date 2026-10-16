import 'dart:async';
import 'dart:io';
import 'package:fede/models/imagen.dart';
import 'package:fede/ui/productores/imagenes_productor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'conserva la imagen ante un fallo y espera confirmación al reintentar',
    (tester) async {
      final bytes = File('test/fixtures/foto-prueba.png').readAsBytesSync();
      final confirmacion = Completer<ImagenSubida>();
      var intentos = 0;
      ImagenSubida? recibida;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  recibida = await showDialog<ImagenSubida>(
                    context: context,
                    builder: (_) => ConfirmarSubidaFoto(
                      bytes: bytes,
                      guardar: () {
                        intentos++;
                        if (intentos == 1) {
                          return Future.error(StateError('Sin conexión'));
                        }
                        return confirmacion.future;
                      },
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar subida'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(recibida, isNull);
      final reintentar = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Reintentar subida'),
          )
          .onPressed!;
      reintentar();
      reintentar(); // Dos clics antes del siguiente frame no duplican la petición.
      await tester.pump();
      expect(
        find.text('Subiendo… esperando confirmación del servidor.'),
        findsOneWidget,
      );
      expect(recibida, isNull);
      final respuesta = ImagenSubida.desdeJson({
        'productorId': 18,
        'original': {
          'tipo': 'ORIGINAL',
          'url': '/foto.png',
          'tipoMime': 'image/png',
          'ancho': 32,
          'alto': 32,
          'tamanoBytes': 300,
        },
        'miniatura': {
          'tipo': 'MINIATURA',
          'url': '/miniatura.png',
          'tipoMime': 'image/png',
          'ancho': 16,
          'alto': 16,
          'tamanoBytes': 100,
        },
      });
      confirmacion.complete(respuesta);
      await tester.pumpAndSettle();
      expect(recibida, same(respuesta));
      expect(intentos, 2);
      expect(find.byType(ConfirmarSubidaFoto), findsNothing);
    },
  );
}
