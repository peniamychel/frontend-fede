import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';

const _central = 'CENTRAL REGIONAL DE PRODUCTORES TRECE DE JUNIO';
const _sindicato = 'SINDICATO AGRARIO PRIMERO DE MAYO DE CARRASCO TROPICAL';

void main() {
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
      'MARÍA PÉREZ',
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
  _ApiDetalle({this.conFoto = false});
  final bool conFoto;
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/42') {
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
        'lotes': <dynamic>[],
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
