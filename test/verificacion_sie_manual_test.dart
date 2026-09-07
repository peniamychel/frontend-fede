import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';

void main() {
  testWidgets('permite verificar manualmente un productor existente', (
    tester,
  ) async {
    final api = _ApiVerificacionManual();
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);

    await tester.pumpWidget(
      TemaScope(
        preferencia: tema,
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(
            home: ProductorDetallePagina(productorId: 43),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.verificaciones, 0);
    // Cuando hay una foto cargada, el resumen no muestra información
    // redundante; la fotografía se consulta en su sección propia.
    expect(find.text('Fotografía'), findsOneWidget);
    expect(find.text('Sin foto'), findsNothing);
    expect(find.text('Marcado'), findsNothing);
    expect(find.text('Fecha de creación'), findsOneWidget);
    expect(find.text('23/08/2026 14:05'), findsOneWidget);
    await tester.tap(find.byTooltip('Verificar con SIE'));
    await tester.pumpAndSettle();

    expect(find.text('¿Verificar con SIE?'), findsOneWidget);
    expect(
      find.text(
        'Se consultará la cédula 654321. Si SIE devuelve nombres o apellidos '
        'diferentes, podrás revisarlos y decidir si querés reemplazarlos.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Verificar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(api.verificaciones, 1);
    expect(api.aceptado, isFalse);
    expect(find.text('El nombre no coincide con SIE'), findsOneWidget);
    await tester.tap(find.text('Sí, reemplazar'));
    await tester.pumpAndSettle();
    expect(api.aceptado, isTrue);
    expect(find.text('Corrección SIE aceptada'), findsOneWidget);
    expect(find.text('MARÍA NÚÑEZ'), findsOneWidget);
  });
}

class _ApiVerificacionManual extends ApiClient {
  int verificaciones = 0;
  bool aceptado = false;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/43') {
      final corregido = aceptado;
      return {
        'productor': {
          'id': 43,
          'nombres': corregido ? 'MARÍA' : 'MARIA',
          'apellidos': corregido ? 'NÚÑEZ' : 'NUNEZ',
          'nombreCompleto': corregido ? 'MARÍA NÚÑEZ' : 'MARIA NUNEZ',
          'ci': '654321',
          'sindicatoId': 7,
          'sindicatoNombre': 'LIBERTAD',
          'centralId': 3,
          'centralNombre': 'IVIRGARZAMA',
          'revisionSiePendiente': false,
          if (corregido) ...{
            'revisionSieEstado': 'CORREGIDO_SIE',
            'revisionSieMensaje':
                'Los nombres y apellidos se corrigieron con SIE.',
            'revisionSieBloqueaImpresion': false,
          },
          'auditoria': {'estado': true, 'creadoEn': '2026-08-23T14:05:00'},
        },
        'lotes': <dynamic>[],
        'imagenes': [
          {
            'tipo': 'ORIGINAL',
            'url': '/api/v1/productores/43/imagen/ORIGINAL',
            'tipoMime': 'image/png',
            'tamanoBytes': 1024,
            'ancho': 384,
            'alto': 384,
            'nombreOriginal': 'foto-productor.png',
            'actualizadaEn': '2026-08-23T14:10:00',
          },
        ],
      };
    }
    return <dynamic>[];
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta == '/productores/43/verificacion-sie') {
      verificaciones++;
      return {
        'estado': 'REQUIERE_CONFIRMACION',
        'completada': false,
        'datosModificados': false,
        'actuales': {'ci': '654321', 'nombres': 'MARIA', 'apellidos': 'NUNEZ'},
        'propuestos': {
          'ci': '654321',
          'nombres': 'MARÍA',
          'apellidos': 'NÚÑEZ',
        },
      };
    }
    if (ruta == '/productores/43/revision-sie/confirmacion') {
      aceptado = (cuerpo as Map)['aceptar'] as bool;
      return {
        'estado': 'CORREGIDA',
        'completada': true,
        'datosModificados': true,
        'mensaje': 'SIE encontró diferencias y corrigió los datos.',
      };
    }
    return <String, dynamic>{};
  }
}
