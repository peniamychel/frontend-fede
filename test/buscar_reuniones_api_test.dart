@Tags(['integracion'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Dividir las reuniones por tipo y buscarlas, contra el backend real.
///
/// Con los años la lista se hace larga, así que se entra por dos caminos: las
/// solapas por tipo, y un buscador que mira el detalle de la reunión **y** los
/// vetos que ahí se decidieron. «¿En qué reunión vetaron a Fulano?» es una
/// pregunta que se hace sola, y sin eso habría que abrir asamblea por asamblea.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/buscar_reuniones_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Uint8List acta;

  late Federacion fede;
  late Central central;
  late Sindicato sindicato;
  late Productor sancionado;

  final reuniones = <Reunion>[];

  Future<Reunion> convocar(
    TipoReunion tipo,
    int convocanteId,
    String titulo, {
    String fecha = '2026-05-05',
    String? lugar,
    String? observaciones,
    bool vetos = false,
  }) async {
    final r = await padron.reuniones.crear(ReunionRequest(
      tipo: tipo,
      convocanteId: convocanteId,
      titulo: titulo,
      fecha: DateTime.parse(fecha),
      lugar: lugar,
      observaciones: observaciones,
      vetosHabilitados: vetos,
    ));
    reuniones.add(r);
    return r;
  }

  /// Los ids que trae una búsqueda, para comparar sin depender del orden de
  /// otras reuniones del padrón real.
  Future<Set<int>> buscar({TipoReunion? tipo, String? texto}) async =>
      (await padron.reuniones.listar(tipo: tipo, texto: texto))
          .map((r) => r.id)
          .toSet();

  setUpAll(() async {
    padron = Padron();
    acta = Uint8List.fromList(
        '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'
            .codeUnits);

    fede = await padron.federaciones
        .crear(const FederacionRequest(nombre: 'ZZZ BUSCA FED', numero: '66'));
    central = await padron.centrales.crear(CentralRequest(
        nombre: 'ZZZ BUSCA CEN', abreviatura: 'BUS', federacionId: fede.id));
    sindicato = await padron.sindicatos.crear(
        SindicatoRequest(nombre: 'ZZZ BUSCA SIN', centralId: central.id));
    sancionado = await padron.productores.crear(ProductorRequest(
        nombres: 'ZZZ RIGOBERTO',
        apellidos: 'MAMANI SILES',
        ci: '77665544',
        sindicatoId: sindicato.id));
  });

  tearDownAll(() async {
    try {
      await padron.productores.eliminar(sancionado.id);
    } on ApiException {
      // Ya no estaba.
    }
    for (final r in reuniones) {
      try {
        await padron.reuniones.eliminar(r.id);
      } on ApiException {
        // Ídem.
      }
    }
    try {
      await padron.sindicatos.eliminar(sindicato.id);
      await padron.centrales.eliminar(central.id);
      await padron.federaciones.eliminar(fede.id);
    } on ApiException {
      // Lo importante ya se limpió.
    } finally {
      padron.cerrar();
    }
  });

  group('por tipo', () {
    late Reunion deSindicato;
    late Reunion ampliado;

    setUpAll(() async {
      deSindicato = await convocar(
          TipoReunion.sindicato, sindicato.id, 'ZZZ ORDINARIA DE MAYO');
      ampliado = await convocar(
          TipoReunion.ampliado, central.id, 'ZZZ AMPLIADO DE MAYO');
    });

    test('cada tipo trae solo las suyas', () async {
      final delSindicato = await buscar(tipo: TipoReunion.sindicato);
      expect(delSindicato, contains(deSindicato.id));
      expect(delSindicato, isNot(contains(ampliado.id)));

      final ampliados = await buscar(tipo: TipoReunion.ampliado);
      expect(ampliados, contains(ampliado.id));
      expect(ampliados, isNot(contains(deSindicato.id)));
    });

    test('sin tipo vienen todas', () async {
      final todas = await buscar();
      expect(todas, containsAll([deSindicato.id, ampliado.id]));
    });

    test('el conteo por tipo coincide con lo que trae cada solapa', () async {
      // El filtro del conteo y el del listado están escritos dos veces en
      // JPQL, que no deja compartirlos. Esta prueba los ata: si uno cambia y
      // el otro no, acá se nota.
      final conteo = await padron.reuniones.conteoPorTipo();

      for (final t in TipoReunion.values) {
        expect(conteo[t], (await buscar(tipo: t)).length,
            reason: 'la solapa de ${t.etiqueta} promete un número que no da');
      }
      expect(conteo.values.fold(0, (a, b) => a + b), (await buscar()).length);
    });

    test('y también con el texto puesto', () async {
      final conteo = await padron.reuniones.conteoPorTipo(texto: 'DE MAYO');

      for (final t in TipoReunion.values) {
        expect(conteo[t], (await buscar(tipo: t, texto: 'DE MAYO')).length);
      }
      expect(conteo[TipoReunion.sindicato], 1);
      expect(conteo[TipoReunion.ampliado], 1);
      expect(conteo[TipoReunion.dirigentesFederacion], 0,
          reason: 'los tipos sin ninguna salen en cero, no ausentes');
    });
  });

  group('buscar por el detalle de la reunión', () {
    late Reunion conTodo;

    setUpAll(() async {
      conTodo = await convocar(
        TipoReunion.sindicato,
        sindicato.id,
        'ZZZ ASAMBLEA DEL CHAPARE',
        lugar: 'Sede de ZZZ VILLA TUNARI',
        observaciones: 'Se trató el ZZZ desmonte del camino',
      );
      await padron.reuniones.agregarHoja(
          reunionId: conTodo.id,
          bytes: acta,
          nombreArchivo: 'acta.pdf',
          codigo: 'ZZZ-77/2026');
    });

    test('por el título', () async {
      expect(await buscar(texto: 'CHAPARE'), contains(conTodo.id));
    });

    test('por el lugar', () async {
      expect(await buscar(texto: 'VILLA TUNARI'), contains(conTodo.id));
    });

    test('por las notas', () async {
      expect(await buscar(texto: 'desmonte'), contains(conTodo.id));
    });

    test('por el número del acta', () async {
      expect(await buscar(texto: 'ZZZ-77/2026'), contains(conTodo.id));
    });

    test('sin importar mayúsculas ni minúsculas', () async {
      expect(await buscar(texto: 'chapare'), contains(conTodo.id));
    });

    test('lo que no está en ninguna parte no trae nada', () async {
      expect(await buscar(texto: 'ZZZ NO EXISTE ESTO'), isEmpty);
    });
  });

  group('buscar por el veto', () {
    late Reunion laQueVeto;
    late Reunion laQueLevanto;
    late Reunion ajena;

    setUpAll(() async {
      laQueVeto = await convocar(TipoReunion.sindicato, sindicato.id,
          'ZZZ ASAMBLEA QUE SANCIONA',
          fecha: '2026-06-01', vetos: true);
      laQueLevanto = await convocar(TipoReunion.sindicato, sindicato.id,
          'ZZZ ASAMBLEA QUE PERDONA',
          fecha: '2026-07-01', vetos: true);
      ajena = await convocar(
          TipoReunion.sindicato, sindicato.id, 'ZZZ ASAMBLEA SIN NADA',
          fecha: '2026-06-15');

      for (final r in [laQueVeto, laQueLevanto]) {
        await padron.reuniones.agregarHoja(
            reunionId: r.id,
            bytes: acta,
            nombreArchivo: 'acta.pdf',
            codigo: 'ZZZ-V-${r.id}');
      }

      await padron.vetos.vetar(VetoRequest(
          productorId: sancionado.id,
          reunionId: laQueVeto.id,
          motivo: 'ZZZ taló monte fuera de su parcela'));
    });

    test('por el apellido de quien fue vetado', () async {
      // La reunión no lo menciona en ninguno de sus campos: la coincidencia
      // sale del veto que se decidió ahí.
      final halladas = await buscar(texto: 'MAMANI SILES');

      expect(halladas, contains(laQueVeto.id));
      expect(halladas, isNot(contains(ajena.id)));
    });

    test('por su cédula', () async {
      expect(await buscar(texto: '77665544'), contains(laQueVeto.id));
    });

    test('por su código del padrón', () async {
      final codigo = (await padron.productores.obtener(sancionado.id))
          .productor
          .codigoPadron;
      expect(codigo, isNotNull);

      expect(await buscar(texto: codigo), contains(laQueVeto.id));
    });

    test('por el motivo que quedó escrito', () async {
      expect(await buscar(texto: 'taló monte'), contains(laQueVeto.id));
    });

    test('la que levanta el veto también aparece', () async {
      // Las dos decidieron sobre esa persona, y quien busca la historia
      // completa quiere las dos.
      final veto = (await padron.vetos.historialDe(sancionado.id)).first;
      await padron.vetos.levantar(
          veto.id,
          LevantarVetoRequest(
              reunionId: laQueLevanto.id,
              motivo: 'ZZZ repuso los árboles, según el acta'));

      final halladas = await buscar(texto: 'MAMANI SILES');
      expect(halladas, containsAll([laQueVeto.id, laQueLevanto.id]));
      expect(halladas, isNot(contains(ajena.id)));
    });

    test('el tipo y el texto se combinan', () async {
      expect(
          await buscar(
              tipo: TipoReunion.sindicato, texto: 'MAMANI SILES'),
          containsAll([laQueVeto.id, laQueLevanto.id]));
      expect(
          await buscar(tipo: TipoReunion.ampliado, texto: 'MAMANI SILES'),
          isEmpty,
          reason: 'esos vetos se decidieron en reuniones de sindicato');
    });

    test('cada reunión sale una sola vez aunque coincida por varios lados',
        () async {
      // «ZZZ» está en el título, en el motivo del veto y en el nombre de la
      // persona: sin el distinct, la misma reunión vendría repetida.
      final todas = await padron.reuniones.listar(texto: 'ZZZ');
      final ids = todas.map((r) => r.id).toList();

      expect(ids.length, ids.toSet().length);
    });
  });
}
