import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/widgets/estados.dart';

/// Los avisos flotantes: que digan lo que tienen que decir y se distingan
/// entre sí de un vistazo.
void main() {
  /// Pantalla mínima con un botón que dispara el aviso.
  Widget banco(void Function(BuildContext) accion, {Size? tamano}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => accion(context),
              child: const Text('disparar'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> disparar(WidgetTester tester) async {
    await tester.tap(find.text('disparar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('el éxito muestra tilde, título y detalle', (tester) async {
    await tester.pumpWidget(banco((c) => mostrarExito(
          c,
          'Foto guardada',
          detalle: 'De 6.06 MB a 398 KB, 94 % menos.',
        )));
    await disparar(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('Foto guardada'), findsOneWidget);
    expect(find.text('De 6.06 MB a 398 KB, 94 % menos.'), findsOneWidget);
  });

  testWidgets('flota y no ocupa todo el ancho', (tester) async {
    await tester.pumpWidget(banco((c) => mostrarExito(c, 'Listo')));
    await disparar(tester);

    final barra = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(barra.behavior, equals(SnackBarBehavior.floating));
    // A todo el ancho el texto queda perdido en una esquina de la pantalla.
    expect(barra.width, isNotNull);
  });

  testWidgets('el error separa el motivo del detalle', (tester) async {
    const fallo = ApiException(
      estado: 409,
      mensaje: 'La central ya tiene un sindicato llamado LIBERTAD',
    );

    await tester.pumpWidget(banco((c) => mostrarError(c, fallo)));
    await disparar(tester);

    // El título dice qué pasó de un vistazo; el cuerpo, por qué.
    expect(find.text('No se pudo guardar'), findsOneWidget);
    expect(find.text('La central ya tiene un sindicato llamado LIBERTAD'),
        findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('el error de validación lista los campos', (tester) async {
    const fallo = ApiException(
      estado: 400,
      mensaje: 'Datos inválidos',
      errores: {'nombres': 'los nombres son obligatorios'},
    );

    await tester.pumpWidget(banco((c) => mostrarError(c, fallo)));
    await disparar(tester);

    expect(find.text('Revisá los datos'), findsOneWidget);
    expect(
      find.textContaining('los nombres son obligatorios'),
      findsOneWidget,
      reason: 'el detalle por campo es lo único accionable del mensaje',
    );
  });

  testWidgets('la falta de conexión se distingue de un error de la API',
      (tester) async {
    const fallo = SinConexionException('http://localhost:8080/api/v1');

    await tester.pumpWidget(banco((c) => mostrarError(c, fallo)));
    await disparar(tester);

    // Son problemas distintos y se arreglan distinto: uno levantando el
    // backend, el otro corrigiendo los datos.
    expect(find.text('Sin conexión con el servidor'), findsOneWidget);
  });

  testWidgets('solo el error se puede cerrar a mano', (tester) async {
    await tester.pumpWidget(banco((c) => mostrarExito(c, 'Listo')));
    await disparar(tester);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).showCloseIcon,
        isFalse);

    await tester.pumpWidget(banco((c) => mostrarError(c, 'roto')));
    await disparar(tester);
    // Un error hay que poder leerlo con calma, o sacarlo del medio si estorba.
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).showCloseIcon,
        isTrue);
  });

  testWidgets('el error dura más que la confirmación', (tester) async {
    await tester.pumpWidget(banco((c) => mostrarExito(c, 'Listo')));
    await disparar(tester);
    final exito = tester.widget<SnackBar>(find.byType(SnackBar)).duration;

    await tester.pumpWidget(banco((c) => mostrarError(c, 'roto')));
    await disparar(tester);
    final error = tester.widget<SnackBar>(find.byType(SnackBar)).duration;

    expect(error, greaterThan(exito));
  });

  testWidgets('un aviso nuevo reemplaza al anterior, no se apilan',
      (tester) async {
    await tester.pumpWidget(banco((c) {
      mostrarAviso(c, 'primero');
      mostrarExito(c, 'segundo');
    }));
    await disparar(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('segundo'), findsOneWidget);
    expect(find.text('primero'), findsNothing);
  });
}
