import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/lotes/lote_pagina.dart';
import 'package:fede/ui/lotes/lotes_sindicato_pagina.dart';
import 'package:fede/ui/lotes/participantes_parcela.dart';

const _sindicato = Sindicato(
  id: 7,
  nombre: '1RO DE MAYO',
  centralId: 3,
  centralNombre: '13 DE JUNIO',
);

Map<String, dynamic> _lote(
  int id, {
  int sindicato = 7,
  String? numero = '22',
  String? nombre,
  String? letra,
  String estado = 'BLANCO',
}) => {
  'id': id, 'numero': numero, 'codigo': '$numero ${letra ?? ''}'.trim(),
  'sindicatoId': sindicato, 'sindicatoNombre': '1RO DE MAYO', 'estado': estado,
  // La letra vigente debe ganar a la extensión histórica del lote.
  'extension': 'A',
  if (nombre != null)
    'tenedor': {
      'productorId': id + 100,
      'nombre': nombre,
      'letra': letra,
      'desde': '2026-08-01',
    },
};

void main() {
  test(
    'agrupa por sindicato y número, solo con tenedor y ordena por letra vigente',
    () {
      final lotes = [
        _lote(2, numero: ' 22 ', nombre: 'CARLOS RAMOS', letra: 'B'),
        _lote(1, nombre: 'MARÍA PÉREZ', letra: 'A', estado: 'CON_SISTEMA'),
        _lote(3, sindicato: 8, nombre: 'OTRO SINDICATO', letra: 'A'),
        _lote(4), // Sin tenedor no es un productor que comparte.
        _lote(5, numero: null, nombre: 'SIN NÚMERO'),
        _lote(6, numero: ' ', nombre: 'VACÍO'),
        _lote(7, numero: '23', nombre: 'OTRO LOTE'),
      ].map(Lote.desdeJson);
      final grupos = Lote.participacionesPorNumero(lotes);
      expect(grupos.keys, containsAll([(7, '22'), (8, '22'), (7, '23')]));
      expect(grupos.length, 3);
      expect(grupos[(7, '22')]!.map((l) => l.tenedor!.nombre), [
        'MARÍA PÉREZ',
        'CARLOS RAMOS',
      ]);
      expect(grupos[(7, '22')]!.last.letraParticipacion, 'B');
      expect(grupos[(7, '22')]!.first.estado, EstadoLote.conSistema);
    },
  );

  test('normaliza mayúsculas sin mezclar números distintos', () {
    final grupos = Lote.participacionesPorNumero([
      Lote.desdeJson(_lote(1, numero: 'bn47', nombre: 'A')),
      Lote.desdeJson(_lote(2, numero: ' BN47 ', nombre: 'B')),
      Lote.desdeJson(_lote(3, numero: 'bn48', nombre: 'C')),
    ]);
    expect(grupos[(7, 'BN47')]!.length, 2);
    expect(grupos[(7, 'BN48')]!.length, 1);
  });

  testWidgets('la ficha muestra participantes y se actualiza al recargar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiCompartidas();
    await tester.pumpWidget(_pagina(api, const LotePagina(loteId: 1)));
    await tester.pumpAndSettle();
    expect(find.text('Productores del lote 22 (2)'), findsOneWidget);
    final panel = find.byType(ParticipantesParcela);
    expect(
      find.descendant(of: panel, matching: find.text('MARÍA PÉREZ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('CARLOS RAMOS')),
      findsOneWidget,
    );
    expect(find.text('Clasificación: Sistema'), findsOneWidget);
    expect(find.text('Clasificación: Blanco'), findsOneWidget);
    expect(find.text('Extensión: A'), findsOneWidget);
    expect(find.text('Extensión: B'), findsOneWidget);
    expect(find.text('OTRO SINDICATO'), findsNothing);
    expect(tester.takeException(), isNull);
    api.compartido = false;
    await tester.tap(find.byTooltip('Recargar'));
    await tester.pumpAndSettle();
    expect(find.byType(ParticipantesParcela), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la lista permite desplegar nombres, clasificación y extensión', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiCompartidas();
    await tester.pumpWidget(
      _pagina(api, const LotesSindicatoPagina(sindicato: _sindicato)),
    );
    await tester.pumpAndSettle();
    final desplegable = find.byKey(const PageStorageKey('compartidos-1'));
    await tester.ensureVisible(desplegable);
    await tester.tap(
      find.descendant(
        of: desplegable,
        matching: find.text('Ver los 2 productores del lote 22'),
      ),
    );
    await tester.pumpAndSettle();
    final panel = find.descendant(
      of: desplegable,
      matching: find.byType(ParticipantesParcela),
    );
    expect(
      find.descendant(of: panel, matching: find.text('MARÍA PÉREZ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('CARLOS RAMOS')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('Extensión: B')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: panel, matching: find.text('Clasificación: Sistema')),
      findsOneWidget,
    );
    expect(find.byTooltip('Eliminar parcela'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _pagina(ApiClient api, Widget home) => PadronScope(
  padron: Padron(api: api),
  child: MaterialApp(home: home),
);

class _ApiCompartidas extends ApiClient {
  bool compartido = true;
  Map<String, dynamic> get primero => _lote(
    1,
    nombre: 'MARÍA PÉREZ',
    letra: compartido ? 'A' : null,
    estado: 'CON_SISTEMA',
  );

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/lotes/1') return primero;
    if (ruta == '/lotes/1/historial') return <dynamic>[];
    if (ruta == '/lotes') {
      expect(query?['sindicatoId'], 7);
      return [
        primero,
        if (compartido) _lote(2, nombre: 'CARLOS RAMOS', letra: 'B'),
        // Defensa ante datos de otro sindicato: no pertenecen al mismo grupo.
        _lote(3, sindicato: 8, nombre: 'OTRO SINDICATO', letra: 'A'),
      ];
    }
    throw StateError('Consulta inesperada: $ruta');
  }
}
