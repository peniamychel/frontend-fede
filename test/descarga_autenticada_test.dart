import 'package:fede/core/api_client.dart';
import 'package:fede/core/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('la descarga conserva sesión, parámetros y nombre de PDF', () async {
    final api = ApiClient(cliente: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer sesion-prueba');
      expect(request.url.path, '/api/v1/sindicatos/3/informe.pdf');
      expect(request.url.queryParametersAll['id'], ['1', '2']);
      return http.Response.bytes([37, 80, 68, 70], 200, headers: {
        'content-type': 'application/pdf',
        'content-disposition': 'attachment; filename="nomina.pdf"',
      });
    }));
    addTearDown(api.cerrar);
    api.usarToken('sesion-prueba');
    final archivo = await api.descargarUrl(
      ApiConfig.uri('/sindicatos/3/informe.pdf', {'id': ['1', '2']}),
    );
    expect(archivo.nombreArchivo, 'nomina.pdf');
    expect(archivo.tipoMime, 'application/pdf');
    expect(archivo.bytes, [37, 80, 68, 70]);
  });

  test('no envía la sesión a otro servidor', () {
    final api = ApiClient(cliente: MockClient((_) async {
      fail('No debe realizar una petición externa');
    }));
    addTearDown(api.cerrar);
    api.usarToken('sesion-prueba');
    expect(() => api.descargarUrl(Uri.parse('https://externo.invalid/api/v1/a.pdf')),
        throwsArgumentError);
  });
}
