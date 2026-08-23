import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_formulario.dart';

/// Alta de un productor con su parcela y el sistema de esa parcela.
///
/// Lo que se comprueba es el encadenado, que es donde está el riesgo: crear al
/// productor, darle la parcela con **su** id, y recién entonces instalarle el
/// sistema con el id de **esa** parcela. Si alguno de los tres eslabones se
/// arma con el id equivocado, la tierra termina a nombre de otro y nadie se
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
    await tester.enterText(
      find.ancestor(
        of: find.text('N° de parcela'),
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

  testWidgets('el sistema nuevo se instala en la parcela recién creada', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(
        of: find.text('N° de parcela'),
        matching: find.byType(TextFormField),
      ),
      '77',
    );
    // El segundo «Nuevo» de la pantalla es el del sistema.
    await tester.tap(find.text('Nuevo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.ancestor(
        of: find.text('Código del sistema *'),
        matching: find.byType(TextFormField),
      ),
      'BOMBA-1',
    );
    await registrar(tester);

    expect(espia.creados['/sistemas']!['codigo'], 'BOMBA-1');
    expect(
      espia.consultasDeTraslado.single,
      {'loteId': _ApiEspia.idLote},
      reason: 'el sistema va a la parcela que se acaba de crear',
    );
  });

  testWidgets('sin parcela no se ofrece sistema', (tester) async {
    await abrir(tester);

    expect(find.text('Sistema de la parcela'), findsNothing);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    expect(find.text('Sistema de la parcela'), findsOneWidget);
  });
}

/// Un ApiClient que anota lo que se le pide y responde lo mínimo válido.
class _ApiEspia extends ApiClient {
  static const int idProductor = 42;
  static const int idLote = 99;
  static const int idLoteLibre = 55;
  static const int idSistema = 88;

  /// Ruta → cuerpo enviado.
  final Map<String, Map<String, dynamic>> creados = {};
  final Map<String, Map<String, dynamic>> reemplazados = {};

  /// Los `query` de cada traslado de sistema: ahí viaja a qué parcela va.
  final List<Map<String, dynamic>> consultasDeTraslado = [];

  /// El backend manda `codigo` ya armado; el modelo lo lee tal cual y no lo
  /// deriva de numero + extension.
  Map<String, dynamic> _lote(int id, {Map<String, dynamic>? tenedor}) => {
    'id': id,
    'numero': id == idLoteLibre ? '50' : '77',
    'extension': id == idLoteLibre ? 'A' : null,
    'codigo': id == idLoteLibre ? '50-A' : '77',
    'sindicatoId': 7,
    'sindicatoNombre': 'LIBERTAD',
    'tenedor': tenedor,
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta.startsWith('/lotes')) {
      // Una libre y una tomada: solo la libre puede ofrecerse.
      return [
        _lote(idLoteLibre),
        _lote(70, tenedor: {'id': 1, 'nombreCompleto': 'OTRO'}),
      ];
    }
    if (ruta.startsWith('/sistemas')) {
      return [
        {'id': idSistema, 'codigo': 'RIEGO-1'},
      ];
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
    if (ruta == '/sistemas') {
      return {'id': idSistema, 'codigo': cuerpo['codigo']};
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
    if (ruta.contains('/traslado')) {
      consultasDeTraslado.add(query ?? const {});
      return {'id': idSistema, 'codigo': 'X'};
    }
    return _lote(
      ruta.contains('$idLoteLibre') ? idLoteLibre : idLote,
      tenedor: {'id': idProductor, 'nombreCompleto': 'JUAN'},
    );
  }
}
