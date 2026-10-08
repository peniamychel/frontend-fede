import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/api_config.dart';

/// Evita depender de una conexión HTTP para comprobar una miniatura nueva.
Future<void> prepararMiniaturaPrueba(WidgetTester tester, String url) async {
  await tester.runAsync(() async {
    final grabador = ui.PictureRecorder();
    ui.Canvas(grabador).drawColor(Colors.blue, ui.BlendMode.src);
    final dibujo = grabador.endRecording();
    final imagen = await dibujo.toImage(32, 32);
    dibujo.dispose();
    PaintingBinding.instance.imageCache.putIfAbsent(
      NetworkImage(ApiConfig.urlAbsoluta(url)),
      () =>
          OneFrameImageStreamCompleter(Future.value(ImageInfo(image: imagen))),
    );
  });
}
