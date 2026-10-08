import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/impresion_credencial.dart';
import 'package:fede/ui/credenciales/pliego_previa_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  const sindicato = Sindicato(
    id: 13,
    nombre: '13 DE JUNIO',
    centralId: 2,
    centralNombre: 'CENTRAL IVIRGARZAMA',
  );

  setUp(() => debugImpresionDeCredencialesDisponible = true);
  tearDown(() => debugImpresionDeCredencialesDisponible = null);

  Future<void> abrirPreviaReverso(
    WidgetTester tester,
    _ApiPanel api,
    int cantidad,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: const MaterialApp(
          home: PliegoPreviaPagina(sindicato: sindicato),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Imprimir reversos'));
    await tester.tap(find.text('Imprimir reversos'));
    // El botón del panel mantiene un indicador activo detrás del diálogo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '$cantidad');
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Abrir impresión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '500 reversos cargan solo una muestra pequeña y cancelar no genera el trabajo',
    (tester) async {
      final original = PrintingPlatform.instance;
      final printing = _PrintingPruebas();
      PrintingPlatform.instance = printing;
      addTearDown(() => PrintingPlatform.instance = original);
      final api = _ApiPanel();
      await abrirPreviaReverso(tester, api, 500);
      expect(api.cantidadesReverso, [1]);
      expect(find.text('Cantidad a imprimir: 500 reversos'), findsOneWidget);
      final previa = tester.widget<PdfPreview>(find.byType(PdfPreview));
      expect(previa.pages, [0]);
      expect(previa.maxPageWidth, 400);
      expect(previa.allowPrinting, isFalse);
      expect(previa.useActions, isFalse);
      expect(printing.paginasRasterizadas, isNotEmpty);
      expect(
        printing.paginasRasterizadas.every(
          (p) => p.length == 1 && p.single == 0,
        ),
        isTrue,
      );
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(find.byType(Image)).width, lessThanOrEqualTo(400));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.cantidadesReverso, [1]);
      expect(printing.trabajos, isEmpty);
      expect(find.text('Imprimir reversos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final cantidad in [1, 25]) {
    testWidgets(
      'confirmar $cantidad reversos envía la cantidad elegida y reutiliza una sola muestra',
      (tester) async {
        final original = PrintingPlatform.instance;
        final printing = _PrintingPruebas();
        PrintingPlatform.instance = printing;
        addTearDown(() => PrintingPlatform.instance = original);
        final api = _ApiPanel();
        await abrirPreviaReverso(tester, api, cantidad);
        expect(api.cantidadesReverso, [1]);
        await tester.tap(find.text('Imprimir reverso'));
        await tester.pumpAndSettle();
        expect(api.cantidadesReverso, cantidad == 1 ? [1] : [1, cantidad]);
        expect(printing.trabajos.single, [cantidad]);
        expect(find.byType(PdfPreview), findsNothing);
        expect(
          printing.paginasRasterizadas.every(
            (p) => p.length == 1 && p.single == 0,
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mantiene el progreso visible y bloquea volver durante el envío',
    (tester) async {
      late BuildContext contexto;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              contexto = context;
              return const Scaffold(body: Text('Impresión'));
            },
          ),
        ),
      );
      final trabajo = Completer<bool>();
      final resultado = ejecutarConProgresoImpresion<bool>(
        contexto,
        mensaje: 'Enviando reversos…',
        accion: () => trabajo.future,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Enviando reversos…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await Navigator.of(contexto).maybePop();
      await tester.pump();
      expect(find.text('Enviando reversos…'), findsOneWidget);
      trabajo.complete(true);
      await tester.pump();
      expect(await resultado, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'ignora un segundo clic de impresión de reversos durante el proceso',
    (tester) async {
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: _ApiPanel()),
          child: const MaterialApp(
            home: PliegoPreviaPagina(sindicato: sindicato),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Imprimir reversos'),
      );
      boton.onPressed!();
      boton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Cantidad de reversos'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Procesando reversos…'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Imprimir reversos'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('muestra cantidades y acciones de impresión para Windows', (
    tester,
  ) async {
    final padron = Padron(api: _ApiPanel());
    await tester.pumpWidget(
      PadronScope(
        padron: padron,
        child: const MaterialApp(
          home: PliegoPreviaPagina(sindicato: sindicato),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Ya impresos'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Faltan con foto'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Sin fotografía'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Impresiones faltantes (4)'), findsOneWidget);
    expect(find.text('Impresión selectiva'), findsOneWidget);
    expect(find.text('Revisar última impresión'), findsOneWidget);
    expect(find.text('Imprimir reversos'), findsOneWidget);
    expect(
      find.text('Impresora: se seleccionará antes de enviar'),
      findsOneWidget,
    );
  });

  testWidgets(
    'en web o Android muestra cantidades pero oculta acciones de impresión',
    (tester) async {
      debugImpresionDeCredencialesDisponible = false;
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: _ApiPanel()),
          child: const MaterialApp(
            home: PliegoPreviaPagina(sindicato: sindicato),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Ya impresos'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Faltan con foto'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Sin fotografía'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('Vista informativa'), findsOneWidget);
      expect(find.textContaining('Impresiones faltantes'), findsNothing);
      expect(find.text('Impresión selectiva'), findsNothing);
      expect(find.text('Revisar última impresión'), findsNothing);
      expect(find.text('Imprimir reversos'), findsNothing);
      expect(find.textContaining('Impresora:'), findsNothing);
    },
  );

  testWidgets('permite revisar el último grupo contabilizado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiPanel(conUltimoGrupo: true)),
        child: const MaterialApp(
          home: PliegoPreviaPagina(sindicato: sindicato),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Revisar última impresión'),
    );
    expect(boton.onPressed, isNotNull);

    await tester.ensureVisible(find.text('Revisar última impresión'));
    await tester.tap(find.text('Revisar última impresión'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Marcá únicamente las tarjetas'),
      findsOneWidget,
    );
    expect(find.text('1 impresas'), findsOneWidget);
    expect(find.text('Cancelar todo el grupo'), findsOneWidget);
    expect(find.text('Guardar revisión (1)'), findsOneWidget);
  });

  testWidgets('sin fase activa informa y bloquea los envíos a la Zebra', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiPanel(conFase: false)),
        child: const MaterialApp(
          home: PliegoPreviaPagina(sindicato: sindicato),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Primero habilitá una fase'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Impresiones faltantes (4)'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Imprimir reversos'),
          )
          .onPressed,
      isNull,
    );
  });
}

class _ApiPanel extends ApiClient {
  _ApiPanel({this.conUltimoGrupo = false, this.conFase = true});

  final bool conUltimoGrupo;
  final bool conFase;
  final cantidadesReverso = <int>[];

  @override
  Future<DescargaBinaria> obtenerBytes(
    String ruta, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    expect(ruta, '/sindicatos/13/credenciales/impresion/reversos.pdf');
    final cantidad = query!['cantidad'] as int;
    cantidadesReverso.add(cantidad);
    return DescargaBinaria(
      bytes: Uint8List.fromList([cantidad]),
      nombreArchivo: 'reversos-$cantidad.pdf',
      tipoMime: 'application/pdf',
    );
  }

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/configuracion/credencial') {
      return const {'diseno': <String, dynamic>{}, 'camposDisponibles': []};
    }
    if (ruta == '/sindicatos/13/credenciales/impresion') {
      return {
        'sindicatoId': 13,
        'sindicato': '13 DE JUNIO',
        'total': 12,
        'impresos': 5,
        'faltantesConFoto': 4,
        'sinFoto': 3,
        'listosParaImprimir': 4,
        'faltantesDelSindicato': const [],
        'candidatos': const [],
        if (conFase) 'faseActiva': const {'id': 7, 'numero': 1},
        if (conUltimoGrupo)
          'ultimoGrupo': {
            'id': 41,
            'enviadoEn': '2026-09-01T08:30:00',
            'total': 1,
            'productorIdsContabilizados': const [81],
            'candidatos': const [
              {
                'credencial': {
                  'productorId': 81,
                  'nombreCompleto': 'MARÍA PÉREZ',
                  'nombres': 'MARÍA',
                  'apellidos': 'PÉREZ',
                  'ci': '1234567',
                  'lotes': '22 A',
                  'codigoQr': '2-IVI-81',
                  'completa': true,
                  'faltantes': [],
                },
                'impresiones': 1,
                'ultimaImpresion': '2026-09-01T08:30:00',
                'seleccionable': true,
              },
            ],
          },
      };
    }
    throw StateError('Ruta no simulada: $ruta');
  }
}

/// Sustituye tanto la rasterización nativa como la impresora. Los bytes de
/// prueba identifican la cantidad: no se envía ningún trabajo físico.
class _PrintingPruebas extends PrintingPlatform {
  final paginasRasterizadas = <List<int>>[];
  final trabajos = <Uint8List>[];

  @override
  Future<PrintingInfo> info() async =>
      const PrintingInfo(canPrint: true, canRaster: true);

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    paginasRasterizadas.add(List.of(pages!));
    yield _RasterMuestra();
  }

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
    bool windowsModernDialog,
  ) async {
    trabajos.add(await onLayout(format));
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RasterMuestra extends PdfRaster {
  _RasterMuestra() : super(400, 252, Uint8List(0));

  @override
  Future<Uint8List> toPng() async =>
      img.encodePng(img.Image(width: 400, height: 252));
}
