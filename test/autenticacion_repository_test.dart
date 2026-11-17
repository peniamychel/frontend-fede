import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/repositories/padron.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'elimina tokens heredados del almacenamiento sin reutilizarlos',
    () async {
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

      expect(sesion, isNull);
      expect(api.tieneToken, isFalse);
      expect(api.rutas, isEmpty);
      expect(preferencias.getString('federa.sesion'), isNull);
    },
  );

  test('la sesión solo vive en memoria y cerrar la revoca', () async {
    final api = _ApiSesionFalsa();
    final repo = AutenticacionRepository(api);
    final sesion = await repo.acceder('codigo-de-prueba');
    expect(sesion.usuario, 'operador');
    expect(api.tieneToken, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getString('federa.sesion'),
      isNull,
    );
    expect((await repo.restaurar())!.permisos, {'PRODUCTORES_VER'});
    await repo.cerrarSesion();
    expect(api.rutas, contains('/auth/logout'));
    expect(api.tieneToken, isFalse);
    expect(await repo.restaurar(), isNull);
    expect(
      await AutenticacionRepository(_ApiSesionFalsa()).restaurar(),
      isNull,
    );
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
    rutas.add(ruta);
    if (ruta == '/auth/acceso') {
      return {
        'token': 'token-de-prueba',
        'usuario': 'operador',
        'nombreCompleto': 'Operador',
        'rol': 'OPERADOR',
        'duracionSegundos': 3600,
        'roles': ['CONSULTA'],
        'permisos': ['PRODUCTORES_VER'],
      };
    }
    return <String, dynamic>{};
  }
}
