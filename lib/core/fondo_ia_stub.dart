import 'dart:typed_data';

import '../models/imagen.dart';
import 'fondo_ia_modelo.dart';

/// Implementación para plataformas distintas de la web.
///
/// La app actual se usa por web. Android podrá incorporar ML Kit en una fase
/// posterior sin cambiar la interfaz que consume esta clase.
Future<FotoSinFondo> prepararFotoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
}) {
  throw UnsupportedError(
    'La eliminación de fondo está disponible por ahora en la versión web.',
  );
}

Future<ImagenPngPreparada> prepararDocumentoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
  required double intensidad,
  required int realce,
  required int ladoMaximo,
  required int pesoMaximo,
}) {
  throw UnsupportedError(
    'La preparación transparente está disponible por ahora en la versión web.',
  );
}

bool get fondoIaDisponible => false;

bool get fondoDocumentoDisponible => false;
