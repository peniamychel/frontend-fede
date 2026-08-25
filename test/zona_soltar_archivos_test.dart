import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:fede/ui/widgets/zona_soltar_archivos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget aplicacion(Widget child) => MaterialApp(home: Scaffold(body: child));

  DropDoneDetails detalle(List<DropItem> archivos) => DropDoneDetails(
    files: archivos,
    localPosition: Offset.zero,
    globalPosition: Offset.zero,
  );

  testWidgets('acepta una imagen soltada sin distinguir mayúsculas', (
    tester,
  ) async {
    List<DropItem>? recibidos;
    await tester.pumpWidget(
      aplicacion(
        ZonaSoltarArchivos(
          extensionesPermitidas: extensionesImagen,
          alSoltar: (archivos) async => recibidos = archivos,
          child: const SizedBox(width: 200, height: 100),
        ),
      ),
    );

    final zona = tester.widget<DropTarget>(find.byType(DropTarget));
    zona.onDragDone!(
      detalle([
        DropItemFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'foto.PNG',
          path: 'C:/temporal/foto.PNG',
        ),
      ]),
    );
    await tester.pump();

    expect(recibidos, isNotNull);
    expect(recibidos, hasLength(1));
  });

  testWidgets('rechaza archivos que no son imágenes', (tester) async {
    var llamado = false;
    await tester.pumpWidget(
      aplicacion(
        ZonaSoltarArchivos(
          extensionesPermitidas: extensionesImagen,
          alSoltar: (_) async => llamado = true,
          child: const SizedBox(width: 200, height: 100),
        ),
      ),
    );

    final zona = tester.widget<DropTarget>(find.byType(DropTarget));
    zona.onDragDone!(
      detalle([
        DropItemFile.fromData(
          Uint8List.fromList([1]),
          name: 'notas.txt',
          path: 'C:/temporal/notas.txt',
        ),
      ]),
    );
    await tester.pump();

    expect(llamado, isFalse);
    expect(find.text('Tipo de archivo no permitido'), findsOneWidget);
  });

  test('materializa los bytes de un archivo soltado', () async {
    final archivo = DropItemFile.fromData(
      Uint8List.fromList([4, 5, 6]),
      name: 'sello.webp',
      path: 'C:/temporal/sello.webp',
    );

    final convertido = await archivoSoltadoAPlatformFile(archivo);

    expect(convertido.name, 'sello.webp');
    expect(convertido.bytes, [4, 5, 6]);
  });
}
