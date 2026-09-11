import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_formulario.dart';

/// Alta de un productor con su parcela y su clasificación.
///
/// Lo que se comprueba es el encadenado, que es donde está el riesgo: crear al
/// productor y darle la parcela con **su** id. Si alguno de los dos eslabones
/// se arma con el id equivocado, la tierra termina a nombre de otro y nadie se
/// entera hasta que alguien reclama.
void main() {
  const sindicato = Sindicato(
    id: 7,
    nombre: 'LIBERTAD',
    centralId: 3,
    centralNombre: 'IVIRGARZAMA',
  );

  late _ApiEspia espia;

  void ventanaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget banco() => TemaScope(
    preferencia: PreferenciaTema(),
    child: PadronScope(
      padron: Padron(api: espia),
      child: const MaterialApp(
        home: ProductorFormulario(sindicatoFijo: sindicato),
      ),
    ),
  );

  Future<void> abrir(WidgetTester tester) async {
    ventanaAlta(tester);
    await tester.pumpWidget(banco());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(
        of: find.text('Cédula de identidad *'),
        matching: find.byType(TextFormField),
      ),
      '9990001',
    );
    await tester.tap(find.byTooltip('Verificar cédula'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(
        of: find.text('Nombres *'),
        matching: find.byType(TextFormField),
      ),
      'JUAN',
    );
  }

  Future<void> registrar(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Registrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
  }

  setUp(() => espia = _ApiEspia());

  testWidgets('sin parcela solo se crea el productor', (tester) async {
    await abrir(tester);
    await registrar(tester);

    expect(espia.creados.keys, ['/productores']);
    expect(find.text('Ficha del productor'), findsOneWidget);
  });

  testWidgets('con parcela nueva, la parcela se crea a nombre del productor', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();

    expect(find.text('Extensión'), findsNothing);
    await tester.enterText(
      find.ancestor(
        of: find.text('N° de parcela *'),
        matching: find.byType(TextFormField),
      ),
      '77',
    );
    await registrar(tester);

    final lote = espia.creados['/lotes']!;
    expect(lote['numero'], '77');
    expect(lote['sindicatoId'], sindicato.id);
    expect(
      lote['productorId'],
      _ApiEspia.idProductor,
      reason: 'la parcela tiene que quedar a nombre del que se acaba de crear',
    );
  });

  testWidgets('con parcela existente se traspasa, no se crea otra', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.text('Existente'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Lote?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50-A').last);
    await tester.pumpAndSettle();
    await registrar(tester);

    expect(
      espia.creados.containsKey('/lotes'),
      isFalse,
      reason: 'la parcela ya existía',
    );
    expect(
      espia.reemplazados['/lotes/${_ApiEspia.idLoteLibre}/tenencia'],
      isNotNull,
    );
    expect(
      espia
          .reemplazados['/lotes/${_ApiEspia.idLoteLibre}/tenencia']!['productorId'],
      _ApiEspia.idProductor,
    );
  });

  testWidgets('la parcela nueva lleva su clasificación', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(
        of: find.text('N° de parcela *'),
        matching: find.byType(TextFormField),
      ),
      '77',
    );
    await registrar(tester);

    expect(espia.creados['/lotes']!['estado'], 'BLANCO');
  });

  testWidgets('avisa ocupantes y próxima letra del número repetido', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(
        of: find.text('N° de parcela *'),
        matching: find.byType(TextFormField),
      ),
      '77',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Se asignará la letra B'), findsOneWidget);
    expect(find.textContaining('OTRO'), findsOneWidget);
  });

  testWidgets('elegir Sistema clasifica sin pedir un equipo', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(
        of: find.text('N° de parcela *'),
        matching: find.byType(TextFormField),
      ),
      '77',
    );
    await tester.tap(find.byType(DropdownButtonFormField<EstadoLote>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sistema').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('se asignará la letra A'), findsOneWidget);
    expect(find.text('Sistema que se instalará *'), findsNothing);
    expect(find.textContaining('Crealo primero'), findsNothing);
    await registrar(tester);

    expect(espia.creados['/lotes']!['estado'], 'CON_SISTEMA');
    expect(espia.consultasSistemas, 0);
  });
}

/// Un ApiClient que anota lo que se le pide y responde lo mínimo válido.
class _ApiEspia extends ApiClient {
  static const int idProductor = 42;
  static const int idLote = 99;
  static const int idLoteLibre = 55;

  /// Ruta → cuerpo enviado.
  final Map<String, Map<String, dynamic>> creados = {};
  final Map<String, Map<String, dynamic>> reemplazados = {};
  int consultasSistemas = 0;

  /// El backend manda `codigo` ya armado; el modelo lo lee tal cual y no lo
  /// deriva de numero + extension.
  Map<String, dynamic> _lote(int id, {Map<String, dynamic>? tenedor}) => {
    'id': id,
    'numero': id == idLoteLibre ? '50' : '77',
    // Estas subdivisiones históricas no separan los grupos automáticos.
    'extension': id == idLoteLibre
        ? 'A'
        : id == 70
        ? 'B'
        : null,
    'codigo': id == idLoteLibre
        ? '50-A'
        : id == 70
        ? '77-B'
        : '77',
    'sindicatoId': 7,
    'sindicatoNombre': 'LIBERTAD',
    'estado': 'BLANCO',
    'tenedor': tenedor,
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta.startsWith('/lotes')) {
      // Una libre y una tomada: solo la libre puede ofrecerse.
      return [
        _lote(idLoteLibre),
        _lote(
          70,
          tenedor: {'productorId': 1, 'nombre': 'OTRO', 'desde': '2026-08-01'},
        ),
      ];
    }
    if (ruta == '/sistemas') {
      consultasSistemas++;
      return <dynamic>[];
    }
    return <dynamic>[];
  }

  @override
  Future<Object?> crear(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    if (ruta == '/personas/consulta') {
      return {'estado': 'NO_ENCONTRADA', 'mensaje': 'No existe en SIE'};
    }
    creados[ruta] = cuerpo as Map<String, dynamic>;
    if (ruta == '/lotes') {
      return _lote(idLote);
    }
    return {
      'id': idProductor,
      'nombres': 'JUAN',
      'nombreCompleto': 'JUAN',
      'sindicatoId': 7,
      'sindicatoNombre': 'LIBERTAD',
      'centralId': 3,
      'centralNombre': 'IVIRGARZAMA',
    };
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    reemplazados[ruta] = cuerpo as Map<String, dynamic>;
    return _lote(
      ruta.contains('$idLoteLibre') ? idLoteLibre : idLote,
      tenedor: {
        'productorId': idProductor,
        'nombre': 'JUAN',
        'desde': '2026-08-01',
      },
    );
  }
}
