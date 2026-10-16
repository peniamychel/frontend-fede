import 'dart:convert';
import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/importacion/importacion_pagina.dart';
import 'package:fede/ui/importacion/informe_importacion.dart';
import 'package:fede/ui/importacion/revision_cambios_importacion.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> comparacion({bool automatico = false}) => {
  'fila': 2,
  'productorId': 800,
  'productor': 'MARIA PEREZ',
  'nombrePlanilla': 'MARIA DEL EXCEL',
  'ci': '123456',
  'central': '13 DE JUNIO',
  'sindicato': '1RO DE MAYO',
  'huella': 'analisis-actual',
  'cambios': [
    {
      'campo': 'numeroLote',
      'actual': automatico ? null : '8',
      'propuesto': '4',
      'automatico': automatico,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          canal,
          (_) async => [
            {
              'name': 'padron.xlsx',
              'path': '/prueba/padron.xlsx',
              'bytes': Uint8List.fromList([1, 2, 3]),
              'size': 3,
            },
          ],
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  for (final eleccion in <bool?>[true, false, null]) {
    testWidgets(
      'elección de lote $eleccion se puede cambiar y enviar sin perder null',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _ApiImportacion();
        await tester.pumpWidget(
          PadronScope(
            padron: Padron(api: api),
            child: const MaterialApp(home: ImportacionPagina()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Conciliar lista UDESTRO'), findsNothing);
        await tester.tap(find.text('Elegir planilla .xlsx'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Analizar sin importar'));
        await tester.pumpAndSettle();
        expect(find.text('MARIA PEREZ'), findsOneWidget);
        expect(
          find.textContaining('Nombre en Excel: MARIA DEL EXCEL'),
          findsOneWidget,
        );
        final boton = find.widgetWithText(
          FilledButton,
          'Importar y aplicar cambios',
        );
        expect(find.text('Aceptar Excel'), findsOneWidget);
        expect(find.text('Conservar actual'), findsOneWidget);
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(const ValueKey('lote-2-false')))
              .selected,
          isTrue,
        );
        final actual = find.byKey(const ValueKey('lote-2-false'));
        await tester.ensureVisible(actual);
        if (eleccion == true) {
          await tester.tap(find.byKey(const ValueKey('lote-2-true')));
          await tester.pumpAndSettle();
        } else {
          // Deseleccionar la opción actual deja ambos chips sin elegir.
          await tester.tap(actual);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(actual).selected, isFalse);
          expect(
            tester
                .widget<ChoiceChip>(find.byKey(const ValueKey('lote-2-true')))
                .selected,
            isFalse,
          );
          expect(
            find.textContaining(
              'se marcará como observado: N° lote según Excel: 4',
            ),
            findsOneWidget,
          );
          if (eleccion == false) {
            await tester.tap(actual);
            await tester.pumpAndSettle();
          }
        }
        expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
        await tester.ensureVisible(boton);
        await tester.tap(boton);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
        await tester.pumpAndSettle();
        expect(api.peticionReal, hasLength(1));
        expect(api.peticionReal!.single['huella'], 'analisis-actual');
        expect(api.peticionReal!.single['campos'], {'numeroLote': eleccion});
        expect(api.realizadas, 1);
        expect(find.textContaining('Importación terminada'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('lote ausente es automático y no ofrece aprobación manual', (
    tester,
  ) async {
    final p = ComparacionImportacion.desdeJson(comparacion(automatico: true));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RevisionCambiosImportacion(comparaciones: [p])),
      ),
    );
    expect(
      find.text('1 lote(s) faltantes se completarán al importar.'),
      findsOneWidget,
    );
    expect(find.text('MARIA PEREZ'), findsNothing);
    expect(find.text('Aceptar Excel'), findsNothing);
    expect(p.decision({}), {
      'fila': 2,
      'huella': 'analisis-actual',
      'campos': <String, bool>{},
    });
  });
  testWidgets(
    'nota de lote y selección de CI repetidas viajan juntas sin perder la elección al ocultar la fila',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiImportacion()..conDuplicados = true;
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(home: ImportacionPagina()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir planilla .xlsx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analizar sin importar'));
      await tester.pumpAndSettle();
      final actual = find.byKey(const ValueKey('lote-2-false'));
      await tester.ensureVisible(actual);
      await tester.tap(actual);
      await tester.pumpAndSettle();
      final fila2 = find.byKey(const ValueKey('importar-fila-2'));
      final fila3 = find.byKey(const ValueKey('importar-fila-3'));
      await tester.ensureVisible(fila2);
      await tester.tap(fila2);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lote-2-false')), findsNothing);
      await tester.tap(fila2);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(actual).selected, isFalse);
      expect(
        find.textContaining(
          'se marcará como observado: N° lote según Excel: 4',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(fila3);
      await tester.tap(fila3);
      await tester.pumpAndSettle();
      final importar = find.widgetWithText(
        FilledButton,
        'Importar y aplicar cambios',
      );
      await tester.ensureVisible(importar);
      await tester.tap(importar);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
      await tester.pumpAndSettle();
      final dos = api.peticionReal!.singleWhere((d) => d['fila'] == 2);
      expect(dos['huella'], 'analisis-actual');
      expect(dos['campos'], {'numeroLote': null});
      expect(dos['aceptarFila'], isTrue);
      expect(dos['huellaDuplicado'], 'grupo');
      expect(
        api.peticionReal!.singleWhere((d) => d['fila'] == 3)['aceptarFila'],
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'la lista principal excluye campos vacíos aunque el productor tenga otra diferencia',
    (tester) async {
      final datos = comparacion();
      (datos['cambios'] as List).add({
        'campo': 'observaciones',
        'actual': null,
        'propuesto': 'Revisar documento',
        'automatico': true,
      });
      final p = ComparacionImportacion.desdeJson(datos);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RevisionCambiosImportacion(comparaciones: [p]),
            ),
          ),
        ),
      );
      expect(find.text('Sistema: 8\nExcel: 4'), findsOneWidget);
      expect(find.textContaining('Sistema: Sin dato'), findsNothing);
      expect(find.text('Aceptar Excel'), findsOneWidget);
      expect(find.text('Revisar otros datos faltantes'), findsNothing);
      expect(find.textContaining('1 nota(s) de observado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'los cambios automáticos permiten importar sin preguntas adicionales',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiImportacion()..soloAutomaticos = true;
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(home: ImportacionPagina()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir planilla .xlsx'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analizar sin importar'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar otros datos faltantes'), findsNothing);
      expect(find.text('Aceptar Excel'), findsNothing);
      expect(find.textContaining('1 extensión(es) faltantes'), findsOneWidget);
      expect(find.textContaining('1 clasificación(es)'), findsOneWidget);
      expect(find.textContaining('1 nota(s) de observado'), findsOneWidget);
      final importar = find.widgetWithText(
        FilledButton,
        'Importar y aplicar cambios',
      );
      expect(tester.widget<FilledButton>(importar).onPressed, isNotNull);
      await tester.ensureVisible(importar);
      await tester.tap(importar);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
      await tester.pumpAndSettle();
      expect(api.peticionReal, isEmpty);
      expect(api.realizadas, 1);
      expect(find.textContaining('Importación terminada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rechazos muestran nombre CI y ubicación sin identificadores internos',
    (tester) async {
      final resultado = ImportacionResultado.desdeJson({
        'errores': [
          {
            'fila': 4,
            'productor': 'JUAN QUISPE',
            'ci': '456',
            'central': '13 DE JUNIO',
            'sindicato': 'OTRO',
            'columna': 'ci',
            'valor': '456',
            'mensaje':
                'Esta CI pertenece a otro sindicato. Revisá el registro.',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InformeImportacion(informe: resultado),
            ),
          ),
        ),
      );
      expect(find.text('JUAN QUISPE'), findsOneWidget);
      expect(find.textContaining('CI: 456'), findsOneWidget);
      expect(find.textContaining('13 DE JUNIO › OTRO'), findsOneWidget);
      expect(find.textContaining('Columna ci'), findsNothing);
    },
  );
}

class _ApiImportacion extends ApiClient {
  List<dynamic>? peticionReal;
  int realizadas = 0;
  bool soloAutomaticos = false;
  bool conDuplicados = false;
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async => [
    {'id': 1, 'nombre': 'CARRASCO TROPICAL'},
  ];
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
    final simular = query?['simular'] as bool;
    final decisiones = jsonDecode(campos!['decisiones']!) as List;
    final incluidas = {
      for (final d in decisiones)
        if (d['aceptarFila'] != null) d['fila']: d['aceptarFila'],
    };
    if (!simular) {
      realizadas++;
      peticionReal = decisiones;
    }
    final fila = comparacion(automatico: soloAutomaticos);
    if (soloAutomaticos) {
      (fila['cambios'] as List).addAll(<Map<String, Object?>>[
        {
          'campo': 'extension',
          'actual': null,
          'propuesto': 'B',
          'automatico': true,
        },
        {
          'campo': 'clasificacion',
          'actual': 'SISTEMA',
          'propuesto': 'BLANCO',
          'automatico': true,
        },
        {
          'campo': 'observaciones',
          'actual': 'Nota actual',
          'propuesto': 'Nota actual, Revisar CI',
          'automatico': true,
        },
      ]);
    }
    return {
      'simulacion': simular,
      'federacionId': 1,
      'federacionNombre': 'CARRASCO TROPICAL',
      'filasLeidas': 1,
      'filasValidas': conDuplicados
          ? [2, 3].where((n) => incluidas[n] != false).length
          : 1,
      if (conDuplicados)
        'filasOmitidas': [2, 3].where((n) => incluidas[n] == false).length,
      'productores': 0,
      'lotes': 0,
      'productoresActualizados': simular ? 0 : 1,
      'comparaciones': [if (incluidas[2] != false) fila],
      if (conDuplicados)
        'gruposDuplicados': [
          {
            'huella': 'grupo',
            'ci': '123456',
            'filas': [
              for (final n in [2, 3])
                {
                  'numero': n,
                  'productor': 'MARIA PEREZ',
                  'central': '13 DE JUNIO',
                  'sindicato': '1RO DE MAYO',
                  'numeroLote': '4',
                  'seleccionada': incluidas[n] != false,
                },
            ],
          },
        ],
    };
  }
}
