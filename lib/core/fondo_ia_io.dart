import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_litert/native.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

import '../models/imagen.dart';
import 'fondo_ia_modelo.dart';

const _ladoMaximo = 600;
const _pesoMaximo = 300 * 1024;
const _tamanos = [600, 512, 448, 384, 320, 256];

/// Prepara la foto enteramente en el teléfono. ML Kit calcula qué píxeles
/// pertenecen a la persona y Dart compone el PNG con transparencia.
Future<FotoSinFondo> prepararFotoSinFondo({
  required Uint8List bytes,
  required Recorte recorte,
  required bool quitarFondo,
  required String tipoMime,
}) async {
  if (!fondoIaDisponible) {
    throw UnsupportedError(
      'La eliminación de fondo solo está disponible en Android y iOS.',
    );
  }

  final decodificada = img.decodeImage(bytes);
  if (decodificada == null) {
    throw StateError('No se pudo abrir la fotografía.');
  }
  final orientada = img.bakeOrientation(decodificada);
  final cuadrado = _validarRecorte(recorte, orientada);
  final recortada = img.copyCrop(
    orientada,
    x: cuadrado.x,
    y: cuadrado.y,
    width: cuadrado.lado,
    height: cuadrado.lado,
  );
  var preparada = img
      .copyResize(
        recortada,
        width: _ladoMaximo,
        height: _ladoMaximo,
        interpolation: img.Interpolation.cubic,
      )
      .convert(numChannels: 4);

  if (quitarFondo) {
    preparada = await _aplicarMascara(preparada);
  }

  Uint8List? ultimo;
  for (final lado in _tamanos) {
    final salida = lado == _ladoMaximo
        ? preparada
        : img.copyResize(
            preparada,
            width: lado,
            height: lado,
            interpolation: img.Interpolation.cubic,
          );
    final png = Uint8List.fromList(img.encodePng(salida));
    ultimo = png;
    if (png.length <= _pesoMaximo) return FotoSinFondo(png);
  }

  throw StateError(
    'No se pudo reducir la fotografía a 300 KB. '
    'Probá con una imagen más nítida y uniforme. '
    'Último tamaño: ${ultimo?.length ?? 0} bytes.',
  );
}

Future<img.Image> _aplicarMascara(img.Image origen) async {
  if (Platform.isWindows) {
    return _aplicarMascaraWindows(origen);
  }

  final rgba = Uint8List.fromList(
    origen.getBytes(order: img.ChannelOrder.rgba),
  );
  final segmentador = SelfieSegmenter(
    mode: SegmenterMode.single,
    enableRawSizeMask: false,
  );
  SegmentationMask? mascara;
  try {
    mascara = await segmentador.processImage(
      InputImage.fromBitmap(
        bitmap: rgba,
        width: origen.width,
        height: origen.height,
      ),
    );
  } finally {
    await segmentador.close();
  }
  if (mascara == null || mascara.confidences.isEmpty) {
    throw StateError('No se pudo detectar a la persona en la fotografía.');
  }

  // Aunque normalmente ML Kit devuelve una máscara del mismo tamaño, se
  // interpola para tolerar modelos o dispositivos que entreguen tamaño crudo.
  for (var y = 0; y < origen.height; y++) {
    final my = ((y + 0.5) * mascara.height / origen.height - 0.5).round().clamp(
      0,
      mascara.height - 1,
    );
    for (var x = 0; x < origen.width; x++) {
      final mx = ((x + 0.5) * mascara.width / origen.width - 0.5).round().clamp(
        0,
        mascara.width - 1,
      );
      final confianza = mascara.confidences[my * mascara.width + mx].clamp(
        0.0,
        1.0,
      );
      final pixel = origen.getPixel(x, y);
      pixel.a = (pixel.a * confianza).round();
    }
  }
  return origen;
}

/// En Windows ejecuta localmente el modelo oficial de segmentación de personas
/// incluido con la aplicación. No necesita Internet ni envía la fotografía.
Future<img.Image> _aplicarMascaraWindows(img.Image origen) async {
  const ladoModelo = 256;
  final entradaImagen = img.copyResize(
    origen,
    width: ladoModelo,
    height: ladoModelo,
    interpolation: img.Interpolation.cubic,
  );
  final entrada = [
    List.generate(
      ladoModelo,
      (y) => List.generate(ladoModelo, (x) {
        final pixel = entradaImagen.getPixel(x, y);
        return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      }),
    ),
  ];
  final salida = [
    List.generate(
      ladoModelo,
      (_) => List.generate(ladoModelo, (_) => <double>[0]),
    ),
  ];

  final (opciones, delegado) = InterpreterFactory.create(
    const PerformanceConfig.auto(),
    addMediaPipeCustomOps: true,
  );
  Interpreter? interprete;
  try {
    interprete = await Interpreter.fromAsset(
      'assets/models/selfie_segmenter.tflite',
      options: opciones,
    );
    interprete.allocateTensors();
    final formaEntrada = interprete.getInputTensor(0).shape;
    final formaSalida = interprete.getOutputTensor(0).shape;
    if (!_formaCompatible(formaEntrada) || !_formaCompatible(formaSalida)) {
      throw StateError(
        'El modelo de eliminación de fondo no tiene el formato esperado.',
      );
    }
    interprete.run(entrada, salida);
  } finally {
    interprete?.close();
    delegado?.delete();
    opciones.delete();
  }

  for (var y = 0; y < origen.height; y++) {
    final my = ((y + .5) * ladoModelo / origen.height - .5).round().clamp(
      0,
      ladoModelo - 1,
    );
    for (var x = 0; x < origen.width; x++) {
      final mx = ((x + .5) * ladoModelo / origen.width - .5).round().clamp(
        0,
        ladoModelo - 1,
      );
      final confianza = salida[0][my][mx][0].clamp(0.0, 1.0);
      final pixel = origen.getPixel(x, y);
      pixel.a = (pixel.a * confianza).round();
    }
  }
  return origen;
}

bool _formaCompatible(List<int> forma) =>
    forma.length == 4 && forma[0] == 1 && forma[1] == 256 && forma[2] == 256;

({int x, int y, int lado}) _validarRecorte(Recorte recorte, img.Image imagen) {
  if (recorte.ancho <= 0 ||
      recorte.alto <= 0 ||
      recorte.x < 0 ||
      recorte.y < 0 ||
      recorte.x + recorte.ancho > imagen.width ||
      recorte.y + recorte.alto > imagen.height) {
    throw StateError('El recorte de la fotografía no es válido.');
  }
  final lado = math.min(recorte.ancho, recorte.alto);
  return (
    x: recorte.x + (recorte.ancho - lado) ~/ 2,
    y: recorte.y + (recorte.alto - lado) ~/ 2,
    lado: lado,
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
}) async {
  final decodificada = img.decodeImage(bytes);
  if (decodificada == null) {
    throw StateError('No se pudo abrir la imagen del documento.');
  }
  final orientada = img.bakeOrientation(decodificada);
  _validarRecorteLibre(recorte, orientada);
  var preparada = img.copyCrop(
    orientada,
    x: recorte.x,
    y: recorte.y,
    width: recorte.ancho,
    height: recorte.alto,
  );

  final escala = math.min(
    1.0,
    ladoMaximo / math.max(preparada.width, preparada.height),
  );
  if (escala < 1) {
    preparada = img.copyResize(
      preparada,
      width: math.max(1, (preparada.width * escala).round()),
      height: math.max(1, (preparada.height * escala).round()),
      interpolation: img.Interpolation.cubic,
    );
  }
  preparada = preparada.convert(numChannels: 4);
  if (quitarFondo) {
    _quitarFondoUniforme(preparada, intensidad.clamp(0.0, 1.0));
  }
  if (realce > 0) {
    _reforzarTrazos(preparada, realce.clamp(0, 3));
  }

  while (true) {
    final png = Uint8List.fromList(img.encodePng(preparada));
    if (png.length <= pesoMaximo ||
        math.max(preparada.width, preparada.height) <= 128) {
      return ImagenPngPreparada(png);
    }
    preparada = img.copyResize(
      preparada,
      width: math.max(1, (preparada.width * .82).round()),
      height: math.max(1, (preparada.height * .82).round()),
      interpolation: img.Interpolation.cubic,
    );
  }
}

void _validarRecorteLibre(Recorte recorte, img.Image imagen) {
  if (recorte.ancho <= 0 ||
      recorte.alto <= 0 ||
      recorte.x < 0 ||
      recorte.y < 0 ||
      recorte.x + recorte.ancho > imagen.width ||
      recorte.y + recorte.alto > imagen.height) {
    throw StateError('El recorte de la firma o sello no es válido.');
  }
}

void _quitarFondoUniforme(img.Image imagen, double intensidad) {
  final radio = math.max(
    1,
    math.min(
      math.min(imagen.width, imagen.height),
      math.min(imagen.width, imagen.height) ~/ 12,
    ),
  );
  final rojos = <int>[];
  final verdes = <int>[];
  final azules = <int>[];
  final esquinas = [
    (0, 0),
    (imagen.width - radio, 0),
    (0, imagen.height - radio),
    (imagen.width - radio, imagen.height - radio),
  ];
  for (final (inicioX, inicioY) in esquinas) {
    for (var y = inicioY; y < inicioY + radio; y++) {
      for (var x = inicioX; x < inicioX + radio; x++) {
        final pixel = imagen.getPixel(x, y);
        if (pixel.a == 0) continue;
        rojos.add(pixel.r.round());
        verdes.add(pixel.g.round());
        azules.add(pixel.b.round());
      }
    }
  }
  if (rojos.isEmpty) return;
  rojos.sort();
  verdes.sort();
  azules.sort();
  final mitad = rojos.length ~/ 2;
  final fondoR = rojos[mitad];
  final fondoG = verdes[mitad];
  final fondoB = azules[mitad];
  final tolerancia = 45 + intensidad * 105;
  final inicio = tolerancia * .38;

  for (final pixel in imagen) {
    if (pixel.a == 0) continue;
    final dr = pixel.r - fondoR;
    final dg = pixel.g - fondoG;
    final db = pixel.b - fondoB;
    final distancia = math.sqrt(dr * dr + dg * dg + db * db);
    final opacidad = distancia <= inicio
        ? 0.0
        : distancia >= tolerancia
        ? 1.0
        : (distancia - inicio) / (tolerancia - inicio);
    pixel.a = (pixel.a * opacidad).round();
  }
}

void _reforzarTrazos(img.Image imagen, int radio) {
  final origen = img.Image.from(imagen);
  double tinta(img.Pixel pixel) {
    final oscuridad = 765 - pixel.r - pixel.g - pixel.b;
    return pixel.a * oscuridad / 765;
  }

  for (var y = 0; y < imagen.height; y++) {
    for (var x = 0; x < imagen.width; x++) {
      final actual = origen.getPixel(x, y);
      var mejor = actual;
      var mejorTinta = tinta(actual);
      for (var dy = -radio; dy <= radio; dy++) {
        for (var dx = -radio; dx <= radio; dx++) {
          if (dx * dx + dy * dy > radio * radio) continue;
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= origen.width || ny >= origen.height) {
            continue;
          }
          final candidato = origen.getPixel(nx, ny);
          final tintaCandidata = tinta(candidato);
          if (tintaCandidata > mejorTinta) {
            mejor = candidato;
            mejorTinta = tintaCandidata;
          }
        }
      }
      if (mejorTinta > tinta(actual) + 4) {
        imagen.setPixelRgba(x, y, mejor.r, mejor.g, mejor.b, mejor.a);
      }
    }
  }
}

bool get fondoIaDisponible =>
    Platform.isAndroid || Platform.isIOS || Platform.isWindows;

bool get fondoDocumentoDisponible => true;
