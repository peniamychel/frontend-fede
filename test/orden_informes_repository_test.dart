import 'dart:convert';

import 'package:fede/core/api_client.dart';
import 'package:fede/models/orden_informes.dart';
import 'package:fede/repositories/central_repository.dart';
import 'package:fede/repositories/sindicato_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final orden in OrdenInformes.values) {
    test(
      'los diez informes envían ${orden.valor} sin cambiar alcance ni selección',
      () async {
        final peticiones = <http.Request>[];
        final api = ApiClient(
          cliente: MockClient((peticion) async {
            peticiones.add(peticion);
            expect(peticion.url.queryParameters, {'orden': orden.valor});
            expect(peticion.headers['Authorization'], 'Bearer prueba');
            return http.Response.bytes(
              [1, 2, 3],
              200,
              headers: {
                'content-type': 'application/octet-stream',
                'content-disposition': 'attachment; filename="informe.bin"',
              },
            );
          }),
        );
        api.usarToken('prueba');
        addTearDown(api.cerrar);
        final central = CentralRepository(api);
        final sindicato = SindicatoRepository(api);
        await central.descargarInformePreImpresion(3, orden: orden);
        await central.descargarRevisionPadron(3, orden: orden);
        await central.descargarProductoresExcel(3, orden: orden);
        await central.descargarInformeNominalImpresion(3, [7, 9], orden: orden);
        await central.descargarInformeFase(3, 11, orden: orden);
        await sindicato.descargarInformePreImpresion(7, orden: orden);
        await sindicato.descargarRevisionPadron(7, orden: orden);
        await sindicato.descargarProductoresExcel(7, orden: orden);
        await sindicato.descargarNomina(7, orden: orden);
        await sindicato.descargarInformeFase(7, 11, orden: orden);
        expect(peticiones.map((p) => p.url.path), [
          '/api/v1/centrales/3/credenciales/impresion/informe-pre-impresion.pdf',
          '/api/v1/centrales/3/credenciales/impresion/revision-padron.pdf',
          '/api/v1/centrales/3/credenciales/impresion/productores.xlsx',
          '/api/v1/centrales/3/credenciales/impresion/informe-nominal.pdf',
          '/api/v1/centrales/3/fases-impresion/11/informe.pdf',
          '/api/v1/sindicatos/7/informes/pre-impresion.pdf',
          '/api/v1/sindicatos/7/informes/revision-padron.pdf',
          '/api/v1/sindicatos/7/informes/productores.xlsx',
          '/api/v1/sindicatos/7/informes/nomina.pdf',
          '/api/v1/sindicatos/7/informes/fases/11/informe.pdf',
        ]);
        expect(peticiones.map((p) => p.method), [
          'GET',
          'GET',
          'GET',
          'POST',
          'GET',
          'GET',
          'GET',
          'GET',
          'GET',
          'GET',
        ]);
        expect(jsonDecode(peticiones[3].body), {
          'sindicatoIds': [7, 9],
        });
      },
    );
  }

  test('las llamadas anteriores conservan apellidos por defecto', () async {
    var peticiones = 0;
    final api = ApiClient(
      cliente: MockClient((peticion) async {
        peticiones++;
        expect(peticion.url.queryParameters, {'orden': 'APELLIDOS'});
        return http.Response.bytes([1], 200);
      }),
    );
    addTearDown(api.cerrar);
    final central = CentralRepository(api);
    final sindicato = SindicatoRepository(api);
    await central.descargarInformePreImpresion(3);
    await central.descargarRevisionPadron(3);
    await central.descargarProductoresExcel(3);
    await central.descargarInformeNominalImpresion(3, [7]);
    await central.descargarInformeFase(3, 11);
    await sindicato.descargarInformePreImpresion(7);
    await sindicato.descargarRevisionPadron(7);
    await sindicato.descargarProductoresExcel(7);
    await sindicato.descargarNomina(7);
    await sindicato.descargarInformeFase(7, 11);
    expect(peticiones, 10);
  });
}
