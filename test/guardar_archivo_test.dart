import 'package:fede/core/guardar_archivo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(canal, null));

  for (final archivo in [
    ('informe.pdf', 'application/pdf', [37, 80, 68, 70, 45]),
    ('ficha-productor-42.png', 'image/png', [137, 80, 78, 71, 13, 10, 26, 10]),
  ]) {
    test(
      'descarga ${archivo.$1} sin reabrir el documento guardado en Android',
      () async {
        var guardados = 0;
        messenger.setMockMethodCallHandler(canal, (llamada) async {
          expect(llamada.method, 'save');
          final argumentos = llamada.arguments as Map;
          expect(argumentos['fileName'], archivo.$1);
          expect(argumentos['bytes'], isA<Uint8List>());
          expect(argumentos['bytes'], archivo.$3);
          guardados++;
          // El código nativo ya escribió los bytes con ContentResolver.
          // Es una referencia de documento, no un archivo para dart:io.
          return '/document/336';
        });
        await expectLater(
          guardarArchivo(archivo.$3, archivo.$1, archivo.$2),
          completes,
        );
        expect(guardados, 1);
      },
    );
  }

  test('cancelar el selector termina sin error', () async {
    messenger.setMockMethodCallHandler(canal, (_) async => null);
    await expectLater(
      guardarArchivo([1], 'informe.pdf', 'application/pdf'),
      completes,
    );
  });

  test('un fallo real del guardado sigue informándose al usuario', () async {
    messenger.setMockMethodCallHandler(canal, (_) async {
      throw PlatformException(
        code: 'save_failed',
        message: 'No se pudo guardar',
      );
    });
    await expectLater(
      guardarArchivo([1], 'informe.pdf', 'application/pdf'),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'código', 'save_failed'),
      ),
    );
  });
}
