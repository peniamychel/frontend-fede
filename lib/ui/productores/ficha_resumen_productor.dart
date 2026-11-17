import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/productor.dart';
import '../../models/diseno_credencial.dart';
import '../credenciales/fuentes_bajo_demanda.dart';

/// Imagen independiente del tamaño de la pantalla, legible al enviar por chat.
Future<Uint8List> generarFichaResumenProductor(
  ProductorDetalle detalle, {
  Uint8List? fotografia,
}) async {
  await cargarFuenteCredencial(FuenteCredencial.roboto);
  const ancho = 1080;
  const margen = 48.0;
  const tinta = Color(0xFF172823);
  const verde = Color(0xFF176B4D);
  final borde = Paint()
    ..color = const Color(0xFF91AA9E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final grabador = ui.PictureRecorder();
  final lienzo = Canvas(grabador);
  final textos = <TextPainter>[];
  ui.Image? foto;
  ui.Picture? dibujo;
  ui.Image? imagen;

  double texto(
    String valor,
    double x,
    double y,
    double ancho, {
    double tamano = 64,
    Color color = tinta,
    FontWeight peso = FontWeight.w600,
  }) {
    final pintor = TextPainter(
      text: TextSpan(
        text: valor,
        style: TextStyle(
          fontFamily: FuenteCredencial.roboto.familiaFlutter,
          fontSize: tamano,
          color: color,
          fontWeight: peso,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    )..layout(maxWidth: ancho);
    textos.add(pintor);
    pintor.paint(lienzo, Offset(x, y));
    return pintor.height;
  }

  double dato(String etiqueta, String? valor, double y, double ancho) {
    const relleno = 24.0;
    final etiquetaAlto = texto(
      etiqueta,
      margen + relleno,
      y + relleno,
      ancho - relleno * 2,
      tamano: 40,
      color: const Color(0xFF536660),
      peso: FontWeight.w500,
    );
    final limpio = valor?.trim() ?? '';
    final alto = texto(
      limpio.isEmpty ? 'Sin dato' : limpio,
      margen + relleno,
      y + relleno + etiquetaAlto + 8,
      ancho - relleno * 2,
    );
    final altoRecuadro = relleno * 2 + etiquetaAlto + 8 + alto;
    lienzo.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(margen, y, ancho, altoRecuadro),
        const Radius.circular(24),
      ),
      borde,
    );
    return y + altoRecuadro + 20;
  }

  try {
    if (fotografia != null) {
      final codec = await ui.instantiateImageCodec(fotografia);
      try {
        foto = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    }

    // El fondo se pinta después detrás del contenido para ajustar su altura
    // a nombres, apellidos y sindicatos largos sin recortar ningún dato.
    lienzo.saveLayer(null, Paint());
    texto(
      'FICHA DE DATOS DEL PRODUCTOR',
      margen,
      margen,
      ancho - margen * 2,
      tamano: 46,
      color: verde,
      peso: FontWeight.w700,
    );
    lienzo.drawRect(
      const Rect.fromLTWH(margen, 122, 984, 3),
      Paint()..color = verde,
    );

    const marcoFoto = Rect.fromLTWH(margen, 160, 216, 240);
    final bordeFoto = RRect.fromRectAndRadius(
      marcoFoto,
      const Radius.circular(16),
    );
    lienzo.drawRRect(bordeFoto, Paint()..color = const Color(0xFFF0F3F2));
    if (foto case final actual?) {
      lienzo.save();
      lienzo.clipRRect(bordeFoto);
      paintImage(
        canvas: lienzo,
        rect: marcoFoto.deflate(8),
        image: actual,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
      lienzo.restore();
    } else {
      texto(
        'Sin\nfotografía',
        72,
        236,
        168,
        tamano: 36,
        color: const Color(0xFF536660),
        peso: FontWeight.w400,
      );
    }
    lienzo.drawRRect(bordeFoto, borde);

    final p = detalle.productor;
    var y = marcoFoto.bottom + 32;
    y = dato(
      'Nombres',
      p.nombresCorregidos ?? p.nombres,
      y,
      ancho - margen * 2,
    );
    y = dato(
      'Apellidos',
      p.apellidosCorregidos ?? p.apellidos,
      y,
      ancho - margen * 2,
    );
    final lotes = detalle.lotes
        .map((l) => l.codigo)
        .where((l) => l.trim().isNotEmpty)
        .join(', ');
    y = dato('Cédula de identidad', p.ci, y, ancho - margen * 2);
    y = dato(
      'N.° de lote',
      lotes.isEmpty ? p.numeroLote : lotes,
      y,
      ancho - margen * 2,
    );
    y = dato('Central', p.centralNombre, y, ancho - margen * 2);
    y = dato('Sindicato', p.sindicatoNombre, y, ancho - margen * 2);
    final alto = (y + 20).ceil();
    lienzo.drawRect(
      Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
      Paint()
        ..color = Colors.white
        ..blendMode = BlendMode.dstOver,
    );
    lienzo.restore();
    dibujo = grabador.endRecording();
    imagen = await dibujo.toImage(ancho, alto);
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw StateError('No se pudo generar la ficha de datos.');
    return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } finally {
    if (grabador.isRecording) grabador.endRecording().dispose();
    for (final pintor in textos) {
      pintor.dispose();
    }
    imagen?.dispose();
    dibujo?.dispose();
    foto?.dispose();
  }
}
