import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/fila_productor.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';

void main() {
  for (final estado in <String?>[
    'CON_SISTEMA',
    'SIN_SISTEMA',
    'BLANCO',
    'FRACCIONADO',
    'DETALLISTA',
    'COMUNITARIO',
    null,
  ]) {
    testWidgets('lista muestra revisión sin lote: $estado', (tester) async {
      final p = Productor.desdeJson(_ApiLote(estado: estado).productor);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilaProductor(
              productor: p,
              alTocar: () {},
              mostrarRuta: false,
            ),
          ),
        ),
      );
      expect(find.text(p.resumenRevisionLote), findsOneWidget);
      expect(
        find.byTooltip('En revisión: falta número de lote'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final existente in [false, true]) {
    testWidgets(
      existente
          ? 'completa el lote histórico sin crear otra parcela'
          : 'asigna lote conservando Sistema y cierra la revisión',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _ApiLote(existente: existente);
        final tema = PreferenciaTema();
        addTearDown(tema.dispose);
        await tester.pumpWidget(
          TemaScope(
            preferencia: tema,
            child: PadronScope(
              padron: Padron(api: api),
              child: const MaterialApp(
                home: ProductorDetallePagina(productorId: 42),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Revisión pendiente: número de lote'), findsOneWidget);
        await tester.tap(find.text('Completar número de lote'));
        await tester.pumpAndSettle();
        if (!existente) {
          final dropdown = tester.widget<DropdownButtonFormField<EstadoLote>>(
            find.byType(DropdownButtonFormField<EstadoLote>),
          );
          expect(dropdown.initialValue, EstadoLote.conSistema);
          // No permite completar una parcela nueva sin número.
          await tester.tap(find.widgetWithText(FilledButton, 'Asignar'));
          await tester.pumpAndSettle();
          expect(find.text('Ingresá el número de parcela'), findsOneWidget);
          expect(api.guardado, isFalse);
        }
        final campo = find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextFormField),
            )
            .first;
        await tester.enterText(campo, '22');
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(
            FilledButton,
            existente ? 'Guardar número' : 'Asignar',
          ),
        );
        await tester.pumpAndSettle();
        expect(api.guardado, isTrue);
        expect(api.peticion!['numero'], '22');
        expect(api.peticion!['estado'], 'CON_SISTEMA');
        expect(api.creaciones, existente ? 0 : 1);
        expect(find.text('Revisión pendiente: número de lote'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _ApiLote extends ApiClient {
  _ApiLote({this.existente = false, this.estado = 'CON_SISTEMA'});
  final bool existente;
  final String? estado;
  bool guardado = false;
  int creaciones = 0;
  Map<String, dynamic>? peticion;

  Map<String, dynamic> get productor => {
    'id': 42,
    'nombres': 'MARÍA',
    'apellidos': 'PÉREZ',
    'nombreCompleto': 'MARÍA PÉREZ',
    'ci': '123456',
    'sindicatoId': 7,
    'sindicatoNombre': 'LIBERTAD',
    'centralId': 3,
    'centralNombre': '13 DE JUNIO',
    'codigoPadron': '2-13J-100',
    'clasificacion': estado,
    'revisionLotePendiente': !guardado,
    'credencialLista': false,
  };

  Map<String, dynamic> get lote => {
    'id': 9,
    'sindicatoId': 7,
    'sindicatoNombre': 'LIBERTAD',
    'numero': guardado ? '22' : null,
    'codigo': guardado ? '22' : '',
    'estado': estado,
    'estadoOriginal': estado,
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/42') {
      return {
        'productor': productor,
        'lotes': [if (existente || guardado) lote],
        'imagenes': <dynamic>[],
      };
    }
    if (ruta == '/lotes') return [if (existente || guardado) lote];
    return <dynamic>[];
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    expect(ruta, '/lotes');
    creaciones++;
    peticion = Map<String, dynamic>.from(cuerpo as Map);
    guardado = true;
    return lote;
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    expect(ruta, '/lotes/9');
    peticion = Map<String, dynamic>.from(cuerpo as Map);
    guardado = true;
    return lote;
  }
}
