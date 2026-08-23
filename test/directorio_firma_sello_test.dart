import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/firmas_cargo.dart';
import 'package:fede/ui/jerarquia/preparar_imagen_directorio.dart';
import 'package:fede/ui/jerarquia/sello_directorio.dart';
import 'package:fede/ui/padron_scope.dart';

void main() {
  final cargo = Cargo(
    id: 12,
    cargo: TipoCargo.secretarioGeneral,
    productorId: 8,
    productorNombre: 'ANA QUISPE',
    ambito: Ambito.sindicato,
    ambitoId: 4,
    ambitoNombre: 'LIBERTAD',
    desde: DateTime(2026, 8, 18),
    hasta: null,
    vigente: true,
    pieFirma: 'ANA QUISPE\nSECRETARIO GENERAL\nLIBERTAD',
  );
  const directorio = Directorio(
    ambito: Ambito.sindicato,
    ambitoId: 4,
    ambitoNombre: 'LIBERTAD',
    puestos: [],
  );

  testWidgets('ofrece firma, pie automático y sello institucional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: ApiClient()),
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                FirmasCargo(cargo: cargo, alCambiar: _nada),
                SelloDirectorio(directorio: directorio, alCambiar: _nada),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Subir firma'), findsOneWidget);
    expect(find.text('Pie de firma automático'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Subir pie de firma'), findsNothing);
    expect(find.text('Subir sello'), findsOneWidget);
    expect(
      find.text('ANA QUISPE\nSECRETARIO GENERAL\nLIBERTAD'),
      findsOneWidget,
    );
  });

  test('lee el sello y el pie de firma desde la API', () {
    final datos = Directorio.desdeJson({
      'ambito': 'CENTRAL',
      'ambitoId': 3,
      'ambitoNombre': 'IVIRGARZAMA',
      'selloUrl': '/api/v1/archivos/sellos/central-3.jpg',
      'puestos': [
        {
          'cargo': 'SECRETARIO_GENERAL',
          'etiqueta': 'Secretario General',
          'puedeFirmar': true,
          'actual': {
            'id': 7,
            'cargo': 'SECRETARIO_GENERAL',
            'productorId': 9,
            'productorNombre': 'JUAN PEREZ',
            'ambito': 'CENTRAL',
            'ambitoId': 3,
            'ambitoNombre': 'IVIRGARZAMA',
            'desde': '2026-08-18',
            'vigente': true,
            'pieFirma': 'JUAN PEREZ\nSECRETARIO GENERAL\nIVIRGARZAMA',
          },
        },
      ],
    });

    expect(datos.selloUrl, contains('/sellos/'));
    expect(
      datos.cargoDe(TipoCargo.secretarioGeneral)!.pieFirma,
      'JUAN PEREZ\nSECRETARIO GENERAL\nIVIRGARZAMA',
    );
  });

  testWidgets(
    'la preparación ofrece recorte, fondo transparente y vista previa',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final bytes = File('test/fixtures/foto-prueba.png').readAsBytesSync();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrepararImagenDirectorioDialogo(
              archivo: PlatformFile(
                name: 'firma.jpg',
                size: bytes.length,
                bytes: bytes,
              ),
              clase: ClaseImagenDirectorio.firma,
            ),
          ),
        ),
      );
      // El recortador muestra un progreso animado mientras el codec decodifica;
      // pumpAndSettle esperaría esa animación aunque el diálogo ya esté listo.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Preparar firma'), findsOneWidget);
      expect(find.text('Quitar fondo claro'), findsOneWidget);
      expect(find.text('Cantidad de fondo a eliminar'), findsOneWidget);
      expect(find.text('Preparar vista previa'), findsOneWidget);
      expect(find.text('Subir PNG'), findsOneWidget);
    },
  );
}

void _nada() {}
