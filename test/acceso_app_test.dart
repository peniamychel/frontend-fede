import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el código abre la aplicación y conserva sus permisos', (
    tester,
  ) async {
    final api = _ApiAccesoFalsa();
    await tester.pumpWidget(
      PadronApp(
        padron: Padron(api: api),
        preferenciaTema: PreferenciaTema(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Código de acceso'), findsOneWidget);
    await tester.enterText(find.byType(TextField), ' abc123-secreto ');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(api.ultimoCodigo, 'abc123-secreto');
    expect(find.text('Productores'), findsWidgets);
    expect(find.text('Reuniones'), findsNothing);
    expect(find.text('Respaldos'), findsNothing);
    expect(find.text('Accesos'), findsNothing);
    expect(find.text('Cuenta'), findsWidgets);

    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('federa.sesion'), isNotNull);
  });
}

class _ApiAccesoFalsa extends ApiClient {
  String? ultimoCodigo;

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta == '/auth/acceso') {
      ultimoCodigo = (cuerpo as Map<String, dynamic>)['codigo'] as String?;
      return {
        'token': 'token-prueba',
        'duracionSegundos': 3600,
        'usuario': 'consulta',
        'nombreCompleto': 'Usuario de consulta',
        'rol': 'OPERADOR',
        'roles': ['CONSULTA'],
        'permisos': ['PRODUCTORES_VER', 'INFORMES_DESCARGAR'],
      };
    }
    return <String, dynamic>{};
  }

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores') {
      return {
        'content': <dynamic>[],
        'number': 0,
        'size': 25,
        'totalElements': 0,
        'totalPages': 0,
        'first': true,
        'last': true,
      };
    }
    if (ruta == '/centrales' || ruta == '/sindicatos') return <dynamic>[];
    return <dynamic>[];
  }
}
