import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

import 'package:fede/core/api_client.dart';
import 'package:fede/models/lado_credencial.dart';
import 'package:fede/ui/credenciales/impresion_credencial.dart';

void main() {
  late PrintingPlatform original;
  late _ImpresoraSimulada impresora;
  late List<LadoCredencial> descargados;
  late int registros;

  setUp(() {
    original = PrintingPlatform.instance;
    impresora = _ImpresoraSimulada();
    PrintingPlatform.instance = impresora;
    debugImpresionDeCredencialesDisponible = true;
    descargados = [];
    registros = 0;
  });

  tearDown(() {
    PrintingPlatform.instance = original;
    debugImpresionDeCredencialesDisponible = null;
  });

  Future<void> abrir(WidgetTester tester, {bool fallarRegistro = false}) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PanelImpresionCredencial(
            habilitada: true,
            nombre: 'MARÍA PÉREZ',
            cargar: (lado) async {
              descargados.add(lado);
              return DescargaBinaria(
                bytes: Uint8List.fromList([
                  lado == LadoCredencial.anverso ? 1 : 2,
                ]),
                nombreArchivo: 'carnet.pdf',
                tipoMime: 'application/pdf',
              );
            },
            alAnversoImpreso: () async {
              registros++;
              if (fallarRegistro && registros == 1) {
                throw StateError('No se pudo registrar la impresión');
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pulsar(WidgetTester tester, LadoCredencial lado) async {
    await tester.tap(
      find.text(
        lado == LadoCredencial.anverso
            ? '1. Imprimir anverso'
            : '2. Imprimir reverso',
      ),
    );
    // El indicador del panel sigue activo detrás de la alerta.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> confirmarReverso(WidgetTester tester) async {
    await tester.tap(find.text('Imprimir reverso'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  for (final lado in LadoCredencial.values) {
    testWidgets(
      'cancelar ${lado.name} no descarga, imprime ni modifica el contador',
      (tester) async {
        await abrir(tester);
        await pulsar(tester, lado);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('MARÍA PÉREZ'), findsOneWidget);
        expect(
          find.text(
            lado == LadoCredencial.anverso
                ? '¿Imprimir la cara del carnet?'
                : '¿Imprimir el reverso del carnet?',
          ),
          findsOneWidget,
        );
        expect(descargados, isEmpty);
        expect(impresora.enviados, isEmpty);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(descargados, isEmpty);
        expect(impresora.enviados, isEmpty);
        expect(registros, 0);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cerrar la alerta con atrás tampoco imprime', (tester) async {
    await abrir(tester);
    await pulsar(tester, LadoCredencial.anverso);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(descargados, isEmpty);
    expect(impresora.enviados, isEmpty);
    expect(registros, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doble clic abre una sola alerta y bloquea ambos lados', (
    tester,
  ) async {
    await abrir(tester);
    final accion = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    accion();
    accion();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '1. Imprimir anverso'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(descargados, isEmpty);
    expect(impresora.enviados, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirmar cara envía un solo trabajo y después aumenta el contador',
    (tester) async {
      await abrir(tester);
      await pulsar(tester, LadoCredencial.anverso);
      expect(registros, 0);
      await tester.tap(find.text('Imprimir cara'));
      await tester.pumpAndSettle();
      expect(descargados, [LadoCredencial.anverso]);
      expect(impresora.enviados.single, [1]);
      expect(registros, 1);
      expect(
        find.text('2. Tarjeta volteada: imprimir reverso'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirmar reverso conserva la vista previa antes del envío', (
    tester,
  ) async {
    await abrir(tester);
    await pulsar(tester, LadoCredencial.reverso);
    expect(
      find.textContaining('Retirá la tarjeta de la Zebra'),
      findsOneWidget,
    );
    await confirmarReverso(tester);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(descargados, [LadoCredencial.reverso]);
    expect(impresora.enviados, isEmpty);
    await tester.tap(find.text('Imprimir reverso'));
    await tester.pumpAndSettle();
    expect(impresora.enviados.single, [2]);
    expect(registros, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar en la vista previa del reverso no envía el trabajo', (
    tester,
  ) async {
    await abrir(tester);
    await pulsar(tester, LadoCredencial.reverso);
    await confirmarReverso(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(impresora.enviados, isEmpty);
    expect(registros, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reintentar el registro no pide imprimir ni duplica el envío físico',
    (tester) async {
      await abrir(tester, fallarRegistro: true);
      await pulsar(tester, LadoCredencial.anverso);
      await tester.tap(find.text('Imprimir cara'));
      await tester.pumpAndSettle();
      expect(impresora.enviados.length, 1);
      expect(registros, 1);
      expect(find.text('Registrar anverso ya enviado'), findsOneWidget);
      await tester.tap(find.text('Registrar anverso ya enviado'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(impresora.enviados.length, 1);
      expect(descargados.length, 1);
      expect(registros, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ImpresoraSimulada extends PrintingPlatform {
  final enviados = <Uint8List>[];

  @override
  Future<PrintingInfo> info() async =>
      const PrintingInfo(canPrint: true, canRaster: true);

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    yield _RasterPrueba();
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
    enviados.add(await onLayout(format));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RasterPrueba extends PdfRaster {
  _RasterPrueba() : super(400, 252, Uint8List(0));

  @override
  Future<Uint8List> toPng() async =>
      img.encodePng(img.Image(width: 400, height: 252));
}
