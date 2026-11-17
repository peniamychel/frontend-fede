import 'dart:typed_data' show Endian;

import 'package:fede/core/api_client.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/edicion_fotos_sindicato_pagina.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/imagenes_productor.dart';
import 'package:fede/ui/productores/recortador_imagen.dart';
import 'package:fede/ui/sesion_scope.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const _sindicato = Sindicato(
  id: 7,
  nombre: '1RO DE MAYO',
  centralId: 3,
  centralNombre: '13 DE JUNIO',
);

void main() {
  testWidgets('copia la foto original al portapapeles con clic derecho', (
    tester,
  ) async {
    const canal = MethodChannel('federa/portapapeles');
    final mensajero = tester.binding.defaultBinaryMessenger;
    Uint8List? png;
    mensajero.setMockMethodCallHandler(canal, (llamada) async {
      expect(llamada.method, 'copiarImagen');
      final argumentos = llamada.arguments as Map;
      png = argumentos['png'] as Uint8List;
      final dib = argumentos['dib'] as Uint8List;
      expect(ByteData.sublistView(dib).getUint32(0, Endian.little), 124);
      return null;
    });
    addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
    final api = _ApiFotos();
    await _abrir(tester, api);
    await _abrirMenuOriginal(tester);
    expect(find.text('Reemplazar imagen'), findsOneWidget);
    await tester.tap(find.text('Copiar imagen'));
    await _esperarFoto(tester);

    final copiada = img.decodePng(png!)!;
    expect(copiada.width, 32);
    expect(copiada.getPixel(0, 0).a, 180);
    expect(find.text('Imagen copiada'), findsOneWidget);
    expect(api.guardados, isEmpty);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('reemplaza la foto original desde el recortador existente', (
    tester,
  ) async {
    final api = _ApiFotos(extensionAna: 'jpg');
    final selector = _SelectorReemplazo();
    await _abrir(
      tester,
      api,
      pagina: EdicionFotosSindicatoPagina(
        sindicato: _sindicato,
        selectorImagenes: selector,
      ),
    );
    await _abrirMenuOriginal(tester);
    await tester.tap(find.text('Reemplazar imagen'));
    await _esperarFoto(tester);
    expect(selector.origen, ImageSource.gallery);
    expect(find.text('Recortar y subir'), findsOneWidget);
    expect(api.guardados, isEmpty);

    await tester.tap(find.text('Subir sin procesar'));
    for (var i = 0; i < 10 && api.guardados.isEmpty; i++) {
      await _esperarFoto(tester);
    }
    await _esperarFoto(tester);
    expect(find.byType(ConfirmarSubidaFoto), findsNothing);
    expect(api.guardados, ['/productores/5/imagenes']);
    expect(api.origen, '/api/v1/archivos/ana-original.jpg');
    expect(api.fondoProcesado, 'false');
    expect(img.decodeJpg(api.bytesGuardados!)!.width, 48);
    expect(api.descargas, contains('/api/v1/archivos/editada.jpg'));
    expect(find.text('Edición de fotos').hitTestable(), findsOneWidget);
    expect(find.text('1RO DE MAYO · 1 de 2'), findsOneWidget);
  });

  testWidgets('la rueda desplaza la cinta y las flechas cambian la foto', (
    tester,
  ) async {
    final api = _ApiFotos(fotosAdicionales: 15);
    await _abrir(tester, api);
    final cinta = find.byType(ListView);
    final controlador = tester.widget<ListView>(cinta).controller!;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(cinta),
        scrollDelta: const Offset(0, 230),
      ),
    );
    await tester.pump();
    expect(controlador.offset, greaterThan(0));
    expect(find.text('ANA ALVAREZ'), findsOneWidget);
    expect(api.guardados, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _esperarFoto(tester);
    expect(find.text('JUAN ZAMORA'), findsOneWidget);
    final recargar = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('Recargar foto'),
    );
    await tester.tap(recargar);
    await _esperarFoto(tester);
    expect(api.paginas, [0, 1, 0, 1]);
    expect(find.text('JUAN ZAMORA'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _esperarFoto(tester);
    expect(find.text('ANA ALVAREZ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un operador no puede cargar el carrusel', (tester) async {
    final api = _ApiFotos();
    await _abrir(tester, api, administrador: false);
    expect(find.text('Disponible solo para administradores'), findsOneWidget);
    expect(api.paginas, isEmpty);
  });

  testWidgets('procesa un JPG aunque no se cambie el recorte', (tester) async {
    final api = _ApiFotos(extensionAna: 'JPG');
    final procesada = img.Image(width: 32, height: 32, numChannels: 4);
    procesada.setPixelRgba(16, 16, 100, 110, 120, 255);
    var llamadas = 0;
    await _abrir(
      tester,
      api,
      pagina: EdicionFotosSindicatoPagina(
        sindicato: _sindicato,
        procesarFoto:
            ({
              required bytes,
              required recorte,
              required tipoMime,
              required ajustes,
            }) async {
              llamadas++;
              expect(img.decodeJpg(bytes), isNotNull);
              expect(tipoMime, 'image/jpeg');
              expect(recorte.ancho, 32);
              expect(ajustes.modificados, isFalse);
              return img.encodePng(procesada);
            },
      ),
    );
    final boton = find.widgetWithText(FilledButton, 'Procesar y guardar');
    expect(boton, findsNothing);
    await tester.tap(find.byTooltip('Foto siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('¿Procesar esta foto?'), findsOneWidget);
    await tester.tap(boton);
    await _esperarFoto(tester);

    expect(llamadas, 1);
    expect(api.guardados, ['/productores/5/imagenes/edicion-manual']);
    expect(api.origen, '/api/v1/archivos/ana-original.JPG');
    expect(api.fondoProcesado, 'true');
    final guardada = img.decodePng(api.bytesGuardados!)!;
    expect(guardada.getPixel(0, 0).a, 0);
    expect(guardada.getPixel(16, 16).a, 255);
    expect(boton, findsNothing);
    expect(find.text('Foto guardada'), findsOneWidget);
    expect(find.text('JUAN ZAMORA'), findsOneWidget);
  });

  testWidgets('si falla el procesamiento se conserva la foto original', (
    tester,
  ) async {
    final api = _ApiFotos(extensionAna: 'jpg');
    await _abrir(
      tester,
      api,
      pagina: EdicionFotosSindicatoPagina(
        sindicato: _sindicato,
        procesarFoto:
            ({
              required bytes,
              required recorte,
              required tipoMime,
              required ajustes,
            }) async {
              throw StateError('No se pudo quitar el fondo.');
            },
      ),
    );
    final boton = find.widgetWithText(FilledButton, 'Procesar y guardar');
    await tester.tap(find.byTooltip('Foto siguiente'));
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await _esperarFoto(tester);

    expect(api.guardados, isEmpty);
    expect(find.text('ANA ALVAREZ'), findsOneWidget);
    expect(find.textContaining('No se pudo quitar el fondo.'), findsOneWidget);
    await tester.tap(find.byTooltip('Foto siguiente'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
    await tester.tap(find.text('Omitir'));
    await _esperarFoto(tester);
    expect(find.text('JUAN ZAMORA'), findsOneWidget);
    expect(api.guardados, isEmpty);
  });

  testWidgets(
    'un guardado fallido impide cambiar de foto y conserva el ajuste',
    (tester) async {
      final api = _ApiFotos(fallaGuardado: true);
      await _abrir(tester, api);
      tester.widget<Slider>(find.byType(Slider).first).onChanged!(.2);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      for (var i = 0; i < 30 && api.guardados.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await _esperarFoto(tester);
      expect(api.guardados, ['/productores/5/imagenes/edicion-manual']);
      expect(find.text('ANA ALVAREZ'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider).first).value, .2);
      expect(find.text('No se pudo guardar'), findsOneWidget);
    },
  );

  for (final tamano in [
    const Size(390, 844),
    const Size(600, 960),
    const Size(1200, 800),
  ]) {
    testWidgets('carrusel y guardado del productor seleccionado en $tamano', (
      tester,
    ) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiFotos();
      await _abrir(tester, api);
      expect(api.paginas, [0, 1]);
      expect(find.text('ANA ALVAREZ'), findsOneWidget);
      expect(find.text('1RO DE MAYO · 1 de 2'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Edición'), findsOneWidget);
      final original = find.text('Original');
      if (tamano.width < 600) {
        await tester.tap(original);
        await tester.pump();
        await tester.tap(find.text('Edición'));
        await tester.pump();
      } else {
        expect(
          tester.getCenter(original).dx,
          lessThan(tester.getCenter(find.text('Edición')).dx),
        );
      }

      tester
          .widget<RecortadorImagen>(find.byType(RecortadorImagen))
          .alCambiar(const Recorte(x: 0, y: 0, ancho: 32, alto: 32));
      tester
          .widget<RecortadorImagen>(find.byType(RecortadorImagen))
          .alCambiar(const Recorte(x: 2, y: 2, ancho: 24, alto: 24));
      await tester.pump();
      await tester.tap(find.byTooltip('Foto siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('¿Descartar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('ANA ALVAREZ'), findsOneWidget);
      expect(api.guardados, isEmpty);

      await tester.tap(find.byTooltip('Foto siguiente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Descartar'));
      await _esperarFoto(tester);
      expect(find.text('JUAN ZAMORA'), findsOneWidget);
      final editor = tester.widget<RecortadorImagen>(
        find.byType(RecortadorImagen),
      );
      editor.alCambiar(const Recorte(x: 0, y: 0, ancho: 32, alto: 32));
      editor.alCambiar(const Recorte(x: 4, y: 4, ancho: 20, alto: 20));
      tester.widget<Slider>(find.byType(Slider).first).onChanged!(.2);
      await tester.pump();
      expect(find.text('Restablecer'), findsNothing);
      expect(find.text('Guardar cambios'), findsNothing);
      if (tamano.width >= 600) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      } else {
        await tester.tap(find.byTooltip('Foto anterior'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final guardarDialogo = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Guardar cambios'),
      );
      expect(tester.widget<FilledButton>(guardarDialogo).autofocus, isTrue);
      expect(api.guardados, isEmpty);
      if (tamano.width >= 600) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        await tester.tap(guardarDialogo);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      for (var i = 0; i < 30 && api.guardados.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await _esperarFoto(tester);
      expect(api.guardados, ['/productores/9/imagenes/edicion-manual']);
      expect(api.origen, '/api/v1/archivos/juan-original.png');
      expect(api.fondoProcesado, isNull);
      final guardada = img.decodePng(api.bytesGuardados!)!;
      expect(guardada.width, 20);
      expect(guardada.height, 20);
      expect(guardada.getPixel(0, 0).a, 180);
      expect(guardada.getPixel(0, 0).r, greaterThan(100));
      expect(find.text('Foto guardada'), findsOneWidget);
      expect(find.text('ANA ALVAREZ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _abrir(
  WidgetTester tester,
  _ApiFotos api, {
  bool administrador = true,
  EdicionFotosSindicatoPagina pagina = const EdicionFotosSindicatoPagina(
    sindicato: _sindicato,
  ),
}) async {
  final sesion = SesionControlador(AutenticacionRepository(api))
    ..sesion = Sesion(
      token: 'prueba',
      usuario: 'prueba',
      nombreCompleto: 'Prueba',
      rol: administrador ? 'ADMIN' : 'OPERADOR',
      roles: const {},
      permisos: const {'FOTOS_PRODUCTORES_EDITAR'},
      expiraEn: DateTime(2099),
    );
  addTearDown(api.cerrar);
  addTearDown(sesion.dispose);
  await tester.pumpWidget(
    SesionScope(
      controlador: sesion,
      child: PadronScope(
        padron: Padron(api: api),
        child: MaterialApp(home: pagina),
      ),
    ),
  );
  await _esperarFoto(tester);
}

Future<void> _esperarFoto(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
  }
  await tester.pump();
}

Future<void> _abrirMenuOriginal(WidgetTester tester) async {
  final original = find.byKey(const ValueKey('foto-original-sindicato'));
  final secundario = await tester.startGesture(
    tester.getCenter(original),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await secundario.up();
  await tester.pumpAndSettle();
}

class _SelectorReemplazo extends ImagePicker {
  ImageSource? origen;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    origen = source;
    final imagen = img.Image(width: 48, height: 48);
    return XFile.fromData(img.encodePng(imagen), name: 'reemplazo.png');
  }
}

class _ApiFotos extends ApiClient {
  _ApiFotos({
    this.fotosAdicionales = 0,
    this.fallaGuardado = false,
    this.extensionAna = 'png',
  });

  final int fotosAdicionales;
  final bool fallaGuardado;
  final String extensionAna;
  final paginas = <int>[];
  final guardados = <String>[];
  final descargas = <String>[];
  String? origen;
  String? fondoProcesado;
  Uint8List? bytesGuardados;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/5/imagenes/capacidades') {
      return {'subidaSinProcesar': true};
    }
    expect(ruta, '/productores');
    expect(query!['sindicatoId'], 7);
    expect(query['sort'], ['apellidos,asc', 'nombres,asc']);
    final pagina = query['page'] as int;
    paginas.add(pagina);
    return {
      'content': pagina == 0
          ? [
              _productor(5, 'ANA ALVAREZ', 'ana'),
              _productor(6, 'SIN FOTO', null),
            ]
          : [
              _productor(9, 'JUAN ZAMORA', 'juan'),
              for (var i = 0; i < fotosAdicionales; i++)
                _productor(10 + i, 'ZAMORA ${i + 1}', 'foto-$i'),
            ],
      'page': {'number': pagina, 'totalPages': 2},
    };
  }

  Map<String, Object?> _productor(int id, String nombre, String? archivo) => {
    'id': id,
    'nombreCompleto': nombre,
    'sindicatoId': 7,
    'centralId': 3,
    if (archivo != null)
      'fotoUrl':
          '/api/v1/archivos/$archivo-original.${archivo == 'ana' ? extensionAna : 'png'}',
    if (archivo != null) 'miniaturaUrl': '/api/v1/archivos/$archivo-mini.png',
  };

  @override
  Future<DescargaBinaria> descargarUrl(Uri url) async {
    descargas.add(url.path);
    final imagen = img.Image(width: 32, height: 32, numChannels: 4);
    img.fill(imagen, color: img.ColorRgba8(100, 110, 120, 180));
    final esJpeg = url.path.toLowerCase().endsWith('.jpg');
    return DescargaBinaria(
      bytes: esJpeg ? img.encodeJpg(imagen) : img.encodePng(imagen),
      nombreArchivo: esJpeg ? 'prueba.jpg' : 'prueba.png',
      tipoMime: esJpeg ? 'image/jpeg' : 'image/png',
    );
  }

  @override
  Future<Object?> subirArchivo(
    String ruta, {
    required String campo,
    required List<int> bytes,
    required String nombreArchivo,
    Map<String, String?>? campos,
    Map<String, ArchivoAdjunto>? archivosAdicionales,
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    guardados.add(ruta);
    if (fallaGuardado) {
      throw const ApiException(estado: 409, mensaje: 'La fotografía cambió.');
    }
    origen = campos!['fotoOrigen'];
    fondoProcesado = campos['fondoProcesado'];
    bytesGuardados = Uint8List.fromList(bytes);
    final pendiente = campos['pendienteEdicion'] == 'true';
    return {
      'productorId': int.parse(ruta.split('/')[2]),
      'operacionId': campos['operacionId'],
      'tamanoSubidoBytes': bytes.length,
      'anchoSubido': 20,
      'altoSubido': 20,
      'original': _imagen('ORIGINAL', 'editada', pendiente: pendiente),
      'miniatura': _imagen('MINIATURA', 'editada-mini', pendiente: pendiente),
    };
  }

  Map<String, Object?> _imagen(
    String tipo,
    String archivo, {
    required bool pendiente,
  }) => {
    'tipo': tipo,
    'url': '/api/v1/archivos/$archivo.${pendiente ? 'jpg' : 'png'}',
    'tipoMime': pendiente ? 'image/jpeg' : 'image/png',
    'tamanoBytes': 100,
    'ancho': 20,
    'alto': 20,
    'nombreOriginal': 'foto.png',
    'pendienteEdicion': pendiente,
  };
}
