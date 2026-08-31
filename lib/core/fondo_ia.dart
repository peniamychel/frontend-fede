import 'dart:typed_data';

import '../models/imagen.dart';
import 'fondo_ia_modelo.dart';
import 'fondo_ia_stub.dart'
    if (dart.library.io) 'fondo_ia_io.dart'
    if (dart.library.js_interop) 'fondo_ia_web.dart'
    as plataforma;

export 'fondo_ia_modelo.dart';

Future<FotoSinFondo> prepararFotoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
}) => plataforma.prepararFotoSinFondo(
  bytes: bytes,
  recorte: recorte,
  quitarFondo: quitarFondo,
  tipoMime: tipoMime,
);

Future<ImagenPngPreparada> prepararDocumentoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
  required double intensidad,
  required int realce,
  required int ladoMaximo,
  required int pesoMaximo,
}) => plataforma.prepararDocumentoSinFondo(
  bytes: bytes,
  recorte: recorte,
  quitarFondo: quitarFondo,
  tipoMime: tipoMime,
  intensidad: intensidad,
  realce: realce,
  ladoMaximo: ladoMaximo,
  pesoMaximo: pesoMaximo,
);

bool get fondoIaDisponible => plataforma.fondoIaDisponible;

bool get fondoDocumentoDisponible => plataforma.fondoDocumentoDisponible;
