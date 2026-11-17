import 'dart:async';
import 'dart:io';

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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  if (const bool.fromEnvironment('capturarEditor')) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(() async {
      final fuentes = Platform.environment['EDITOR_FUENTES']!;
      for (final fuente in [
        ('Roboto', 'roboto-regular.ttf'),
        ('MaterialIcons', 'materialicons-regular.otf'),
      ]) {
        final cargador = FontLoader(fuente.$1)
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('$fuentes/${fuente.$2}').readAsBytesSync(),
              ),
            ),
          );
        await cargador.load();
      }
    });
  }
  for (final tamano in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(568, 320),
    const Size(640, 360),
    const Size(844, 390),
    const Size(800, 600),
    const Size(700, 1000),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1200, 800),
    const Size(1920, 1080),
    const Size(2560, 1440),
  ]) {
    testWidgets('editor sin scroll ni controles fuera de pantalla en $tamano', (
      tester,
    ) async {
      final caso = await _Caso.abrir(tester);
      tester.view.physicalSize = tamano;
      caso.soltar(
        imagen: File('test/fixtures/foto-prueba.png').readAsBytesSync(),
      );
      await caso.esperarEditor();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
      for (final nombre in ['Brillo', 'Contraste', 'Saturación', 'Nitidez']) {
        final control = find.byKey(ValueKey('ajuste-$nombre'));
        expect(control.hitTestable(), findsOneWidget, reason: nombre);
        final rect = tester.getRect(control);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(tamano.height));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(tamano.width));
      }
      expect(find.text('Cancelar').hitTestable(), findsOneWidget);
      expect(find.text('Procesar imagen').hitTestable(), findsOneWidget);
      expect(find.byType(SwitchListTile).hitTestable(), findsOneWidget);
      final foto = tester.getRect(find.byType(RawImage));
      expect(foto.height, greaterThan(48));
      expect(foto.width, greaterThan(48));
      if (tamano.width >= 700 && tamano.height >= 600) {
        expect(
          find.byKey(const ValueKey('editor-foto-acotado')),
          findsOneWidget,
        );
        final ajustes = tester.getRect(
          find.byKey(const ValueKey('ajustes-fotografia')),
        );
        expect(ajustes.width, lessThanOrEqualTo(400));
        expect(ajustes.height, closeTo(ajustes.width, 0.01));
        expect(foto.size.longestSide, closeTo(ajustes.width, 0.01));
        expect(foto.right, lessThan(ajustes.left));
        expect(foto.center.dy, closeTo(ajustes.center.dy, 0.01));
        if (tamano.width >= 900 && tamano.height >= 768) {
          expect(ajustes.size, const Size(400, 400));
        }
        expect(
          find.text('Formato de fotografía: cuadrado (1:1)'),
          findsOneWidget,
        );
      }
      if (const bool.fromEnvironment('capturarEditor')) {
        await expectLater(
          find.byType(Scaffold).last,
          matchesGoldenFile(
            '../build/recorte-adaptable/${tamano.width.toInt()}x${tamano.height.toInt()}.png',
          ),
        );
      }
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Procesar imagen').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Subir sin procesar').hitTestable(), findsOneWidget);
      expect(
        tester.getCenter(find.text('Procesar imagen')).dx,
        lessThan(tester.getCenter(find.text('Cancelar')).dx),
      );
      expect(
        tester.getCenter(find.text('Cancelar')).dx,
        lessThan(tester.getCenter(find.text('Subir sin procesar')).dx),
      );
    });
  }

  testWidgets('carga rápida sube directamente y bloquea impresión', (
    tester,
  ) async {
    final caso = await _Caso.abrir(tester);
    final respuesta = Completer<Object?>();
    caso.api.responder = (_, _) => respuesta.future;
    caso.soltar();
    await caso.esperarEditor();
    // El procesamiento IA no está disponible en este entorno de prueba.
    // Se conserva el interruptor activado para comprobar que no se invoca.
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    tester
        .widget<RecortadorImagen>(find.byType(RecortadorImagen))
        .alCambiar(const Recorte(x: 2, y: 2, ancho: 24, alto: 24));
    await tester.pump();
    await tester.tap(find.text('Subir sin procesar'));
    for (var i = 0; i < 30 && caso.api.envios.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.byType(ConfirmarSubidaFoto), findsNothing);
    expect(caso.api.envios, ['/productores/101/imagenes']);
    final subiendo = find.widgetWithText(OutlinedButton, 'Subiendo…');
    expect(tester.widget<OutlinedButton>(subiendo).onPressed, isNull);
    expect(caso.cambios, 0);
    final jpeg = img.decodeJpg(Uint8List.fromList(caso.api.ultimaImagen!))!;
    expect(jpeg.width, 24);
    expect(jpeg.height, 24);
    expect(caso.api.ultimaImagen!.length, lessThanOrEqualTo(400 * 1024));
    respuesta.complete(_respuesta(101, caso.api.operaciones.single));
    await tester.pumpAndSettle();
    expect(caso.api.envios, ['/productores/101/imagenes']);
    expect(caso.api.pendientes, [true]);
    expect(caso.api.fondosProcesados, ['false']);
    expect(caso.api.nombres, ['prueba.jpg']);
    expect(caso.cambios, 1);
    expect(find.text('Foto guardada, pendiente de edición'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la carga rápida rechazada permite reintentar desde el recorte', (
    tester,
  ) async {
    final caso = await _Caso.abrir(tester);
    caso.api.admiteRapida = false;
    caso.soltar();
    await caso.esperarEditor();
    final subir = find.byKey(const ValueKey('subir-fotografia-sin-procesar'));
    final error = find.textContaining(
      'todavía no admite fotografías pendientes',
    );
    await tester.tap(subir);
    for (var i = 0; i < 30 && error.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(caso.api.envios, isEmpty);
    expect(caso.cambios, 0);
    expect(find.byType(ConfirmarSubidaFoto), findsNothing);
    expect(find.byType(RecortadorImagen), findsOneWidget);
    expect(error, findsOneWidget);
    expect(tester.widget<OutlinedButton>(subir).onPressed, isNotNull);
  });

  testWidgets('girar y ocultar ajustes conserva la región de imagen elegida', (
    tester,
  ) async {
    final caso = await _Caso.abrir(tester);
    tester.view.physicalSize = const Size(390, 844);
    caso.soltar();
    await caso.esperarEditor();
    final recortador = tester.state(find.byType(RecortadorImagen));
    await tester.drag(
      find.byKey(const ValueKey('recorte-inferiorDerecha')),
      const Offset(-40, -40),
    );
    await tester.pumpAndSettle();
    Rect seleccionRelativa() {
      final foto = tester.getRect(find.byType(RawImage));
      final superior = tester.getCenter(
        find.byKey(const ValueKey('recorte-superiorIzquierda')),
      );
      final inferior = tester.getCenter(
        find.byKey(const ValueKey('recorte-inferiorDerecha')),
      );
      return Rect.fromLTRB(
        (superior.dx - foto.left) / foto.width,
        (superior.dy - foto.top) / foto.height,
        (inferior.dx - foto.left) / foto.width,
        (inferior.dy - foto.top) / foto.height,
      );
    }

    final region = seleccionRelativa();
    expect(region.width, lessThan(1));
    void comprobarSeleccion() {
      final actual = seleccionRelativa();
      expect(actual.left, closeTo(region.left, 0.000001));
      expect(actual.top, closeTo(region.top, 0.000001));
      expect(actual.right, closeTo(region.right, 0.000001));
      expect(actual.bottom, closeTo(region.bottom, 0.000001));
    }

    for (final tamano in [
      const Size(844, 390),
      const Size(1200, 800),
      const Size(768, 1024),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = tamano;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(RecortadorImagen)), same(recortador));
      comprobarSeleccion();
      final foto = tester.getRect(find.byType(RawImage));
      final asa = tester.getCenter(
        find.byKey(const ValueKey('recorte-inferiorDerecha')),
      );
      expect(foto.contains(asa), isTrue);
      await tester.tap(find.text('Ajustes de imagen'));
      await tester.pumpAndSettle();
      comprobarSeleccion();
      await tester.tap(find.text('Ajustes de imagen'));
      await tester.pumpAndSettle();
      comprobarSeleccion();
      expect(tester.takeException(), isNull);
    }
  });

  for (final tamano in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1200, 800),
  ]) {
    testWidgets('editor admite texto ampliado y área segura en $tamano', (
      tester,
    ) async {
      final caso = await _Caso.abrir(tester, escalaTexto: 1.5);
      tester.view.physicalSize = tamano;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPadding);
      caso.soltar();
      await caso.esperarEditor();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
      for (final nombre in ['Brillo', 'Contraste', 'Saturación', 'Nitidez']) {
        expect(
          find.byKey(ValueKey('ajuste-$nombre')).hitTestable(),
          findsOneWidget,
        );
      }
      expect(find.text('Procesar imagen').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.text('Procesar imagen')).bottom,
        lessThanOrEqualTo(tamano.height - 24),
      );
    });
  }

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
      await tester.tap(find.widgetWithText(FilledButton, 'Procesar imagen'));
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
    'ajustes locales se ven, se restablecen y conservan PNG y destino al reintentar',
    (tester) async {
      final caso = await _Caso.abrir(tester);
      tester.view.physicalSize = const Size(390, 844);
      caso.api.responder = (_, operacion) async {
        if (caso.api.envios.length == 1) throw StateError('Sin conexión');
        return _respuesta(101, operacion);
      };
      final original = img.Image(width: 32, height: 32, numChannels: 4);
      img.fill(original, color: img.ColorRgba8(100, 120, 140, 128));
      caso.soltar(imagen: Uint8List.fromList(img.encodePng(original)));
      await caso.esperarEditor();
      final seleccion = const Recorte(x: 2, y: 2, ancho: 24, alto: 24);
      tester
          .widget<RecortadorImagen>(find.byType(RecortadorImagen))
          .alCambiar(seleccion);
      final brillo = find.byKey(const ValueKey('ajuste-Brillo'));
      tester.widget<Slider>(brillo).onChanged!(0.3);
      await tester.pump();
      tester.widget<Slider>(brillo).onChangeEnd!(0.3);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (tester
                .widget<RecortadorImagen>(find.byType(RecortadorImagen))
                .bytesVistaPrevia !=
            null) {
          break;
        }
      }
      expect(
        tester
            .widget<RecortadorImagen>(find.byType(RecortadorImagen))
            .bytesVistaPrevia,
        isNotNull,
      );
      expect(caso.api.envios, isEmpty);
      await tester.ensureVisible(find.text('Restablecer ajustes'));
      await tester.tap(find.text('Restablecer ajustes'));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(brillo).value, 0);
      expect(
        tester
            .widget<RecortadorImagen>(find.byType(RecortadorImagen))
            .bytesVistaPrevia,
        isNull,
      );
      // Procesar antes de que termine una vista previa también usa el último valor.
      tester.widget<Slider>(brillo).onChanged!(0.3);
      await tester.pump();
      final quitar = find.byType(SwitchListTile);
      await tester.ensureVisible(quitar);
      await tester.tap(quitar);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Procesar imagen'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.byType(ConfirmarSubidaFoto).evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      final preparada = tester
          .widget<ConfirmarSubidaFoto>(find.byType(ConfirmarSubidaFoto))
          .bytes;
      final png = img.decodePng(preparada)!;
      expect(png.width, 24);
      expect(png.height, 24);
      expect(png.getPixel(10, 10).r, greaterThan(100));
      expect(png.getPixel(10, 10).a, 128);
      expect(caso.api.envios, isEmpty);
      await tester.tap(find.text('Atrás'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            tester
                    .widget<RecortadorImagen>(find.byType(RecortadorImagen))
                    .bytesVistaPrevia !=
                null) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(brillo).value, 0.3);
      expect(
        tester
            .widget<RecortadorImagen>(find.byType(RecortadorImagen))
            .bytesVistaPrevia,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Procesar imagen'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        if (find.byType(ConfirmarSubidaFoto).evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ConfirmarSubidaFoto>(find.byType(ConfirmarSubidaFoto))
            .bytes,
        orderedEquals(preparada),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Subir').last);
      await tester.pumpAndSettle();
      expect(find.text('Reintentar subida'), findsOneWidget);
      expect(caso.api.ultimaImagen, orderedEquals(preparada));
      await tester.tap(find.text('Reintentar subida'));
      await tester.pumpAndSettle();
      expect(caso.api.envios, [
        '/productores/101/imagenes',
        '/productores/101/imagenes',
      ]);
      expect(caso.api.ultimaImagen, orderedEquals(preparada));
      expect(caso.api.operaciones.toSet(), hasLength(1));
      expect(caso.cambios, 1);
      expect(tester.takeException(), isNull);
    },
  );

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
    double escalaTexto = 1,
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
          theme: const bool.fromEnvironment('capturarEditor')
              ? ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF2E6B4F),
                    brightness: Brightness.dark,
                  ),
                )
              : null,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
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
  void soltar({Uint8List? imagen}) {
    final bytes =
        imagen ??
        Uint8List.fromList(
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
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Procesar imagen'),
        )
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
  bool admiteRapida = true;
  final pendientes = <bool>[];
  final fondosProcesados = <String?>[];
  final nombres = <String>[];
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta.endsWith('/imagenes/capacidades')) {
      return {'subidaSinProcesar': admiteRapida};
    }
    throw StateError('Consulta inesperada: $ruta');
  }

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
    pendientes.add(campos?['pendienteEdicion'] == 'true');
    fondosProcesados.add(campos?['fondoProcesado']);
    nombres.add(nombreArchivo);
    final respuesta = responder == null
        ? _respuesta(101, operacion)
        : await responder!(ruta, operacion);
    if (respuesta is Map<String, dynamic> && respuesta['original'] is Map) {
      (respuesta['original'] as Map)['pendienteEdicion'] = pendientes.last;
    }
    return respuesta;
  }
}
