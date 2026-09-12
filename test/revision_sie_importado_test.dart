import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/fila_productor.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';

void main() {
  testWidgets('revisa al importado una sola vez al abrir su ficha', (
    tester,
  ) async {
    final api = _ApiRevisionSie();
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(api.revisiones, 1);
    expect(api.decision, isNull);
    expect(find.text('El nombre no coincide con SIE'), findsOneWidget);
    expect(find.text('JOSE PENA MUNOZ'), findsOneWidget);
    expect(find.text('JOSÉ PEÑA MUÑOZ'), findsOneWidget);
    await tester.tap(find.text('Sí, reemplazar'));
    await tester.pumpAndSettle();
    expect(api.decision, isTrue);
    expect(find.text('Corrección SIE aceptada'), findsWidgets);
    expect(find.text('JOSÉ PEÑA MUÑOZ'), findsOneWidget);

    await tester.tap(find.byTooltip('Recargar'));
    await tester.pumpAndSettle();

    expect(
      api.revisiones,
      1,
      reason: 'una recarga no debe consultar SIE otra vez',
    );
  });

  for (final rechazar in [true, false]) {
    testWidgets(
      rechazar
          ? 'No conserva el nombre y guarda la sugerencia pendiente'
          : 'volver atrás conserva la sugerencia sin consultar otra vez',
      (tester) async {
        final api = _ApiRevisionSie();
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
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(api.decision, isNull);
        if (rechazar) {
          await tester.tap(find.text('No, conservar'));
        } else {
          final context = tester.element(find.byType(AlertDialog));
          Navigator.of(context).pop();
        }
        await tester.pumpAndSettle();
        expect(api.decision, rechazar ? isFalse : isNull);
        expect(find.text('JOSE PENA MUNOZ'), findsOneWidget);
        await tester.tap(find.byTooltip('Recargar'));
        await tester.pumpAndSettle();
        expect(api.revisiones, 1);
        expect(find.text('Corrección SIE pendiente'), findsOneWidget);
        expect(find.text('SIE sugiere: JOSÉ PEÑA MUÑOZ'), findsOneWidget);
        expect(find.textContaining('No se puede imprimir'), findsOneWidget);
      },
    );
  }

  testWidgets('acepta la sugerencia guardada sin volver a consultar SIE', (
    tester,
  ) async {
    final api = _ApiRevisionSie()..sugerenciaGuardada = true;
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

    expect(api.revisiones, 0);
    await tester.tap(find.text('Aceptar sugerencia SIE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar corrección'));
    await tester.pumpAndSettle();

    expect(api.decision, isTrue);
    expect(api.revisiones, 0);
    expect(find.text('Corrección SIE aceptada'), findsWidgets);
    expect(find.text('JOSÉ PEÑA MUÑOZ'), findsOneWidget);
  });

  testWidgets(
    'permite aprobar una cédula no encontrada sin editar el productor',
    (tester) async {
      final api = _ApiRevisionSie()..noEncontrado = true;
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

      expect(api.revisiones, 0);
      final titulo = find.text('No encontrado en SIE');
      expect(titulo, findsOneWidget);
      expect(find.textContaining('No se puede imprimir'), findsOneWidget);
      final tarjeta = find.ancestor(of: titulo, matching: find.byType(Card));
      expect(tester.widget<Card>(tarjeta.first).color, Colors.orange.shade100);

      await tester.tap(find.text('Aprobar datos'));
      await tester.pumpAndSettle();
      expect(find.text('¿Aprobar los datos actuales?'), findsOneWidget);
      await tester.tap(find.text('Aprobar datos actuales'));
      await tester.pumpAndSettle();

      expect(api.aprobacionesManuales, 1);
      expect(find.text('No encontrado en SIE'), findsNothing);
      expect(find.text('Datos aprobados manualmente'), findsOneWidget);
      expect(find.textContaining('No se puede imprimir'), findsNothing);
      expect(find.textContaining('Revisión SIE pendiente'), findsNothing);
    },
  );

  testWidgets(
    'la impresora queda gris con SIE pendiente aunque exista fase activa',
    (tester) async {
      final productor = Productor.desdeJson({
        'id': 42,
        'nombres': 'JOSE',
        'apellidos': 'PENA MUNOZ',
        'nombreCompleto': 'JOSE PENA MUNOZ',
        'revisionSieEstado': 'NO_ENCONTRADO',
        'revisionSieBloqueaImpresion': true,
        'credencialLista': false,
        'faseImpresionPendiente': true,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilaProductor(productor: productor, alTocar: () {}),
          ),
        ),
      );

      final tooltip = find.byTooltip(
        'Revisión SIE pendiente: excluido de impresión',
      );
      expect(tooltip, findsOneWidget);
      final icono = find.descendant(
        of: tooltip,
        matching: find.byIcon(Icons.print),
      );
      expect(
        tester.widget<Icon>(icono).color,
        Theme.of(tester.element(icono)).colorScheme.outline,
      );
    },
  );
}

class _ApiRevisionSie extends ApiClient {
  int revisiones = 0;
  bool? decision;
  bool sugerenciaGuardada = false;
  bool noEncontrado = false;
  int aprobacionesManuales = 0;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/42') {
      final aprobadoManualmente = aprobacionesManuales > 0;
      final revisado = sugerenciaGuardada || noEncontrado;
      final corregido = decision == true;
      return {
        'productor': {
          'id': 42,
          'nombres': corregido ? 'JOSÉ' : 'JOSE',
          'apellidos': corregido ? 'PEÑA MUÑOZ' : 'PENA MUNOZ',
          'nombreCompleto': corregido ? 'JOSÉ PEÑA MUÑOZ' : 'JOSE PENA MUNOZ',
          'ci': '123456',
          'sindicatoId': 7,
          'sindicatoNombre': 'LIBERTAD',
          'centralId': 3,
          'centralNombre': 'IVIRGARZAMA',
          'revisionSiePendiente': !revisado,
          if (aprobadoManualmente) ...{
            'revisionSieEstado': 'APROBADO_MANUAL',
            'revisionSieMensaje':
                'Los datos actuales fueron revisados y aprobados manualmente.',
            'revisionSieBloqueaImpresion': false,
            'revisionSiePendiente': false,
          } else if (noEncontrado) ...{
            'revisionSieEstado': 'NO_ENCONTRADO',
            'revisionSieMensaje': 'La cédula no fue encontrada en SIE.',
            'revisionSieBloqueaImpresion': true,
          } else if (corregido) ...{
            'revisionSieEstado': 'CORREGIDO_SIE',
            'revisionSieMensaje': 'Corrección aceptada.',
            'revisionSieBloqueaImpresion': false,
          } else if (sugerenciaGuardada) ...{
            'revisionSieEstado': 'DIFERENCIA_PENDIENTE',
            'revisionSieMensaje': 'Hay diferencias pendientes.',
            'sieNombresSugeridos': 'JOSÉ',
            'sieApellidosSugeridos': 'PEÑA MUÑOZ',
            'revisionSieBloqueaImpresion': true,
          },
        },
        'lotes': <dynamic>[],
        'imagenes': <dynamic>[],
      };
    }
    return <dynamic>[];
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta == '/productores/42/revision-sie') {
      revisiones++;
      sugerenciaGuardada = true;
      return {
        'estado': 'REQUIERE_CONFIRMACION',
        'completada': false,
        'datosModificados': false,
        'mensaje': 'Hay diferencias.',
        'actuales': {
          'ci': '123456',
          'nombres': 'JOSE',
          'apellidos': 'PENA MUNOZ',
        },
        'propuestos': {
          'ci': '123456',
          'nombres': 'JOSÉ',
          'apellidos': 'PEÑA MUÑOZ',
        },
      };
    }
    if (ruta == '/productores/42/revision-sie/confirmacion') {
      final datos = cuerpo as Map;
      decision = datos['aceptar'] as bool;
      expect((datos['actuales'] as Map)['nombres'], 'JOSE');
      expect((datos['propuestos'] as Map)['nombres'], 'JOSÉ');
      return {
        'estado': decision! ? 'CORREGIDA' : 'CONSERVADA',
        'completada': true,
        'datosModificados': decision,
        'mensaje': decision! ? 'Corrección aceptada.' : 'Datos conservados.',
      };
    }
    if (ruta == '/productores/42/revision-sie/aprobacion-manual') {
      aprobacionesManuales++;
      return {
        'estado': 'APROBADA_MANUAL',
        'completada': true,
        'datosModificados': false,
        'mensaje': 'Los datos actuales fueron aprobados manualmente.',
      };
    }
    return <String, dynamic>{};
  }
}
