import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/ui/widgets/boton_tema.dart';

/// Cambio de tema claro/oscuro y su persistencia.
void main() {
  setUp(() {
    // Sustituye el almacenamiento real por uno en memoria: las pruebas no
    // deben depender de lo que haya guardado la máquina, ni dejar rastro.
    SharedPreferences.setMockInitialValues({});
  });

  group('PreferenciaTema', () {
    test('arranca en automático', () {
      expect(PreferenciaTema().value, equals(ThemeMode.system));
    });

    test('recuerda lo elegido entre sesiones', () async {
      final primera = PreferenciaTema();
      await primera.cambiar(ThemeMode.dark);

      // Una instancia nueva simula volver a abrir la app.
      final segunda = PreferenciaTema();
      await segunda.cargar();

      expect(segunda.value, equals(ThemeMode.dark));
    });

    test('en automático, alternar salta a lo contrario de lo que se ve',
        () async {
      final preferencia = PreferenciaTema();

      // Viendo claro por configuración del sistema, el botón tiene que llevar
      // a oscuro: quien lo toca quiere lo otro, no otra vez lo mismo.
      await preferencia.alternar(Brightness.light);
      expect(preferencia.value, equals(ThemeMode.dark));

      await preferencia.alternar(Brightness.dark);
      expect(preferencia.value, equals(ThemeMode.light));
    });

    test('avisa a quien escucha cuando cambia', () async {
      final preferencia = PreferenciaTema();
      var avisos = 0;
      preferencia.addListener(() => avisos++);

      await preferencia.cambiar(ThemeMode.dark);
      expect(avisos, equals(1));

      // Elegir lo mismo no debería repintar la app entera.
      await preferencia.cambiar(ThemeMode.dark);
      expect(avisos, equals(1));
    });
  });

  group('BotonTema', () {
    Widget banco(PreferenciaTema preferencia, ThemeMode modo) {
      return TemaScope(
        preferencia: preferencia,
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: modo,
          home: const Scaffold(
            appBar: null,
            body: Center(child: BotonTema()),
          ),
        ),
      );
    }

    testWidgets('ofrece las tres opciones y marca la activa', (tester) async {
      final preferencia = PreferenciaTema();
      await preferencia.cambiar(ThemeMode.dark);

      await tester.pumpWidget(banco(preferencia, ThemeMode.dark));
      await tester.tap(find.byType(BotonTema));
      await tester.pumpAndSettle();

      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);
      expect(find.text('Igual que el sistema'), findsOneWidget);

      final marcado = tester.widget<CheckedPopupMenuItem<ThemeMode>>(
        find.widgetWithText(CheckedPopupMenuItem<ThemeMode>, 'Oscuro'),
      );
      expect(marcado.checked, isTrue);
    });

    testWidgets('elegir una opción cambia la preferencia', (tester) async {
      final preferencia = PreferenciaTema();

      await tester.pumpWidget(banco(preferencia, ThemeMode.system));
      await tester.tap(find.byType(BotonTema));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();

      expect(preferencia.value, equals(ThemeMode.light));
    });
  });
}
