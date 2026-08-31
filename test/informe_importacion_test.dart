import 'package:fede/models/importacion.dart';
import 'package:fede/ui/importacion/informe_importacion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('separa centrales faltantes de sindicatos por aprobar', (
    tester,
  ) async {
    const informe = ImportacionResultado(
      simulacion: true,
      federacionId: 1,
      federacionNombre: 'CARRASCO TROPICAL',
      filasLeidas: 3,
      filasValidas: 2,
      filasRechazadas: 1,
      productores: 2,
      lotes: 2,
      observaciones: 0,
      centralesNuevas: ['CENTRAL NO REGISTRADA'],
      sindicatosNuevos: [
        SindicatoNuevo(central: '13 DE JUNIO', sindicato: 'NUEVO SINDICATO'),
      ],
      posiblesDuplicados: 0,
      errores: [],
      erroresOmitidos: 0,
      duracionMs: 20,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InformeImportacion(informe: informe),
          ),
        ),
      ),
    );

    expect(find.text('Centrales no registradas'), findsOneWidget);
    expect(find.text('CENTRAL NO REGISTRADA'), findsOneWidget);
    expect(find.text('Sindicatos nuevos para aprobar'), findsOneWidget);
    expect(find.text('13 DE JUNIO › NUEVO SINDICATO'), findsOneWidget);
  });
}
