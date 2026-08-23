import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import '../models/imagen.dart';
import 'fondo_ia_modelo.dart';

@JS('FondoIA.procesar')
external JSPromise<JSString> _procesarFondo(
  JSString imagenDataUrl,
  JSString recorteJson,
  JSBoolean quitarFondo,
);

@JS('FondoIA.procesarDocumento')
external JSPromise<JSString> _procesarDocumento(
  JSString imagenDataUrl,
  JSString parametrosJson,
);

/// Ejecuta MediaPipe en el navegador y devuelve un PNG cuadrado.
Future<FotoSinFondo> prepararFotoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
}) async {
  final dataUrl = 'data:$tipoMime;base64,${base64Encode(bytes)}';
  final parametros = jsonEncode({
    'x': recorte.x,
    'y': recorte.y,
    'ancho': recorte.ancho,
    'alto': recorte.alto,
  });
  final dataUrlResultado = (await _procesarFondo(
    dataUrl.toJS,
    parametros.toJS,
    quitarFondo.toJS,
  ).toDart).toDart;
  final separador = dataUrlResultado.indexOf(',');
  if (separador < 0) {
    throw StateError('El eliminador de fondo devolvió una imagen inválida.');
  }
  return FotoSinFondo(
    Uint8List.fromList(base64Decode(dataUrlResultado.substring(separador + 1))),
  );
}

/// Quita un fondo uniforme claro de una firma o sello y devuelve PNG alfa.
Future<ImagenPngPreparada> prepararDocumentoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
  required double intensidad,
  required int ladoMaximo,
  required int pesoMaximo,
}) async {
  final dataUrl = 'data:$tipoMime;base64,${base64Encode(bytes)}';
  final parametros = jsonEncode({
    'recorte': {
      'x': recorte.x,
      'y': recorte.y,
      'ancho': recorte.ancho,
      'alto': recorte.alto,
    },
    'quitarFondo': quitarFondo,
    'intensidad': intensidad.clamp(0.0, 1.0),
    'ladoMaximo': ladoMaximo,
    'pesoMaximo': pesoMaximo,
  });
  final dataUrlResultado = (await _procesarDocumento(
    dataUrl.toJS,
    parametros.toJS,
  ).toDart).toDart;
  final separador = dataUrlResultado.indexOf(',');
  if (separador < 0) {
    throw StateError('El procesador devolvió una imagen inválida.');
  }
  return ImagenPngPreparada(
    Uint8List.fromList(base64Decode(dataUrlResultado.substring(separador + 1))),
  );
}

bool get fondoIaDisponible => true;

bool get fondoDocumentoDisponible => true;
