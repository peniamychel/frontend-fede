import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/inicio.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/fila_productor.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';
import 'package:fede/ui/productores/imagenes_productor.dart';
import 'package:fede/ui/widgets/lista_paginada.dart';
import 'miniatura_prueba.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final ancho in [1600, 1200, 430]) {
    testWidgets('lista general con ficha adaptativa a $ancho px', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = Size(ancho.toDouble(), 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _ApiProductores();
        final tema = PreferenciaTema();
        addTearDown(tema.dispose);
        await tester.pumpWidget(
          TemaScope(
            preferencia: tema,
            child: PadronScope(
              padron: Padron(api: api),
              child: const MaterialApp(home: Inicio()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final lista = find.byType(ListaPaginada<Productor>);
        final estadoLista = tester.state(lista);
        final scrollLista = find
            .descendant(of: lista, matching: find.byType(Scrollable))
            .first;
        await tester.drag(lista, const Offset(0, -380));
        await tester.pumpAndSettle();
        final posicion = tester
            .state<ScrollableState>(scrollLista)
            .position
            .pixels;
        final primeraFila = find.byType(FilaProductor).hitTestable().first;
        final id = tester.widget<FilaProductor>(primeraFila).productor.id;
        await tester.tap(primeraFila);
        await tester.pumpAndSettle();
        final ficha = find.byType(ProductorDetallePagina);
        expect(ficha, findsOneWidget);
        expect(find.text('NOMBRE$id'), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (ancho == 430) {
          expect(lista, findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(lista, findsOneWidget);
          expect(tester.state(lista), same(estadoLista));
          expect(
            tester.state<ScrollableState>(scrollLista).position.pixels,
            closeTo(posicion, 1),
          );
          return;
        }

        expect(tester.state(lista), same(estadoLista));
        expect(
          tester.getRect(lista).right,
          lessThan(tester.getRect(ficha).left),
        );
        expect(
          tester.state<ScrollableState>(scrollLista).position.pixels,
          closeTo(posicion, 1),
        );
        expect(find.text('Central'), findsOneWidget);
        expect(find.text('Sindicato'), findsOneWidget);
        expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
          ancho == 1600,
        );

        if (ancho == 1600) {
          final estadoFicha = tester.state(ficha);
          tester.view.physicalSize = const Size(1200, 1000);
          await tester.pumpAndSettle();
          expect(tester.state(ficha), same(estadoFicha));
          expect(tester.state(lista), same(estadoLista));
          expect(
            tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
            isFalse,
          );
          // También se conserva la lista al reducir al ancho de un teléfono.
          tester.view.physicalSize = const Size(430, 1000);
          await tester.pumpAndSettle();
          expect(lista, findsNothing);
          expect(tester.state(ficha), same(estadoFicha));
          tester.view.physicalSize = const Size(1200, 1000);
          await tester.pumpAndSettle();
          expect(tester.state(lista), same(estadoLista));
        }

        final otraFila = find.byType(FilaProductor).hitTestable().last;
        final otroId = tester.widget<FilaProductor>(otraFila).productor.id;
        await tester.tap(otraFila);
        await tester.pumpAndSettle();
        expect(find.text('NOMBRE$otroId'), findsOneWidget);
        expect(
          tester.widget<ProductorDetallePagina>(ficha).productorId,
          otroId,
        );

        await tester.tap(find.byTooltip('Marcar como observado'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), 'Revisar datos');
        await tester.tap(find.text('Guardar observación'));
        await tester.pumpAndSettle();
        final filaObservada = tester
            .widgetList<FilaProductor>(find.byType(FilaProductor))
            .firstWhere((fila) => fila.productor.id == otroId);
        expect(filaObservada.productor.observado, isTrue);
        expect(ficha, findsOneWidget);
        expect(
          tester.state<ScrollableState>(scrollLista).position.pixels,
          closeTo(posicion, 1),
        );

        // Simula el guardado de una nueva foto y datos, sin cerrar la ficha.
        final miniatura = '/miniatura-nueva-$otroId.png';
        await prepararMiniaturaPrueba(tester, miniatura);
        api.actualizados.add(otroId);
        tester
            .widget<ImagenesProductor>(find.byType(ImagenesProductor))
            .alCambiar();
        await tester.pumpAndSettle();
        final filaConFoto = tester
            .widgetList<FilaProductor>(find.byType(FilaProductor))
            .firstWhere((fila) => fila.productor.id == otroId);
        expect(filaConFoto.productor.nombres, 'ACTUALIZADO$otroId');
        expect(filaConFoto.productor.miniaturaUrl, miniatura);
        expect(filaConFoto.seleccionado, isTrue);
        expect(ficha, findsOneWidget);
        expect(
          tester.state<ScrollableState>(scrollLista).position.pixels,
          closeTo(posicion, 1),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(ficha, findsNothing);
        expect(tester.state(lista), same(estadoLista));
        final filaActualizada = tester
            .widgetList<FilaProductor>(find.byType(FilaProductor))
            .firstWhere((fila) => fila.productor.id == otroId);
        expect(filaActualizada.productor.observado, isTrue);
        expect(filaActualizada.seleccionado, isTrue);
        expect(
          tester.state<ScrollableState>(scrollLista).position.pixels,
          closeTo(posicion, 1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}

class _ApiProductores extends ApiClient {
  final Set<int> observados = {};
  final Set<int> actualizados = {};

  Map<String, dynamic> productor(int id) => {
    'id': id,
    'nombres': actualizados.contains(id) ? 'ACTUALIZADO$id' : 'NOMBRE$id',
    'apellidos': 'APELLIDO',
    'nombreCompleto': actualizados.contains(id)
        ? 'ACTUALIZADO$id APELLIDO'
        : 'NOMBRE$id APELLIDO',
    'miniaturaUrl': actualizados.contains(id)
        ? '/miniatura-nueva-$id.png'
        : null,
    'ci': '$id',
    'sindicatoId': 30,
    'sindicatoNombre': 'SINDICATO DE PRUEBA',
    'centralId': 20,
    'centralNombre': 'CENTRAL DE PRUEBA',
    'observado': observados.contains(id),
    'observacion': observados.contains(id) ? 'Revisar datos' : null,
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/centrales') return <dynamic>[];
    if (ruta == '/productores') {
      return {
        'content': [for (var id = 1; id <= 25; id++) productor(id)],
        'page': {'size': 25, 'number': 0, 'totalElements': 25, 'totalPages': 1},
      };
    }
    if (RegExp(r'^/productores/\d+$').hasMatch(ruta)) {
      return {
        'productor': productor(int.parse(ruta.split('/').last)),
        'lotes': [],
        'imagenes': [],
      };
    }
    return <dynamic>[];
  }

  @override
  Future<Object?> parchear(String ruta, {Object? cuerpo}) async {
    final id = int.parse(ruta.split('/')[2]);
    observados.add(id);
    return productor(id);
  }
}
