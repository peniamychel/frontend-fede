import 'package:fede/core/api_client.dart';
import 'package:fede/core/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const tieneConfiguracion =
      bool.hasEnvironment('API_HOST') ||
      bool.hasEnvironment('API_ESQUEMA') ||
      bool.hasEnvironment('API_PUERTO');
  // El runner proporciona una URL esperada independiente de la implementación.
  const urlEsperada = String.fromEnvironment('API_PRUEBA_URL_ESPERADA');

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('desarrollo conserva los destinos HTTP de Android y Windows', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      ApiConfig.uri('/auth/acceso').toString(),
      'http://10.0.2.2:8080/api/v1/auth/acceso',
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(
      ApiConfig.uri('/auth/acceso').toString(),
      'http://localhost:8080/api/v1/auth/acceso',
    );
  }, skip: tieneConfiguracion);

  for (final plataforma in [TargetPlatform.android, TargetPlatform.windows]) {
    test(
      'destino compilado de API, imágenes y descargas en $plataforma',
      () async {
        debugDefaultTargetPlatformOverride = plataforma;
        final destino = Uri.parse(urlEsperada);
        expect(
          ApiConfig.uri('/auth/acceso'),
          destino.resolve('/api/v1/auth/acceso'),
        );
        expect(
          Uri.parse(ApiConfig.urlAbsoluta('/api/v1/archivos/foto.png')),
          destino.resolve('/api/v1/archivos/foto.png'),
        );

        final api = ApiClient(
          cliente: MockClient((peticion) async {
            expect(peticion.url, destino.resolve('/api/v1/documento.pdf'));
            expect(
              peticion.headers['Authorization'],
              'Bearer sesion-sintetica',
            );
            return http.Response.bytes(
              [37, 80, 68, 70],
              200,
              headers: {'content-type': 'application/pdf'},
            );
          }),
        )..usarToken('sesion-sintetica');
        addTearDown(api.cerrar);
        await api.descargarUrl(destino.resolve('/api/v1/documento.pdf'));
        final otroEsquema = destino.replace(
          scheme: destino.scheme == 'https' ? 'http' : 'https',
        );
        expect(
          () => api.descargarUrl(otroEsquema.resolve('/api/v1/documento.pdf')),
          throwsArgumentError,
        );
      },
      skip: urlEsperada.isEmpty,
    );
  }
}
