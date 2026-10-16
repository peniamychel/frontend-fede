import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fede/core/api_client.dart';
import 'package:fede/ui/credenciales/tarjeta_previa.dart';
import 'package:fede/ui/operadores/operador_credencial_previa_pagina.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/operadores/foto_operador_recorte_pagina.dart';
import 'package:fede/ui/operadores/operador_formulario_pagina.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const _datos = {
  'id': 7,
  'nombres': 'ANA',
  'apellidos': 'PEREZ',
  'ci': '123456',
  'cargo': 'OPERADORA',
  'telefono': '77712345',
};

Uint8List _png({int lado = 64}) => Uint8List.fromList(
  img.encodePng(img.Image(width: lado, height: lado, numChannels: 4)),
);

class _Selector extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      XFile.fromData(_png(), name: 'retrato.png', mimeType: 'image/png');
}

class _Api extends ApiClient {
  int creados = 0;
  int editados = 0;
  final subidas = <List<int>>[];
  final confirmacion = Completer<Object?>();

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    creados++;
    return {...(cuerpo as Map<String, dynamic>), 'id': 7};
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    editados++;
    expect(ruta, '/credenciales-operadores/7');
    return {...(cuerpo as Map<String, dynamic>), 'id': 7};
  }

  @override
  Future<Object?> subirArchivo(
    String ruta, {
    required String campo,
    required List<int> bytes,
    required String nombreArchivo,
    Map<String, String?>? campos,
    Map<String, ArchivoAdjunto>? archivosAdicionales,
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    expect(ruta, '/credenciales-operadores/7/foto');
    expect(campo, 'archivo');
    subidas.add(List.of(bytes));
    if (subidas.length == 1) {
      throw SinConexionException('servidor', Exception('Sin conexión'));
    }
    return confirmacion.future;
  }
}

class _ApiPrevia extends ApiClient {
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/configuracion/credencial-operador') {
      return {
        'diseno': {'ancho': 153.01, 'alto': 242.65, 'elementos': []},
        'campos': [],
      };
    }
    return {..._datos, 'federacion': 'CARRASCO', 'resena': 'Autorizado'};
  }
}

void main() {
  testWidgets('credencial vertical cabe en pantalla móvil de 360 píxeles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: _ApiPrevia()),
        child: const MaterialApp(
          home: OperadorCredencialPreviaPagina(operadorId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tarjetas = tester.widgetList<TarjetaPrevia>(
      find.byType(TarjetaPrevia),
    );
    expect(tarjetas, hasLength(2));
    for (final tarjeta in tarjetas) {
      expect(tarjeta.ancho, 312);
      expect(tarjeta.diseno!.alto, greaterThan(tarjeta.diseno!.ancho));
    }
    expect(tester.takeException(), isNull);
  });

  test(
    'el retrato recortado mantiene PNG, alfa y un máximo de 600 píxeles',
    () {
      final grande = prepararFotoOperador((
        _png(lado: 800),
        const Recorte(x: 0, y: 0, ancho: 800, alto: 800),
      ));
      final png = img.decodePng(grande)!;
      expect((png.width, png.height), (600, 600));
      expect(png.getPixel(0, 0).a, 0);
      final pequena = img.decodePng(
        prepararFotoOperador((
          _png(),
          const Recorte(x: 8, y: 8, ancho: 40, alto: 40),
        )),
      )!;
      expect((pequena.width, pequena.height), (40, 40));
      expect(pequena.getPixel(0, 0).a, 0);
    },
  );

  test(
    'la foto llega al lienzo y su API usa sesión y multipart independiente',
    () async {
      final peticiones = <http.Request>[];
      final api = ApiClient(
        cliente: MockClient((peticion) async {
          peticiones.add(peticion);
          if (peticion.method == 'GET') {
            return http.Response.bytes(
              _png(),
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          return http.Response(
            jsonEncode({
              ..._datos,
              'fotoUrl': peticion.method == 'DELETE'
                  ? null
                  : '/archivos/operador.png',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      )..usarToken('token');
      final repo = OperadorCredencialRepository(api);
      final operador = await repo.subirFoto(7, bytes: _png());
      expect(operador.fotoUrl, '/archivos/operador.png');
      expect(peticiones.last.method, 'POST');
      expect(
        peticiones.last.url.path,
        '/api/v1/credenciales-operadores/7/foto',
      );
      final multipart = utf8.decode(
        peticiones.last.bodyBytes,
        allowMalformed: true,
      );
      expect(multipart, contains('name="archivo"'));
      expect(multipart, contains('fotografia-operador.png'));
      final archivo = await repo.descargarFoto(7);
      expect(archivo.tipoMime, 'image/png');
      final sinFoto = await repo.quitarFoto(7);
      expect(sinFoto.fotoUrl, isNull);
      expect(peticiones.last.method, 'DELETE');
      expect(
        peticiones.every((p) => p.headers['authorization'] == 'Bearer token'),
        isTrue,
      );
      final previa = OperadorCredencialPrevia.desdeJson({
        ..._datos,
        'fotoUrl': '/archivos/operador.png',
      });
      expect(previa.tarjeta.fotoUrl, '/archivos/operador.png');
      api.cerrar();
    },
  );

  testWidgets(
    'al fallar la foto conserva el retrato y reutiliza el operador creado',
    (tester) async {
      final api = _Api();
      OperadorCredencial? resultado;
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: api),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    resultado = await Navigator.of(context)
                        .push<OperadorCredencial>(
                          MaterialPageRoute(
                            builder: (_) => OperadorFormularioPagina(
                              selectorImagenes: _Selector(),
                            ),
                          ),
                        );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final campos = ['ANA', 'PEREZ', '123456', 'OPERADORA', '77712345'];
      for (var i = 0; i < campos.length; i++) {
        await tester.ensureVisible(find.byType(TextFormField).at(i));
        await tester.enterText(find.byType(TextFormField).at(i), campos[i]);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Subir foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subir foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de galería'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Usar fotografía'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Fotografía preparada. Se subirá al guardar.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(api.creados, 1);
      expect(resultado, isNull);
      expect(find.text('Reintentar guardar fotografía'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.ensureVisible(find.text('Reintentar guardar fotografía'));
      await tester.tap(find.text('Reintentar guardar fotografía'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.creados, 1);
      expect(api.editados, 1);
      expect(api.subidas, hasLength(2));
      expect(api.subidas[1], api.subidas[0]);
      expect(resultado, isNull);
      expect(find.text('Guardando…'), findsOneWidget);
      api.confirmacion.complete({..._datos, 'fotoUrl': '/archivos/nueva.png'});
      await tester.pumpAndSettle();
      expect(resultado?.fotoUrl, '/archivos/nueva.png');
      expect(find.text('Abrir'), findsOneWidget);
    },
  );
}
