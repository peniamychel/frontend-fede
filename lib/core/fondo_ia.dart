import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import '../models/imagen.dart';
import 'ajustes_fotografia.dart';
import 'fondo_ia_modelo.dart';
import 'fondo_ia_stub.dart'
    if (dart.library.io) 'fondo_ia_io.dart'
    if (dart.library.js_interop) 'fondo_ia_web.dart'
    as plataforma;

export 'fondo_ia_modelo.dart';

Future<Uint8List> procesarFotoProductor({
  required Uint8List bytes,
  required Recorte recorte,
  required String tipoMime,
  required AjustesFotografia ajustes,
}) async {
  final preparada = await prepararFotoSinFondo(
    bytes: bytes,
    recorte: recorte,
    quitarFondo: true,
    tipoMime: tipoMime,
  );
  if (!ajustes.modificados) return preparada.bytes;
  return compute(
    aplicarAjustesFotografia,
    SolicitudAjustesFotografia(preparada.bytes, ajustes),
  );
}

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
