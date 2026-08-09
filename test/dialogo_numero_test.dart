import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/ui/widgets/dialogo_nombre_numero.dart';

/// Diálogo de alta y edición de centrales y sindicatos.
///
/// Hereda la disciplina de `DialogoTexto`: los controladores viven en el
/// `State`. Las dos primeras pruebas son la regresión de la pantalla roja, que
/// aparecía al desecharlos apenas volvía `showDialog`, mientras la ruta todavía
/// animaba su salida.
void main() {
  Widget banco({
    String nombreInicial = '',
    String? numeroInicial,
    ValueChanged<NombreYNumero?>? alCerrar,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final datos = await DialogoNombreNumero.mostrar(
                  context,
                  titulo: 'Nuevo sindicato',
                  nombreInicial: nombreInicial,
                  numeroInicial: numeroInicial,
                );
                alCerrar?.call(datos);
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> abrir(WidgetTester tester) async {
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Finder campo(String etiqueta) => find.ancestor(
        of: find.text(etiqueta),
        matching: find.byType(TextFormField),
      );

  testWidgets('guardar con los dos campos no deja el árbol roto',
      (tester) async {
    NombreYNumero? resultado;
    await tester.pumpWidget(banco(alCerrar: (d) => resultado = d));
    await abrir(tester);

    await tester.enterText(campo('Nombre *'), 'ALTO SAN SALVADOR');
    await tester.enterText(campo('Número'), '47');
    await tester.tap(find.text('Guardar'));
    // Un pump primero: el diálogo cerró pero la animación sigue, que es el
    // instante en que se rompía todo.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(resultado?.nombre, 'ALTO SAN SALVADOR');
    expect(resultado?.numero, '47');
  });

  testWidgets('abrir y cerrar varias veces seguidas', (tester) async {
    await tester.pumpWidget(banco(nombreInicial: 'LIBERTAD'));

    for (var i = 0; i < 3; i++) {
      await abrir(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'vuelta $i');
    }
  });

  testWidgets('sin nombre no deja guardar, y lo dice', (tester) async {
    NombreYNumero? resultado;
    await tester.pumpWidget(banco(alCerrar: (d) => resultado = d));
    await abrir(tester);

    await tester.enterText(campo('Número'), '47');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // El diálogo sigue abierto con el aviso, en vez de cerrarse en silencio.
    expect(find.text('Poné un nombre'), findsOneWidget);
    expect(find.byType(DialogoNombreNumero), findsOneWidget);
    expect(resultado, isNull);
  });

  testWidgets('el número es opcional y vacío significa sin número',
      (tester) async {
    NombreYNumero? resultado;
    await tester.pumpWidget(banco(alCerrar: (d) => resultado = d));
    await abrir(tester);

    await tester.enterText(campo('Nombre *'), 'BERMEJO');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Null y no cadena vacía: el backend guarda null, y la clave única deja
    // convivir a todos los que no tienen número.
    expect(resultado?.nombre, 'BERMEJO');
    expect(resultado?.numero, isNull);
  });

  testWidgets('al editar llegan cargados los dos valores', (tester) async {
    NombreYNumero? resultado;
    await tester.pumpWidget(banco(
      nombreInicial: 'TUNARI',
      numeroInicial: '12',
      alCerrar: (d) => resultado = d,
    ));
    await abrir(tester);

    expect(find.text('TUNARI'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    // Cambiar solo el número deja el nombre como estaba.
    await tester.enterText(campo('Número'), '13');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(resultado?.nombre, 'TUNARI');
    expect(resultado?.numero, '13');
  });

  testWidgets('se le puede quitar el número a algo que lo tenía',
      (tester) async {
    NombreYNumero? resultado;
    await tester.pumpWidget(banco(
      nombreInicial: 'TUNARI',
      numeroInicial: '12',
      alCerrar: (d) => resultado = d,
    ));
    await abrir(tester);

    await tester.enterText(campo('Número'), '');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(resultado?.numero, isNull);
  });

  testWidgets('cancelar no devuelve nada', (tester) async {
    NombreYNumero? resultado = (nombre: 'algo', numero: 'algo');
    await tester.pumpWidget(banco(alCerrar: (d) => resultado = d));
    await abrir(tester);

    await tester.enterText(campo('Nombre *'), 'NO SE GUARDA');
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(resultado, isNull);
  });
}
