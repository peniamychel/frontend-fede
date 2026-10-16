import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/ui/credenciales/fuentes_bajo_demanda.dart';

import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/editor_credencial_pagina.dart';
import 'package:fede/ui/credenciales/tarjeta_previa.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await Future.wait(FuenteCredencial.values.map(cargarFuenteCredencial));
  });
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
    expect(find.text('Horizontal'), findsNothing);
    expect(find.text('Vertical'), findsNothing);

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

  test(
    'el diseño de operadores usa rutas independientes en todas las acciones',
    () async {
      final api = _ApiDiseno();
      final repositorio = DisenoCredencialRepository(
        api,
        ruta: '/configuracion/credencial-operador',
      );
      await repositorio.obtener();
      expect(api.ultimaRuta, '/configuracion/credencial-operador');
      await repositorio.guardar(DisenoCredencial.predeterminado());
      expect(api.ultimaRuta, '/configuracion/credencial-operador');
      await repositorio.restablecer();
      expect(api.ultimaRuta, '/configuracion/credencial-operador/restablecer');
      await repositorio.subirImagen([1, 2, 3], 'logo.png');
      expect(api.ultimaRuta, '/configuracion/credencial-operador/imagen');
      await repositorio.subirPlantilla(CaraCredencial.cara, [1], 'cara.png');
      expect(
        api.ultimaRuta,
        '/configuracion/credencial-operador/plantilla/CARA',
      );
      await repositorio.restablecerPlantilla(CaraCredencial.reverso);
      expect(
        api.ultimaRuta,
        '/configuracion/credencial-operador/plantilla/REVERSO',
      );
    },
  );

  testWidgets(
    'el editor operador no usa el diseño ni la plantilla del productor',
    (tester) async {
      final api = _ApiDiseno();
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(
            home: EditorCredencialPagina(operadores: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.ultimaRuta, '/configuracion/credencial-operador');
      expect(find.text('Editor de credenciales de operadores'), findsOneWidget);
      expect(find.text('OPERADOR DEL SOFTWARE'), findsOneWidget);
      expect(find.text('MARÍA QUISPE MAMANI'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('orienta la credencial del operador sin girar sus textos', (
    tester,
  ) async {
    final api = _ApiDiseno();
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: const MaterialApp(
          home: EditorCredencialPagina(operadores: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vertical'));
    await tester.pumpAndSettle();

    final previa = tester.widget<TarjetaPrevia>(find.byType(TarjetaPrevia));
    expect(previa.diseno!.ancho, 153.01);
    expect(previa.diseno!.alto, 242.65);
    expect(find.text('OPERADOR DEL SOFTWARE'), findsOneWidget);
    final campo = previa.diseno!.elementos.single;
    expect(campo.x / previa.diseno!.ancho, closeTo(20 / 242.65, .00001));
    expect(campo.y / previa.diseno!.alto, closeTo(70 / 153.01, .00001));
    await tester.tap(find.text('Guardar diseño'));
    await tester.pumpAndSettle();
    final enviado = api.ultimoCuerpo as Map<String, dynamic>;
    expect(enviado['ancho'], 153.01);
    expect(enviado['alto'], 242.65);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el diseño verde requiere confirmar antes de restablecer', (
    tester,
  ) async {
    final api = _ApiDiseno();
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: const MaterialApp(
          home: EditorCredencialPagina(operadores: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar diseño vertical verde'));
    await tester.pumpAndSettle();
    expect(api.ultimaRuta, '/configuracion/credencial-operador');
    expect(find.textContaining('Los datos y fotografías'), findsOneWidget);
    await tester.tap(find.text('Aplicar diseño'));
    await tester.pumpAndSettle();
    expect(api.ultimaRuta, '/configuracion/credencial-operador/restablecer');
    expect(tester.takeException(), isNull);
  });

  test('cambiar orientación conserva campos y la fotografía circular', () {
    final base = DisenoCredencial.predeterminado();
    final circular = base.conElementos([
      for (final e in base.elementos)
        e.campo == 'FOTO' ? e.copiar(circular: true) : e,
    ]);
    final vertical = circular.conOrientacion(OrientacionCredencial.vertical);
    expect(vertical.ancho, base.alto);
    expect(vertical.alto, base.ancho);
    expect(vertical.elementos.length, base.elementos.length);
    final foto = vertical.elementos.firstWhere((e) => e.campo == 'FOTO');
    expect(foto.circular, isTrue);
    expect(ElementoDisenoCredencial.desdeJson(foto.aJson()).circular, isTrue);
    final anterior = Map<String, dynamic>.from(foto.aJson())
      ..remove('circular');
    expect(ElementoDisenoCredencial.desdeJson(anterior).circular, isFalse);
    final horizontal = vertical.conOrientacion(
      OrientacionCredencial.horizontal,
    );
    for (var i = 0; i < base.elementos.length; i++) {
      if (base.elementos[i].campo == 'FOTO') {
        expect(horizontal.elementos[i].ancho, 57);
        expect(horizontal.elementos[i].alto, 57);
        continue;
      }
      expect(horizontal.elementos[i].x, closeTo(base.elementos[i].x, .00001));
      expect(horizontal.elementos[i].y, closeTo(base.elementos[i].y, .00001));
      expect(
        horizontal.elementos[i].ancho,
        closeTo(base.elementos[i].ancho, .00001),
      );
      expect(
        horizontal.elementos[i].alto,
        closeTo(base.elementos[i].alto, .00001),
      );
      expect(
        horizontal.elementos[i].tamanoFuente,
        base.elementos[i].tamanoFuente,
      );
    }
  });

  test(
    'la fotografía conserva su círculo y diámetro al cambiar orientación',
    () {
      final foto = DisenoCredencial.predeterminado().elementos
          .firstWhere((e) => e.campo == 'FOTO')
          .copiar(x: 42.505, y: 125, ancho: 68, alto: 68, circular: true);
      var diseno = DisenoCredencial(
        ancho: 153.01,
        alto: 242.65,
        elementos: [foto],
      );
      for (var vuelta = 0; vuelta < 5; vuelta++) {
        final horizontal = diseno.conOrientacion(
          OrientacionCredencial.horizontal,
        );
        final actual = horizontal.elementos.single;
        expect(actual.ancho, 68);
        expect(actual.alto, 68);
        expect(
          (actual.x + 34) / horizontal.ancho,
          closeTo((foto.x + 34) / diseno.ancho, .00001),
        );
        expect(
          (actual.y + 34) / horizontal.alto,
          closeTo((foto.y + 34) / diseno.alto, .00001),
        );
        expect(actual.x + actual.ancho, lessThanOrEqualTo(horizontal.ancho));
        expect(actual.y + actual.alto, lessThanOrEqualTo(horizontal.alto));
        diseno = horizontal.conOrientacion(OrientacionCredencial.vertical);
        final devuelta = diseno.elementos.single;
        expect(devuelta.ancho, 68);
        expect(devuelta.alto, 68);
        expect(devuelta.x, closeTo(foto.x, .00001));
        expect(devuelta.y, closeTo(foto.y, .00001));
      }
    },
  );

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
  Object? ultimoCuerpo;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    ultimaRuta = ruta;
    if (ruta == '/configuracion/credencial-operador') return _editorOperador;
    return {
      'diseno': DisenoCredencial.predeterminado().aJson(),
      'camposDisponibles': [
        {'campo': 'CODIGO_PADRON', 'etiqueta': 'N° de padrón', 'tipo': 'TEXTO'},
        {'campo': 'TEXTO_FIJO', 'etiqueta': 'Texto libre', 'tipo': 'TEXTO'},
      ],
    };
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object? cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    ultimaRuta = ruta;
    ultimoCuerpo = cuerpo;
    return ruta.endsWith('/restablecer')
        ? _editorOperador
        : {..._editorOperador, 'diseno': cuerpo};
  }

  @override
  Future<Object?> eliminarConRespuesta(
    String ruta, {
    Map<String, dynamic>? query,
  }) async {
    ultimaRuta = ruta;
    return _editorOperador;
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
    if (ruta.endsWith('/imagen')) {
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

final _editorOperador = {
  'diseno': {
    'ancho': 242.65,
    'alto': 153.01,
    'elementos': [
      {
        'id': 'cargo',
        'cara': 'CARA',
        'tipo': 'TEXTO',
        'campo': 'CARGO',
        'etiqueta': 'Cargo',
        'x': 20,
        'y': 70,
        'ancho': 200,
        'alto': 12,
        'tamanoFuente': 8,
      },
    ],
  },
  'camposDisponibles': [
    {'campo': 'CARGO', 'etiqueta': 'Cargo', 'tipo': 'TEXTO'},
    {'campo': 'RESENA', 'etiqueta': 'Reseña', 'tipo': 'TEXTO'},
  ],
};
