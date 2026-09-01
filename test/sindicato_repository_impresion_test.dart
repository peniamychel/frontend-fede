import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/api_client.dart';
import 'package:fede/repositories/sindicato_repository.dart';

void main() {
  test('la impresión selectiva autoriza reimpresiones en el PDF', () async {
    final api = _ApiImpresion();
    final repositorio = SindicatoRepository(api);

    await repositorio.descargarAnversosSeleccionados(13, const [
      8,
      9,
    ], permitirReimpresion: true);

    expect(api.ruta, '/sindicatos/13/credenciales/impresion/anversos.pdf');
    expect(api.cuerpo, {
      'productorIds': [8, 9],
      'permitirReimpresion': true,
    });
  });

  test('la revisión envía el grupo y solo las tarjetas confirmadas', () async {
    final api = _ApiImpresion();
    final repositorio = SindicatoRepository(api);

    await repositorio.revisarUltimoGrupo(13, 41, const [8]);

    expect(api.ruta, '/sindicatos/13/credenciales/impresion/ultimo-grupo');
    expect(api.cuerpo, {
      'grupoId': 41,
      'productorIdsImpresos': [8],
    });
  });
}

class _ApiImpresion extends ApiClient {
  String? ruta;
  Object? cuerpo;

  @override
  Future<DescargaBinaria> crearBytes(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    this.ruta = ruta;
    this.cuerpo = cuerpo;
    return DescargaBinaria(
      bytes: Uint8List(0),
      nombreArchivo: 'credenciales.pdf',
      tipoMime: 'application/pdf',
    );
  }

  @override
  Future<Object?> parchear(String ruta, {Object? cuerpo}) async {
    this.ruta = ruta;
    this.cuerpo = cuerpo;
    return const {
      'sindicatoId': 13,
      'sindicato': '1RO DE MAYO',
      'total': 0,
      'impresos': 0,
      'faltantesConFoto': 0,
      'sinFoto': 0,
      'listosParaImprimir': 0,
      'faltantesDelSindicato': [],
      'candidatos': [],
    };
  }
}
