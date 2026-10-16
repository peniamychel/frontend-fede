import 'dart:convert';
import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/importacion/importacion_pagina.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
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
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null),
  );

  Future<void> abrir(WidgetTester tester, _ApiDuplicados api) async {
    tester.view.physicalSize = const Size(1100, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
  }

  Finder fila(int n) => find.byKey(ValueKey('importar-fila-$n'));
  final confirmar = find.widgetWithText(
    FilledButton,
    'Importar y aplicar cambios',
  );
  Future<void> alternar(WidgetTester tester, int n) async {
    await tester.ensureVisible(fila(n));
    await tester.tap(fila(n));
    await tester.pumpAndSettle();
  }

  Future<void> importar(WidgetTester tester) async {
    await tester.ensureVisible(confirmar);
    await tester.tap(confirmar);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'agrupa CI intercaladas y marca todos los productores por defecto',
    (tester) async {
      final api = _ApiDuplicados()..variosGrupos = true;
      await abrir(tester, api);
      expect(find.text('CI repetidas en la planilla'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(4));
      for (final n in [2, 3, 4, 5]) {
        expect(tester.widget<CheckboxListTile>(fila(n)).value, isTrue);
      }
      // El Excel intercalaba 222/111/222/111; la pantalla reúne cada CI.
      expect(
        tester.getTopLeft(fila(3)).dy,
        lessThan(tester.getTopLeft(fila(5)).dy),
      );
      expect(
        tester.getTopLeft(fila(5)).dy,
        lessThan(tester.getTopLeft(fila(2)).dy),
      );
      expect(
        tester.getTopLeft(fila(2)).dy,
        lessThan(tester.getTopLeft(fila(4)).dy),
      );
      await importar(tester);
      expect(api.decisionesReales, hasLength(4));
      expect(
        api.decisionesReales.every((d) => d['aceptarFila'] == true),
        isTrue,
      );
      expect(
        find.textContaining('Importación terminada: 4 productores'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desmarcar excluye la fila, recalcula y permite importar una CI sin observación',
    (tester) async {
      final api = _ApiDuplicados();
      await abrir(tester, api);
      expect(
        find.textContaining('Revisión CI. La cédula sigue repetida'),
        findsOneWidget,
      );
      await alternar(tester, 3);
      expect(api.analisis, 2);
      expect(tester.widget<CheckboxListTile>(fila(2)).value, isTrue);
      expect(tester.widget<CheckboxListTile>(fila(3)).value, isFalse);
      expect(
        find.textContaining('Revisión CI. La cédula sigue repetida'),
        findsNothing,
      );
      expect(
        find.text('1 fila(s) desmarcadas: no se importarán.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNotNull);
      await importar(tester);
      expect(
        api.decisionesReales.firstWhere((d) => d['fila'] == 3)['aceptarFila'],
        isFalse,
      );
      expect(api.importadas, [2]);
      expect(
        find.textContaining('Importación terminada: 1 productores'),
        findsOneWidget,
      );
      expect(tester.widget<CheckboxListTile>(fila(3)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'se puede volver a marcar y desmarcar todas bloquea una importación vacía',
    (tester) async {
      final api = _ApiDuplicados();
      await abrir(tester, api);
      await alternar(tester, 2);
      await alternar(tester, 3);
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);
      await alternar(tester, 2);
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNotNull);
      expect(tester.widget<CheckboxListTile>(fila(2)).value, isTrue);
      expect(tester.widget<CheckboxListTile>(fila(3)).value, isFalse);
      expect(
        find.textContaining('Revisión CI. La cédula sigue repetida'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'un fallo al reanalizar conserva la selección e impide confirmar hasta reintentar',
    (tester) async {
      final api = _ApiDuplicados();
      await abrir(tester, api);
      api.fallarAnalisis = true;
      await alternar(tester, 3);
      expect(tester.widget<CheckboxListTile>(fila(3)).value, isFalse);
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);
      expect(
        find.textContaining('Volvé a analizar para actualizar la selección'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Volver a analizar'));
      await tester.tap(find.text('Volver a analizar'));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(fila(3)).value, isFalse);
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'si hay duplicado previo en el padrón el aviso se mantiene aunque quede una fila',
    (tester) async {
      final api = _ApiDuplicados()..existeEnPadron = true;
      await abrir(tester, api);
      await alternar(tester, 3);
      expect(
        find.textContaining('Revisión CI. La cédula sigue repetida'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNotNull);
      await importar(tester);
      expect(api.importadas, [2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cambiar el archivo restablece todas las casillas', (
    tester,
  ) async {
    final api = _ApiDuplicados();
    await abrir(tester, api);
    await alternar(tester, 3);
    await tester.ensureVisible(find.text('Cambiar'));
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analizar sin importar'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(fila(2)).value, isTrue);
    expect(tester.widget<CheckboxListTile>(fila(3)).value, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _ApiDuplicados extends ApiClient {
  List<dynamic> decisionesReales = [];
  List<int> importadas = [];
  int analisis = 0;
  bool variosGrupos = false;
  bool existeEnPadron = false;
  bool fallarAnalisis = false;
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
    if (simular) {
      analisis++;
      if (fallarAnalisis) {
        fallarAnalisis = false;
        throw const ApiException(
          estado: 503,
          mensaje: 'Fallo de análisis de prueba',
        );
      }
    }
    final decisiones = jsonDecode(campos!['decisiones']!) as List;
    final seleccion = {
      for (final d in decisiones) d['fila'] as int: d['aceptarFila'] as bool,
    };
    final grupos = variosGrupos
        ? <String, List<int>>{
            '111': [3, 5],
            '222': [2, 4],
          }
        : <String, List<int>>{
            '123456': [2, 3],
          };
    final filas = grupos.values.expand((n) => n).toList();
    final elegidas = filas.where((n) => seleccion[n] ?? true).toList();
    if (!simular) {
      decisionesReales = decisiones;
      importadas = elegidas;
    }
    return {
      'simulacion': simular,
      'federacionId': 1,
      'federacionNombre': 'CARRASCO TROPICAL',
      'filasLeidas': filas.length,
      'filasValidas': elegidas.length,
      'filasRechazadas': 0,
      'filasOmitidas': filas.length - elegidas.length,
      'productores': elegidas.length,
      'lotes': elegidas.length,
      'gruposDuplicados': [
        for (final grupo in grupos.entries)
          {
            'ci': grupo.key,
            'huella': 'grupo-${grupo.key}',
            'filas': [
              for (final n in grupo.value)
                {
                  'numero': n,
                  'productor': n.isEven ? 'MARIA PEREZ' : 'JUAN GOMEZ',
                  'central': '13 DE JUNIO',
                  'sindicato': 'LIBERTAD',
                  'numeroLote': '$n',
                  'seleccionada': seleccion[n] ?? true,
                },
            ],
          },
      ],
      'avisos': [
        for (final grupo in grupos.entries)
          if (grupo.value.where((n) => seleccion[n] ?? true).length > 1 ||
              existeEnPadron)
            for (final n in grupo.value.where((n) => seleccion[n] ?? true))
              {
                'fila': n,
                'productor': n.isEven ? 'MARIA PEREZ' : 'JUAN GOMEZ',
                'ci': grupo.key,
                'central': '13 DE JUNIO',
                'sindicato': 'LIBERTAD',
                'mensaje':
                    'Revisión CI. La cédula sigue repetida: no podrá imprimir.',
              },
      ],
    };
  }
}
