import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/ui/app.dart';

/// Pruebas de la interfaz sin backend.
///
/// `flutter_test` bloquea las peticiones HTTP reales, así que la app arranca
/// contra un servidor inalcanzable. Eso no es un estorbo: es justo el caso que
/// hay que verificar, porque es lo que va a ver el usuario cuando Spring Boot
/// no esté levantado.
void main() {
  testWidgets('la app arranca y muestra las cuatro secciones', (tester) async {
    await tester.pumpWidget(const PadronApp());
    await tester.pump();

    expect(find.text('Productores'), findsWidgets);
    expect(find.text('Jerarquía'), findsWidgets);
    expect(find.text('Observaciones'), findsWidgets);
    expect(find.text('Calidad'), findsWidgets);
  });

  testWidgets('sin backend muestra el fallo de conexión, no una pantalla rota',
      (tester) async {
    // Ancho suficiente para que salga el riel lateral y no la barra inferior.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PadronApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // La lista de productores no pudo cargar: debe ofrecer reintentar en vez
    // de quedarse colgada o lanzar una excepción sin capturar.
    expect(find.text('Reintentar'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en pantalla angosta usa la barra inferior', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PadronApp());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('a 360 px nada se desborda y los cuatro destinos caben',
      (tester) async {
    // El teléfono más angosto que se usa en la práctica. Si algo se sale,
    // Flutter lanza «A RenderFlex overflowed by N pixels» y takeException lo
    // devuelve: es una comprobación más fiable que mirar una captura.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PadronApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);

    final barra = find.byType(NavigationBar);
    expect(barra, findsOneWidget);
    for (final etiqueta in [
      'Productores',
      'Jerarquía',
      'Observaciones',
      'Calidad',
    ]) {
      expect(
        find.descendant(of: barra, matching: find.text(etiqueta)),
        findsOneWidget,
        reason: 'el destino «$etiqueta» debe estar en la barra inferior',
      );
    }
  });

  testWidgets('la barra de filtros no se desborda en pantalla angosta',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PadronApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 320 px es el ancho de un iPhone SE de primera generación: el suelo real.
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('en pantalla ancha usa el riel lateral', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PadronApp());
    await tester.pump();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
