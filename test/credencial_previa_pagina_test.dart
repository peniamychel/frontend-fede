import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/credenciales/credencial_previa_pagina.dart';
import 'package:fede/ui/credenciales/impresion_credencial.dart';
import 'package:fede/ui/padron_scope.dart';

/// La pantalla de vista previa de la credencial, con un servidor fingido.
///
/// La primera prueba es la regresión de un error real: `_recargar` asignaba el
/// futuro con una función flecha dentro de `setState`, la flecha devuelve lo
/// que asigna, y setState rechaza un callback que devuelva un Future. Reventaba
/// recién al abrir la pantalla, así que sin esta prueba nadie lo veía hasta
/// apretar el botón.
void main() {
  setUp(() {
    debugImpresionDeCredencialesDisponible = true;
  });

  tearDown(() {
    debugImpresionDeCredencialesDisponible = null;
  });

  Map<String, dynamic> previa({
    required bool completa,
    List<Map<String, String>> faltantes = const [],
  }) => {
    'productorId': 1,
    'nombreCompleto': 'JUAN MORALES',
    'federacion': 'FEDERACIÓN CARRASCO',
    'central': 'IVIRGARZAMA',
    'sindicato': 'LIBERTAD',
    'nombres': 'JUAN',
    'apellidos': 'MORALES',
    'ci': '3434',
    'lotes': '',
    'codigoPadron': '2-IVI-1',
    'codigoQr': 'CDB01AF229',
    // Sin foto a propósito: cargar una URL de red en una prueba de widget
    // fallaría, y el recuadro rojo de «SIN FOTO» también merece verse.
    'fotoUrl': null,
    'ejecutivoFederacion': {
      'nombre': 'EJECUTIVO X',
      'cargo': 'EJECUTIVO',
      'organizacion': 'FEDERACIÓN CARRASCO',
      'tieneFirma': true,
    },
    'secretarioGeneralCentral': {
      'nombre': 'SECRETARIO CENTRAL X',
      'cargo': 'SECRETARIO GENERAL',
      'organizacion': 'IVIRGARZAMA',
      'tieneFirma': true,
    },
    'secretarioGeneralSindicato': null,
    'faltantes': faltantes,
    'completa': completa,
  };

  Widget pantalla(Map<String, dynamic> respuesta) => TemaScope(
    preferencia: PreferenciaTema(),
    child: PadronScope(
      padron: Padron(api: _ApiFija(respuesta)),
      child: const MaterialApp(
        home: CredencialPreviaPagina(productorId: 1, nombre: 'JUAN'),
      ),
    ),
  );

  final faltaSecretario = {
    'campo': 'Secretario General del sindicato',
    'detalle': 'El sindicato LIBERTAD no tiene secretario general en funciones',
    'donde': 'Jerarquía → Sindicatos → Directorio',
  };

  testWidgets('abrir la pantalla no revienta', (tester) async {
    await tester.pumpWidget(
      pantalla(previa(completa: false, faltantes: [faltaSecretario])),
    );
    await tester.pump();

    // Acá es donde aparecía el error del setState con Future.
    expect(tester.takeException(), isNull);
  });

  testWidgets('incompleta: muestra qué falta, dónde, y no deja generar', (
    tester,
  ) async {
    await tester.pumpWidget(
      pantalla(previa(completa: false, faltantes: [faltaSecretario])),
    );
    await tester.pump();

    expect(find.text('Falta un dato para poder imprimirla.'), findsOneWidget);
    expect(find.text('Secretario General del sindicato'), findsOneWidget);
    expect(find.text('Jerarquía → Sindicatos → Directorio'), findsOneWidget);
    // El hueco del reverso se marca en rojo, no se deja en blanco.
    expect(find.text('SIN FIRMANTE'), findsOneWidget);

    final anverso = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('1. Imprimir anverso'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      anverso.onPressed,
      isNull,
      reason: 'con faltantes el botón tiene que estar deshabilitado',
    );
    final reverso = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('2. Imprimir reverso'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(reverso.onPressed, isNull);
  });

  testWidgets('completa: dibuja la tarjeta y habilita el botón', (
    tester,
  ) async {
    await tester.pumpWidget(pantalla(previa(completa: true)));
    await tester.pump();

    expect(find.text('Lista para imprimir.'), findsOneWidget);
    // La tarjeta trae los datos como van a salir.
    expect(find.text('JUAN MORALES'), findsOneWidget);
    expect(find.text('2-IVI-1'), findsOneWidget);
    expect(find.text('CARRASCO'), findsOneWidget);

    final boton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('1. Imprimir anverso'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(boton.onPressed, isNotNull);
    expect(find.text('2. Imprimir reverso'), findsOneWidget);
  });

  testWidgets('Android conserva la vista previa sin botones de impresión', (
    tester,
  ) async {
    debugImpresionDeCredencialesDisponible = false;
    await tester.pumpWidget(pantalla(previa(completa: true)));
    await tester.pump();

    expect(find.text('JUAN MORALES'), findsOneWidget);
    expect(
      find.textContaining('La impresión física está disponible'),
      findsOneWidget,
    );
    expect(find.text('1. Imprimir anverso'), findsNothing);
  });
}

/// Un ApiClient que responde siempre lo mismo y no llama a ningún servidor.
class _ApiFija extends ApiClient {
  _ApiFija(this.respuesta);

  final Map<String, dynamic> respuesta;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async =>
      respuesta;
}
