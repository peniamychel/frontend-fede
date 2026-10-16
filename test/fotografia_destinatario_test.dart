import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:fede/core/api_client.dart';
import 'package:fede/core/operacion_fotografia.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/imagenes_productor.dart';
import 'package:fede/ui/productores/recortador_imagen.dart';
import 'package:fede/ui/widgets/zona_soltar_archivos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'dos fichas conservadas solo suben para el productor de la sección visible',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _ApiFotos();
      api.responder = (_, operacion) async => _respuesta(202, operacion);
      final padron = Padron(api: api);
      addTearDown(padron.cerrar);
      final cambios = <int>[];
      await tester.pumpWidget(
        PadronScope(
          padron: padron,
          child: MaterialApp(
            home: Scaffold(
              body: IndexedStack(
                index: 1,
                children: [
                  ImagenesProductor(
                    productorId: 101,
                    nombreProductor: 'ANA',
                    ci: '123',
                    imagenes: const [],
                    alCambiar: () => cambios.add(101),
                  ),
                  ImagenesProductor(
                    productorId: 202,
                    nombreProductor: 'JUAN',
                    ci: '456',
                    imagenes: const [],
                    alCambiar: () => cambios.add(202),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 32, height: 32, numChannels: 4)),
      );
      final archivo = DropItemFile.fromData(
        bytes,
        name: 'foto.png',
        path: 'foto.png',
      );
      final zonas = tester
          .widgetList<ZonaSoltarArchivos>(
            find.byType(ZonaSoltarArchivos, skipOffstage: false),
          )
          .toList();
      for (final zona in zonas) {
        unawaited(zona.alSoltar([archivo]));
      }
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Recortar y subir', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('JUAN · CI: 456'), findsOneWidget);
      tester
          .widget<RecortadorImagen>(find.byType(RecortadorImagen))
          .alCambiar(const Recorte(x: 0, y: 0, ancho: 32, alto: 32));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Subir').last);
      await tester.pumpAndSettle();
      expect(api.envios, ['/productores/202/imagenes']);
      expect(cambios, [202]);
      expect(find.text('Recortar y subir', skipOffstage: false), findsNothing);
    },
  );

  testWidgets(
    'Android no recupera ni consume una foto pendiente desde otro productor',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final pendiente = OperacionFotografia(
        productorId: 101,
        nombre: 'ANA',
        ci: '123',
      );
      await FotoCamaraPendiente.guardar(pendiente);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final caso = await _Caso.abrir(
          tester,
          productor: 202,
          conservarPendiente: true,
        );
        await tester.pumpAndSettle();
        expect(find.text('Fotografía pendiente de ANA'), findsOneWidget);
        expect(find.text('Recortar y subir'), findsNothing);
        expect(caso.api.envios, isEmpty);
        expect((await FotoCamaraPendiente.leer())!.productorId, 101);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        SharedPreferences.setMockInitialValues({});
      }
    },
  );

  testWidgets('dos aperturas y dos clics envían una vez y vuelven a la ficha', (
    tester,
  ) async {
    final caso = await _Caso.abrir(tester);
    caso.soltar();
    caso.soltar();
    await caso.esperarEditor();
    expect(find.text('Recortar y subir', skipOffstage: false), findsOneWidget);
    await caso.preparar(doble: true);
    expect(
      find.byType(ConfirmarSubidaFoto, skipOffstage: false),
      findsOneWidget,
    );
    final subir = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Subir').last)
        .onPressed!;
    subir();
    subir();
    await tester.pumpAndSettle();
    expect(caso.api.envios, ['/productores/101/imagenes']);
    expect(caso.cambios, 1);
    expect(find.text('Recortar y subir', skipOffstage: false), findsNothing);
    expect(find.byType(ConfirmarSubidaFoto, skipOffstage: false), findsNothing);
    final png = img.decodePng(Uint8List.fromList(caso.api.ultimaImagen!))!;
    expect(png.width, lessThanOrEqualTo(600));
    expect(png.numChannels, 4);
  });

  testWidgets(
    'cambiar de productor antes de leer el archivo cancela la apertura',
    (tester) async {
      final caso = await _Caso.abrir(tester);
      final lectura = Completer<Uint8List>();
      unawaited(caso.zona.alSoltar([_ArchivoDemorado(lectura.future)]));
      await tester.pump();
      caso.cambiar(202);
      await tester.pump();
      lectura.complete(
        Uint8List.fromList(img.encodePng(img.Image(width: 32, height: 32))),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recortar y subir'), findsNothing);
      expect(caso.api.envios, isEmpty);
    },
  );

  testWidgets(
    'cambiar de productor con recorte abierto impide procesar para el nuevo',
    (tester) async {
      final caso = await _Caso.abrir(tester);
      caso.soltar();
      await caso.esperarEditor();
      caso.cambiar(202);
      await tester.pumpAndSettle();
      await caso.preparar(esperaConfirmacion: false);
      expect(caso.api.envios, isEmpty);
      expect(find.byType(ConfirmarSubidaFoto), findsNothing);
      expect(find.textContaining('La ficha de origen cambió'), findsOneWidget);
    },
  );

  for (final desmontar in [false, true]) {
    testWidgets(
      'ficha ${desmontar ? 'desmontada' : 'cambiada'} no acepta una vista previa antigua',
      (tester) async {
        final caso = await _Caso.abrir(tester);
        caso.soltar();
        await caso.esperarEditor();
        await caso.preparar();
        if (desmontar) {
          caso.ocultar();
        } else {
          caso.cambiar(202);
        }
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Subir').last);
        await tester.pumpAndSettle();
        expect(caso.api.envios, isEmpty);
        expect(find.byType(ConfirmarSubidaFoto), findsOneWidget);
        expect(
          find.textContaining('La ficha de origen cambió'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'la conexión lenta mantiene la vista y el destino original hasta confirmar',
    (tester) async {
      final caso = await _Caso.abrir(tester);
      final respuesta = Completer<Object?>();
      caso.api.responder = (_, _) => respuesta.future;
      caso.soltar();
      await caso.esperarEditor();
      await caso.preparar();
      await tester.tap(find.widgetWithText(FilledButton, 'Subir').last);
      await tester.pump();
      final contexto = tester.element(find.byType(ConfirmarSubidaFoto));
      expect(await Navigator.of(contexto).maybePop(), isTrue);
      await tester.pump();
      expect(find.byType(ConfirmarSubidaFoto), findsOneWidget);
      expect(caso.cambios, 0);
      caso.cambiar(202);
      await tester.pump();
      respuesta.complete(_respuesta(101, caso.api.operaciones.single));
      await tester.pumpAndSettle();
      expect(caso.api.envios, ['/productores/101/imagenes']);
      expect(caso.cambios, 0); // No recarga ni notifica éxito en la ficha 202.
      expect(find.byType(ConfirmarSubidaFoto), findsNothing);
      expect(find.text('Recortar y subir', skipOffstage: false), findsNothing);
    },
  );

  testWidgets('reintenta conservando los bytes, la operación y el productor', (
    tester,
  ) async {
    final caso = await _Caso.abrir(tester);
    caso.api.responder = (ruta, operacion) async {
      if (caso.api.envios.length == 1) throw StateError('Sin conexión');
      return _respuesta(101, operacion);
    };
    caso.soltar();
    await caso.esperarEditor();
    await caso.preparar();
    await tester.tap(find.widgetWithText(FilledButton, 'Subir').last);
    await tester.pumpAndSettle();
    expect(find.text('Reintentar subida'), findsOneWidget);
    expect(caso.cambios, 0);
    await tester.tap(find.text('Reintentar subida'));
    await tester.pumpAndSettle();
    expect(caso.api.envios, [
      '/productores/101/imagenes',
      '/productores/101/imagenes',
    ]);
    expect(caso.api.operaciones.toSet(), hasLength(1));
    expect(caso.cambios, 1);
    expect(find.text('Recortar y subir', skipOffstage: false), findsNothing);
  });

  for (final respuesta in ['vacía', 'otro productor', 'otra operación']) {
    testWidgets(
      'una confirmación $respuesta conserva la foto y no anuncia éxito',
      (tester) async {
        final caso = await _Caso.abrir(tester);
        caso.api.responder = (_, operacion) async => respuesta == 'vacía'
            ? {}
            : _respuesta(
                respuesta == 'otro productor' ? 202 : 101,
                respuesta == 'otra operación'
                    ? 'ffffffffffffffffffffffffffffffff'
                    : operacion,
              );
        caso.soltar();
        await caso.esperarEditor();
        await caso.preparar();
        await tester.tap(find.widgetWithText(FilledButton, 'Subir').last);
        await tester.pumpAndSettle();
        expect(caso.cambios, 0);
        expect(find.text('Foto guardada'), findsNothing);
        expect(find.byType(ConfirmarSubidaFoto), findsOneWidget);
        expect(find.text('Reintentar subida'), findsOneWidget);
      },
    );
  }

  test(
    'cámara pendiente conserva propietario e identidad y no borra otra operación',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = OperacionFotografia(
        productorId: 101,
        nombre: 'ANA',
        ci: '123',
      );
      await FotoCamaraPendiente.guardar(original);
      final recuperada = (await FotoCamaraPendiente.leer())!;
      expect(recuperada.productorId, 101);
      expect(recuperada.id, original.id);
      expect(recuperada.destinatario, 'ANA · CI: 123');
      await FotoCamaraPendiente.borrarSiCorresponde('otro');
      expect(await FotoCamaraPendiente.leer(), isNotNull);
      await FotoCamaraPendiente.borrarSiCorresponde(original.id);
      expect(await FotoCamaraPendiente.leer(), isNull);
    },
  );

  test(
    'sin identidad verificable no se recupera para el productor actual',
    () async {
      SharedPreferences.setMockInitialValues({
        FotoCamaraPendiente.clave: '{"productorId":202}',
      });
      expect(await FotoCamaraPendiente.leer(), isNull);
    },
  );
}

Map<String, dynamic> _respuesta(int productorId, String? operacion) => {
  'productorId': productorId,
  'operacionId': operacion,
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
    'url': '/mini.png',
    'tipoMime': 'image/png',
    'ancho': 16,
    'alto': 16,
    'tamanoBytes': 100,
  },
};

class _Caso {
  _Caso(this.tester);
  final WidgetTester tester;
  final api = _ApiFotos();
  late StateSetter actualizar;
  late ZonaSoltarArchivos zona;
  int productor = 101;
  int cambios = 0;
  bool visible = true;
  static Future<_Caso> abrir(
    WidgetTester tester, {
    int productor = 101,
    bool conservarPendiente = false,
  }) async {
    if (!conservarPendiente) SharedPreferences.setMockInitialValues({});
    final caso = _Caso(tester);
    caso.productor = productor;
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final padron = Padron(api: caso.api);
    addTearDown(padron.cerrar);
    await tester.pumpWidget(
      PadronScope(
        padron: padron,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              caso.actualizar = setState;
              return Scaffold(
                body: caso.visible
                    ? ImagenesProductor(
                        productorId: caso.productor,
                        nombreProductor: 'ANA',
                        ci: '123',
                        imagenes: const [],
                        alCambiar: () => caso.cambios++,
                      )
                    : const Text('Sin ficha'),
              );
            },
          ),
        ),
      ),
    );
    caso.zona = tester.widget<ZonaSoltarArchivos>(
      find.byType(ZonaSoltarArchivos),
    );
    return caso;
  }

  void cambiar(int id) => actualizar(() => productor = id);
  void ocultar() => actualizar(() => visible = false);
  void soltar() {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 32, height: 32, numChannels: 4)),
    );
    unawaited(
      zona.alSoltar([
        DropItemFile.fromData(bytes, name: 'prueba.png', path: 'prueba.png'),
      ]),
    );
  }

  Future<void> esperarEditor() async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('ANA · CI: 123'), findsOneWidget);
  }

  Future<void> preparar({
    bool doble = false,
    bool esperaConfirmacion = true,
  }) async {
    tester
        .widget<RecortadorImagen>(find.byType(RecortadorImagen))
        .alCambiar(const Recorte(x: 0, y: 0, ancho: 32, alto: 32));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    final accion = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Subir'))
        .onPressed!;
    accion();
    if (doble) accion();
    await tester.pumpAndSettle();
    if (esperaConfirmacion) {
      expect(find.byType(ConfirmarSubidaFoto), findsOneWidget);
    }
  }
}

class _ArchivoDemorado extends DropItemFile {
  _ArchivoDemorado(this.lectura) : super('prueba.png');
  final Future<Uint8List> lectura;
  @override
  Future<Uint8List> readAsBytes() => lectura;
}

class _ApiFotos extends ApiClient {
  final envios = <String>[];
  final operaciones = <String?>[];
  List<int>? ultimaImagen;
  Future<Object?> Function(String, String?)? responder;
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
    envios.add(ruta);
    ultimaImagen = bytes;
    final operacion = campos?['operacionId'];
    operaciones.add(operacion);
    return responder == null
        ? _respuesta(101, operacion)
        : await responder!(ruta, operacion);
  }
}
