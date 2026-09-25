import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/repositories/padron.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restaura la sesión y actualiza permisos desde el servidor', () async {
    final api = _ApiSesionFalsa();
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(
      'federa.sesion',
      jsonEncode({
        'token': 'token-anterior',
        'usuario': 'operador',
        'nombreCompleto': 'Operador',
        'rol': 'OPERADOR',
        'roles': ['REGISTRO'],
        'permisos': ['PRODUCTORES_EDITAR'],
        'expiraEn': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      }),
    );

    final sesion = await AutenticacionRepository(api).restaurar();

    expect(sesion, isNotNull);
    expect(sesion!.roles, {'CONSULTA'});
    expect(sesion.permisos, {'PRODUCTORES_VER'});
    expect(api.tieneToken, isTrue);
    expect(api.rutas, ['/auth/yo']);
  });

  test(
    'una sesión vencida se elimina sin consultar datos protegidos',
    () async {
      final api = _ApiSesionFalsa();
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString(
        'federa.sesion',
        jsonEncode({
          'token': 'token-vencido',
          'usuario': 'operador',
          'nombreCompleto': 'Operador',
          'rol': 'OPERADOR',
          'roles': <String>[],
          'permisos': <String>[],
          'expiraEn': DateTime.now()
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        }),
      );

      final sesion = await AutenticacionRepository(api).restaurar();

      expect(sesion, isNull);
      expect(api.rutas, isEmpty);
      expect(api.tieneToken, isFalse);
      expect(preferencias.getString('federa.sesion'), isNull);
    },
  );
}

class _ApiSesionFalsa extends ApiClient {
  final List<String> rutas = [];

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    rutas.add(ruta);
    return {
      'autenticado': true,
      'usuario': 'operador',
      'roles': ['CONSULTA'],
      'permisos': ['PRODUCTORES_VER'],
    };
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    // Una sesión ya vencida se limpia localmente; no necesita llamar logout.
    return <String, dynamic>{};
  }
}
