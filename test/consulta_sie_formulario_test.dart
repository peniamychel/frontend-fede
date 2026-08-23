import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_formulario.dart';

void main() {
  const sindicato = Sindicato(
    id: 7,
    nombre: 'LIBERTAD',
    centralId: 3,
    centralNombre: 'IVIRGARZAMA',
  );

  Widget formulario(ApiClient api) => PadronScope(
    padron: Padron(api: api),
    child: const MaterialApp(
      home: ProductorFormulario(sindicatoFijo: sindicato),
    ),
  );

  void ampliar(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder campo(String etiqueta) => find.ancestor(
    of: find.text(etiqueta),
    matching: find.byType(TextFormField),
  );

  testWidgets('SIE completa nombres y apellidos y desbloquea el alta', (
    tester,
  ) async {
    ampliar(tester);
    final api = _ApiPersona();
    await tester.pumpWidget(formulario(api));
    await tester.pumpAndSettle();

    final bloqueosAntes = tester
        .widgetList<IgnorePointer>(
          find.ancestor(
            of: find.text('Nombres *'),
            matching: find.byType(IgnorePointer),
          ),
        )
        .where((w) => w.ignoring);
    expect(bloqueosAntes, isNotEmpty);

    await tester.enterText(campo('Cédula de identidad *'), '4487439');
    await tester.tap(find.byTooltip('Verificar cédula'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(campo('Nombres *')).controller!.text,
      'INOCENTES',
    );
    expect(
      tester.widget<TextFormField>(campo('Apellidos')).controller!.text,
      'YAURI PUCHO',
    );
    expect(find.text('Datos encontrados en el servicio SIE.'), findsOneWidget);
    expect(api.consultasSie, 1);
  });

  testWidgets('si la cédula ya está en el padrón no consulta SIE', (
    tester,
  ) async {
    ampliar(tester);
    final api = _ApiPersona(conProductorLocal: true);
    await tester.pumpWidget(formulario(api));
    await tester.pumpAndSettle();

    await tester.enterText(campo('Cédula de identidad *'), '4487439');
    await tester.tap(find.byTooltip('Verificar cédula'));
    await tester.pumpAndSettle();

    expect(find.text('Esa cédula ya está registrada.'), findsOneWidget);
    expect(api.consultasSie, 0);
  });

  testWidgets('si SIE no encuentra la cédula habilita el ingreso manual', (
    tester,
  ) async {
    ampliar(tester);
    final api = _ApiPersona(personaNoEncontrada: true);
    await tester.pumpWidget(formulario(api));
    await tester.pumpAndSettle();

    await tester.enterText(campo('Cédula de identidad *'), '12834877');
    await tester.tap(find.byTooltip('Verificar cédula'));
    await tester.pumpAndSettle();

    expect(
      find.text('La cédula no fue encontrada en el servicio SIE.'),
      findsOneWidget,
    );
    final bloqueos = tester.widgetList<IgnorePointer>(
      find.ancestor(
        of: find.text('Nombres *'),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(bloqueos.every((w) => !w.ignoring), isTrue);
    expect(find.text('Continuar manualmente'), findsNothing);
  });
}

class _ApiPersona extends ApiClient {
  _ApiPersona({
    this.conProductorLocal = false,
    this.personaNoEncontrada = false,
  });

  final bool conProductorLocal;
  final bool personaNoEncontrada;
  int consultasSie = 0;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta.startsWith('/productores/por-cedula/')) {
      if (!conProductorLocal) return <dynamic>[];
      return [
        {
          'id': 15,
          'nombres': 'INOCENTES',
          'apellidos': 'YAURI PUCHO',
          'nombreCompleto': 'INOCENTES YAURI PUCHO',
          'ci': '4487439',
          'sindicatoId': 7,
          'sindicatoNombre': 'LIBERTAD',
          'centralId': 3,
          'centralNombre': 'IVIRGARZAMA',
        },
      ];
    }
    if (ruta.startsWith('/lotes') || ruta.startsWith('/sistemas')) {
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
      consultasSie++;
      if (personaNoEncontrada) {
        return {
          'estado': 'NO_ENCONTRADA',
          'mensaje': 'La cédula no fue encontrada en el servicio SIE.',
        };
      }
      return {
        'estado': 'ENCONTRADA',
        'nombres': 'INOCENTES',
        'apellidos': 'YAURI PUCHO',
        'mensaje': 'Datos encontrados en el servicio SIE.',
      };
    }
    throw StateError('Ruta inesperada: $ruta');
  }
}
