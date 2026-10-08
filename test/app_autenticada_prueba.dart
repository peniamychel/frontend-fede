import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/app.dart';

/// Prueba la navegación después del acceso, sin depender de un servidor real.
Future<void> arrancarAppAutenticada(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final padron = Padron(api: _ApiNavegacion());
  addTearDown(padron.cerrar);
  await tester.pumpWidget(PadronApp(padron: padron));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'AbCdE');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

class _ApiNavegacion extends ApiClient {
  @override
  Future<Object?> crear(String ruta, Object cuerpo) async => {
    'token': 'token-exclusivo-de-prueba',
    'duracionSegundos': 3600,
    'usuario': 'prueba',
    'nombreCompleto': 'Usuario de prueba',
    'rol': 'OPERADOR',
    'roles': ['CONSULTA'],
    'permisos': [
      'PRODUCTORES_VER',
      'REUNIONES_GESTIONAR',
      'RESPALDOS_ADMINISTRAR',
    ],
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    throw const SinConexionException('servidor-de-prueba');
  }
}
