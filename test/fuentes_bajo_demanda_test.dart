import 'package:flutter_test/flutter_test.dart';
import 'package:fede/models/diseno_credencial.dart';
import 'package:fede/ui/credenciales/fuentes_bajo_demanda.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('todas las familias existen y reutilizan la misma carga', () async {
    for (final fuente in FuenteCredencial.values) {
      final primera = cargarFuenteCredencial(fuente);
      expect(identical(primera, cargarFuenteCredencial(fuente)), isTrue);
      await primera;
      expect(identical(primera, cargarFuenteCredencial(fuente)), isTrue);
    }
  });
}
