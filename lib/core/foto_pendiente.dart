import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/imagen.dart';
import 'ajustes_fotografia.dart';

class SolicitudFotoPendiente {
  const SolicitudFotoPendiente(this.bytes, this.recorte, this.ajustes);
  final Uint8List bytes;
  final Recorte recorte;
  final AjustesFotografia ajustes;
}

/// Recorte 1:1 y compresión ligera. No carga ni ejecuta ningún modelo de IA.
Uint8List prepararFotoPendiente(SolicitudFotoPendiente solicitud) {
  var imagen = _recortarYAjustar(solicitud);
  // JPEG preserva más resolución que PNG para una fotografía todavía con fondo.
  // Se mantiene la calidad y se estima la reducción por peso para evitar muchas
  // codificaciones sucesivas en los celulares con menos capacidad.
  while (true) {
    final bytes = img.encodeJpg(
      imagen,
      quality: 84,
      chroma: img.JpegChroma.yuv420,
    );
    if (bytes.length <= 400 * 1024) return Uint8List.fromList(bytes);
    if (imagen.width <= 64) {
      throw StateError('No se pudo comprimir esta fotografía.');
    }
    final factor = math.sqrt((400 * 1024) / bytes.length) * .95;
    final lado = math.max(
      64,
      math.min(imagen.width - 1, (imagen.width * factor).floor()),
    );
    imagen = img.copyResize(
      imagen,
      width: lado,
      height: lado,
      interpolation: img.Interpolation.linear,
    );
  }
}

/// El PNG conserva la transparencia y permite al servidor elegir la compresión.
Uint8List prepararEdicionManual(SolicitudFotoPendiente solicitud) =>
    Uint8List.fromList(img.encodePng(_recortarYAjustar(solicitud)));

img.Image _recortarYAjustar(SolicitudFotoPendiente solicitud) {
  final decodificada = img.decodeImage(solicitud.bytes);
  if (decodificada == null) throw StateError('No se pudo abrir la fotografía.');
  final origen = img.bakeOrientation(decodificada);
  final r = solicitud.recorte;
  if (r.ancho <= 0 ||
      r.ancho != r.alto ||
      r.x < 0 ||
      r.y < 0 ||
      r.x + r.ancho > origen.width ||
      r.y + r.alto > origen.height) {
    throw StateError(
      'El recorte debe ser cuadrado y estar dentro de la fotografía.',
    );
  }
  var imagen = img.copyCrop(
    origen,
    x: r.x,
    y: r.y,
    width: r.ancho,
    height: r.alto,
  );
  if (imagen.width > 1600) {
    imagen = img.copyResize(
      imagen,
      width: 1600,
      height: 1600,
      interpolation: img.Interpolation.linear,
    );
  }
  if (solicitud.ajustes.modificados) {
    aplicarAjustesSobreImagen(imagen, solicitud.ajustes);
  }
  return imagen;
}
