import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/editor_credencial_pagina.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  Widget pantalla() => PadronScope(
    padron: Padron(api: _ApiDiseno()),
    child: const MaterialApp(home: EditorCredencialPagina()),
  );

  testWidgets('permite cambiar de cara y agregar otro campo', (tester) async {
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();

    expect(find.text('Editor del carnet'), findsOneWidget);
    expect(find.text('Cara'), findsOneWidget);
    expect(find.text('Reverso'), findsOneWidget);
    expect(find.text('Guardar diseño'), findsOneWidget);

    final antes = find.text('N° de padrón').evaluate().length;
    final agregar = find.byTooltip('Agregar campo');
    await tester.ensureVisible(agregar);
    await tester.tap(agregar);
    await tester.pump();
    expect(find.text('N° de padrón').evaluate().length, greaterThan(antes));

    final reverso = find.text('Reverso');
    await tester.ensureVisible(reverso);
    await tester.tap(reverso);
    await tester.pump();
    expect(find.text('Sello federación'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('la ruta conserva la barra después de /api/v1', () async {
    final api = _ApiDiseno();
    await DisenoCredencialRepository(api).obtener();
    expect(api.ultimaRuta, '/configuracion/credencial');
  });

  testWidgets('la plantilla es un objeto que puede subir y bajar de nivel', (
    tester,
  ) async {
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();

    final campo = find.widgetWithText(ChoiceChip, 'Plantilla');
    await tester.ensureVisible(campo);
    await tester.tap(campo);
    await tester.pump();

    final bajar = find.widgetWithText(OutlinedButton, 'Bajar');
    final subir = find.widgetWithText(FilledButton, 'Subir');
    await tester.ensureVisible(subir);
    expect(tester.widget<OutlinedButton>(bajar).onPressed, isNull);
    expect(tester.widget<FilledButton>(subir).onPressed, isNotNull);

    await tester.tap(subir);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(bajar).onPressed, isNotNull);
  });

  test('sube una imagen independiente para insertarla como objeto', () async {
    final api = _ApiDiseno();
    final imagen = await DisenoCredencialRepository(
      api,
    ).subirImagen([4, 5, 6], 'escudo.png');

    expect(api.ultimaRuta, '/configuracion/credencial/imagen');
    expect(api.ultimoCampo, 'archivo');
    expect(api.ultimoNombre, 'escudo.png');
    expect(imagen.clave, contains('configuracion/credencial/objetos/'));
  });

  test('el diseño predeterminado conserva una plantilla por cada cara', () {
    final plantillas = DisenoCredencial.predeterminado().elementos
        .where((e) => e.tipo == TipoElementoCredencial.plantilla)
        .toList();

    expect(plantillas, hasLength(2));
    expect(
      plantillas.map((e) => e.cara).toSet(),
      CaraCredencial.values.toSet(),
    );
  });

  test('los diseños anteriores usan Roboto y guardan la fuente elegida', () {
    final original = DisenoCredencial.predeterminado().elementos.firstWhere(
      (e) => e.tipo == TipoElementoCredencial.texto,
    );
    final anterior = Map<String, dynamic>.from(original.aJson())
      ..remove('fuente');

    expect(
      ElementoDisenoCredencial.desdeJson(anterior).fuente,
      FuenteCredencial.roboto,
    );
    expect(
      original.copiar(fuente: FuenteCredencial.montserrat).aJson()['fuente'],
      'MONTSERRAT',
    );
    expect(FuenteCredencial.values, hasLength(13));
    for (final fuente in FuenteCredencial.values) {
      final json = original.copiar(fuente: fuente).aJson();
      expect(
        ElementoDisenoCredencial.desdeJson(json).fuente,
        fuente,
        reason: 'La fuente ${fuente.etiqueta} debe conservarse al guardar',
      );
    }
  });

  testWidgets('permite elegir una fuente formal para cada texto', (
    tester,
  ) async {
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();

    final campo = find.widgetWithText(ChoiceChip, 'N° de padrón').first;
    await tester.ensureVisible(campo);
    await tester.tap(campo);
    await tester.pumpAndSettle();

    expect(find.text('Tipo de letra'), findsOneWidget);
    final selector = find.byType(DropdownButtonFormField<FuenteCredencial>);
    expect(selector, findsOneWidget);
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.textContaining('Montserrat'), findsWidgets);
    expect(find.textContaining('Merriweather'), findsOneWidget);
  });

  test('sube una plantilla para la cara seleccionada', () async {
    final api = _ApiDiseno();
    final editor = await DisenoCredencialRepository(
      api,
    ).subirPlantilla(CaraCredencial.reverso, [1, 2, 3], 'nueva.jpg');

    expect(api.ultimaRuta, '/configuracion/credencial/plantilla/REVERSO');
    expect(api.ultimoCampo, 'archivo');
    expect(api.ultimoNombre, 'nueva.jpg');
    expect(editor.plantillaReversoUrl, isNotNull);
  });
}

class _ApiDiseno extends ApiClient {
  String? ultimaRuta;
  String? ultimoCampo;
  String? ultimoNombre;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    ultimaRuta = ruta;
    return {
      'diseno': DisenoCredencial.predeterminado().aJson(),
      'camposDisponibles': [
        {'campo': 'CODIGO_PADRON', 'etiqueta': 'N° de padrón', 'tipo': 'TEXTO'},
        {'campo': 'TEXTO_FIJO', 'etiqueta': 'Texto libre', 'tipo': 'TEXTO'},
      ],
    };
  }

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
    ultimaRuta = ruta;
    ultimoCampo = campo;
    ultimoNombre = nombreArchivo;
    if (ruta == '/configuracion/credencial/imagen') {
      return {
        'clave':
            'configuracion/credencial/objetos/123e4567-e89b-12d3-a456-426614174000.png',
        'url':
            '/api/v1/archivos/configuracion/credencial/objetos/123e4567-e89b-12d3-a456-426614174000.png',
      };
    }
    return {
      'diseno': DisenoCredencial.predeterminado().aJson(),
      'camposDisponibles': const [],
      'plantillaReversoUrl':
          '/api/v1/configuracion/credencial/plantilla/REVERSO?v=1',
    };
  }
}
