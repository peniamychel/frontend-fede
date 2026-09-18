import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';
import 'package:fede/ui/productores/imagenes_productor.dart';

const _central = 'CENTRAL REGIONAL DE PRODUCTORES TRECE DE JUNIO';
const _sindicato = 'SINDICATO AGRARIO PRIMERO DE MAYO DE CARRASCO TROPICAL';

void main() {
  testWidgets('destaca nombres, apellidos, cédula y lote en tres líneas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);
    await tester.pumpWidget(
      TemaScope(
        preferencia: tema,
        child: PadronScope(
          padron: Padron(api: _ApiDetalle(conLote: true)),
          child: const MaterialApp(
            home: ProductorDetallePagina(productorId: 42),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nombres = find.descendant(
      of: find.byKey(const ValueKey('productor-nombres')),
      matching: find.byType(Text),
    );
    final apellidos = find.descendant(
      of: find.byKey(const ValueKey('productor-apellidos')),
      matching: find.byType(Text),
    );
    final cedulaLote = find.descendant(
      of: find.byKey(const ValueKey('productor-cedula-lote')),
      matching: find.byType(Text),
    );
    expect(find.text('MARÍA'), findsOneWidget);
    expect(find.text('PÉREZ'), findsOneWidget);
    expect(find.text('C.I.: 123456   N.° de lote: 15 A'), findsOneWidget);

    final textos = [
      tester.widget<Text>(nombres),
      tester.widget<Text>(apellidos),
      tester.widget<Text>(cedulaLote),
    ];
    expect(textos.map((texto) => texto.style?.fontSize).toSet(), hasLength(1));
    expect(textos.every((texto) => texto.maxLines == 1), isTrue);
    expect(
      tester.getTopLeft(nombres).dy,
      lessThan(tester.getTopLeft(apellidos).dy),
    );
    expect(
      tester.getTopLeft(apellidos).dy,
      lessThan(tester.getTopLeft(cedulaLote).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserva el scroll al recargar después de subir la foto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);
    final api = _ApiDetalle(conFoto: true);
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
    await tester.scrollUntilVisible(
      find.text('Fotografía'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final antes = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(antes, greaterThan(0));
    final carga = Completer<void>();
    api.esperaDetalle = carga.future;
    tester
        .widget<ImagenesProductor>(find.byType(ImagenesProductor))
        .alCambiar();
    await tester.pump();
    expect(find.byType(ImagenesProductor), findsNothing);
    carga.complete();
    await tester.pumpAndSettle();
    final despues = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(despues, closeTo(antes, 1));
    expect(find.text('Fotografía').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra una fotografía sin contar ni describir la miniatura', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);
    await tester.pumpWidget(
      TemaScope(
        preferencia: tema,
        child: PadronScope(
          padron: Padron(api: _ApiDetalle(conFoto: true)),
          child: const MaterialApp(
            home: ProductorDetallePagina(productorId: 42),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsOneWidget);
    for (final texto in [
      'MARÍA',
      'PÉREZ',
      'Central: $_central',
      'Sindicato: $_sindicato',
    ]) {
      expect(
        find.ancestor(
          of: find.text(texto),
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Fotografía'), findsOneWidget);
    expect(find.text('Fotografías'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.textContaining('Miniatura', findRichText: true), findsNothing);
    expect(find.textContaining('128 × 128', findRichText: true), findsNothing);
    expect(
      find.textContaining('409 × 409', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('foto.png', findRichText: true), findsOneWidget);
    expect(find.text('Reemplazar'), findsOneWidget);
    expect(find.text('Borrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final ancho in [320.0, 390.0, 1024.0]) {
    for (final escala in [1.0, 1.5]) {
      testWidgets('nombres completos a $ancho px y texto $escala', (
        tester,
      ) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final tema = PreferenciaTema();
        addTearDown(tema.dispose);
        await tester.pumpWidget(
          TemaScope(
            preferencia: tema,
            child: PadronScope(
              padron: Padron(api: _ApiDetalle()),
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(escala)),
                  child: child!,
                ),
                home: const ProductorDetallePagina(productorId: 42),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final texto in ['Central: $_central', 'Sindicato: $_sindicato']) {
          final finder = find.text(texto);
          expect(finder, findsOneWidget);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final widget = tester.widget<Text>(finder);
          expect(widget.maxLines, isNull);
          expect(widget.softWrap, isTrue);
          expect(widget.overflow, isNot(TextOverflow.ellipsis));
          final textoRenderizado = find.descendant(
            of: finder,
            matching: find.byType(RichText),
          );
          expect(textoRenderizado, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            textoRenderizado,
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final cajas = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: texto.length),
          );
          expect(cajas, isNotEmpty);
          expect(
            cajas.last.bottom,
            lessThanOrEqualTo(paragraph.size.height + 1),
          );
          // La selección de una línea incluye el espacio que provocó el salto,
          // aunque ese espacio se dibuje fuera del ancho. Comprobar las letras.
          for (var i = 0; i < texto.length; i++) {
            if (texto[i].trim().isEmpty) continue;
            final letras = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: i, extentOffset: i + 1),
            );
            for (final caja in letras) {
              expect(caja.right, lessThanOrEqualTo(paragraph.size.width + 1));
            }
          }
        }
        expect(find.byTooltip('Editar'), findsOneWidget);
        expect(find.byTooltip('Verificar con SIE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _ApiDetalle extends ApiClient {
  _ApiDetalle({this.conFoto = false, this.conLote = false});
  final bool conFoto;
  final bool conLote;
  Future<void>? esperaDetalle;
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/42') {
      await esperaDetalle;
      return {
        'productor': {
          'id': 42,
          'nombres': 'MARÍA',
          'apellidos': 'PÉREZ',
          'nombreCompleto': 'MARÍA PÉREZ',
          'ci': '123456',
          'codigoPadron': '213J100',
          'sindicatoId': 7,
          'sindicatoNombre': _sindicato,
          'centralId': 3,
          'centralNombre': _central,
          'auditoria': {'estado': false},
        },
        'lotes': [
          if (conLote)
            {
              'id': 9,
              'numero': '15',
              'extension': 'A',
              'codigo': '15 A',
              'estado': 'CON_SISTEMA',
              'sindicatoId': 7,
              'sindicatoNombre': _sindicato,
            },
        ],
        'imagenes': [
          if (conFoto) ...[
            {
              'tipo': 'ORIGINAL',
              'url': '/foto.png',
              'ancho': 409,
              'alto': 409,
              'tamanoBytes': 231424,
              'nombreOriginal': 'foto.png',
            },
            {
              'tipo': 'MINIATURA',
              'url': '/mini.png',
              'ancho': 128,
              'alto': 128,
              'tamanoBytes': 25600,
            },
          ],
        ],
      };
    }
    return <dynamic>[];
  }
}
