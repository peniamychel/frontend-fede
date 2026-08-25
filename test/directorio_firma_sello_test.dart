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

  testWidgets(
    'sindicato deja la firma opcional y el pie visible pero bloqueado',
    (tester) async {
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
                  FirmasCargo(
                    cargo: cargo,
                    alCambiar: _nada,
                    permitePieFirmaImagen: false,
                    firmaObligatoria: false,
                  ),
                  SelloDirectorio(directorio: directorio, alCambiar: _nada),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Subir firma'), findsOneWidget);
      expect(find.text('Subir pie de firma'), findsOneWidget);
      expect(find.text('No disponible para sindicatos'), findsOneWidget);
      expect(find.text('Pie de firma automático de respaldo'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Subir sello'), findsOneWidget);
      expect(find.text('Obligatorio'), findsOneWidget);
      expect(
        find.text('ANA QUISPE\nSECRETARIO GENERAL\nLIBERTAD'),
        findsOneWidget,
      );
    },
  );

  testWidgets('central permite subir firma y pie de firma', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final central = Cargo(
      id: 13,
      cargo: TipoCargo.secretarioGeneral,
      productorId: 8,
      productorNombre: 'ANA QUISPE',
      ambito: Ambito.central,
      ambitoId: 3,
      ambitoNombre: 'IVIRGARZAMA',
      desde: DateTime(2026, 8, 18),
      hasta: null,
      vigente: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirmasCargo(
            cargo: central,
            alCambiar: _nada,
            permitePieFirmaImagen: true,
            firmaObligatoria: true,
          ),
        ),
      ),
    );

    expect(find.text('Subir firma'), findsOneWidget);
    final botonPie = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Subir pie de firma'),
        matching: find.byType(TextButton),
      ),
    );
    expect(botonPie.onPressed, isNotNull);
  });

  test('lee el sello y el pie de firma desde la API', () {
    final datos = Directorio.desdeJson({
      'ambito': 'CENTRAL',
      'ambitoId': 3,
      'ambitoNombre': 'IVIRGARZAMA',
      'selloUrl': '/api/v1/archivos/sellos/central-3.jpg',
      'permitePieFirmaImagen': true,
      'firmaObligatoria': true,
      'selloObligatorio': true,
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
            'pieFirmaUrl': '/api/v1/archivos/pies-firma/pie-juan.png',
          },
        },
      ],
    });

    expect(datos.selloUrl, contains('/sellos/'));
    expect(datos.permitePieFirmaImagen, isTrue);
    expect(datos.firmaObligatoria, isTrue);
    expect(datos.selloObligatorio, isTrue);
    expect(
      datos.cargoDe(TipoCargo.secretarioGeneral)!.pieFirma,
      'JUAN PEREZ\nSECRETARIO GENERAL\nIVIRGARZAMA',
    );
    expect(
      datos.cargoDe(TipoCargo.secretarioGeneral)!.pieFirmaUrl,
      contains('/pies-firma/'),
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

  testWidgets('el pie de firma usa el mismo recorte y fondo transparente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bytes = File('test/fixtures/foto-prueba.png').readAsBytesSync();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrepararImagenDirectorioDialogo(
            archivo: PlatformFile(
              name: 'pie-firma.jpg',
              size: bytes.length,
              bytes: bytes,
            ),
            clase: ClaseImagenDirectorio.pieFirma,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Preparar pie de firma'), findsOneWidget);
    expect(find.text('Quitar fondo claro'), findsOneWidget);
    expect(find.text('Subir PNG'), findsOneWidget);
  });
}

void _nada() {}
