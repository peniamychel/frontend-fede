import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/ui/widgets/dialogo_texto.dart';

/// Regresión de la pantalla roja al editar un sindicato.
///
/// La causa era crear un `TextEditingController`, abrir el diálogo con
/// `showDialog`, y desecharlo apenas la llamada devolvía. Devolver no significa
/// que el diálogo se haya ido: la ruta sigue animando su salida y el
/// `TextField` se reconstruye durante esa animación, intentando escuchar un
/// controlador ya desechado. De ahí salían el
/// "TextEditingController was used after being disposed", el
/// "_dependents.isEmpty is not true" y los "render box that has never been
/// laid out".
///
/// [DialogoTexto] existe para que eso no pueda volver a pasar: el controlador
/// vive dentro del State y se desecha en su `dispose`.
void main() {
  Widget banco({
    String inicial = 'LIBERTAD',
    int lineas = 1,
    ValueChanged<String?>? alCerrar,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final texto = await DialogoTexto.mostrar(
                  context,
                  titulo: 'Editar sindicato',
                  inicial: inicial,
                  lineas: lineas,
                );
                alCerrar?.call(texto);
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

  testWidgets('cerrar con Guardar no deja el árbol roto', (tester) async {
    String? resultado;
    await tester.pumpWidget(banco(alCerrar: (t) => resultado = t));
    await abrir(tester);

    await tester.tap(find.text('Guardar'));
    // Un solo pump primero: el diálogo se cerró pero la animación sigue, que
    // es exactamente el instante en que antes se rompía todo.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(resultado, equals('LIBERTAD'));
  });

  testWidgets('cerrar con Cancelar tampoco', (tester) async {
    String? resultado = 'algo';
    await tester.pumpWidget(banco(alCerrar: (t) => resultado = t));
    await abrir(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(resultado, isNull);
  });

  testWidgets('abrir y cerrar varias veces seguidas', (tester) async {
    await tester.pumpWidget(banco());

    // Cada apertura crea un controlador nuevo. Si el desecho estuviera mal,
    // la repetición lo saca a la luz enseguida.
    for (var i = 0; i < 3; i++) {
      await abrir(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'vuelta $i');
    }
  });

  testWidgets('llega con el valor precargado y lo devuelve editado',
      (tester) async {
    String? resultado;
    await tester.pumpWidget(banco(alCerrar: (t) => resultado = t));
    await abrir(tester);

    expect(find.text('LIBERTAD'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  LIBERTAD NUEVA  ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Recortado: un nombre con espacios al borde ensucia la base.
    expect(resultado, equals('LIBERTAD NUEVA'));
  });

  testWidgets('un texto vacío se trata como cancelar', (tester) async {
    String? resultado = 'algo';
    await tester.pumpWidget(banco(alCerrar: (t) => resultado = t));
    await abrir(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(resultado, isNull);
  });

  testWidgets('en multilínea Enter no cierra el diálogo', (tester) async {
    await tester.pumpWidget(banco(inicial: '', lineas: 3));
    await abrir(tester);

    await tester.enterText(find.byType(TextField), 'primera línea');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // En una observación de tres líneas, Enter tiene que servir para escribir.
    expect(find.byType(DialogoTexto), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
