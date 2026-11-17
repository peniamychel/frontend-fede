import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/directorio_pagina.dart';
import 'package:fede/ui/jerarquia/sello_directorio.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/sesion_scope.dart';
import 'package:fede/ui/widgets/zona_soltar_archivos.dart';

import 'miniatura_prueba.dart';

void main() {
  for (final ambito in [Ambito.central, Ambito.sindicato]) {
    for (final imagenes in [false, true]) {
      for (final editable in [false, true]) {
        testWidgets(
          '${ambito.etiqueta}: imágenes $imagenes, edición autorizada $editable',
          (tester) async {
            tester.view.physicalSize = const Size(1400, 1600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final api = _ApiDirectorio(ambito, imagenes);
            final sesion = SesionControlador(AutenticacionRepository(api));
            addTearDown(sesion.dispose);
            sesion.sesion = Sesion(
              token: 'prueba',
              usuario: 'registro',
              nombreCompleto: 'Registro y revisión',
              rol: 'OPERADOR',
              roles: {editable ? 'EDITOR_DIRECTORIOS' : 'REGISTRO_REVISION'},
              permisos: {
                'PRODUCTORES_VER',
                'PRODUCTORES_REGISTRAR',
                'PRODUCTORES_EDITAR',
                'PRODUCTORES_ELIMINAR',
                'SIE_REVISAR',
                'FOTOS_PRODUCTORES_EDITAR',
                'PRODUCTORES_OBSERVAR',
                'NUMERO_LOTE_EDITAR',
                if (editable) 'DIRECTORIOS_EDITAR',
              },
              expiraEn: DateTime(2100),
            );
            if (imagenes) {
              for (final tipo in ['sello', 'firma', 'pie']) {
                await prepararMiniaturaPrueba(tester, api.imagen(tipo));
              }
            }
            await tester.pumpWidget(
              PadronScope(
                padron: Padron(api: api),
                child: SesionScope(
                  controlador: sesion,
                  child: MaterialApp(
                    home: DirectorioPagina(
                      ambito: ambito,
                      id: 3,
                      nombre: 'PRUEBA',
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Directorio de PRUEBA'), findsOneWidget);
            expect(find.text('ANA PÉREZ'), findsOneWidget);
            expect(find.text('Historial'), findsOneWidget);
            expect(
              find.text(
                ambito == Ambito.central
                    ? 'Teléfono de la central'
                    : 'Teléfono del sindicato',
              ),
              findsOneWidget,
            );
            final editarTelefono = find.byTooltip('Editar teléfono');
            expect(editarTelefono, editable ? findsOneWidget : findsNothing);
            expect(api.consultas, [
              '/${ambito.recurso}/3/directorio',
              '/${ambito.recurso}/3/directorio/historial',
            ]);
            final sello = find.byType(SelloDirectorio);
            final zonaSello = tester.widget<ZonaSoltarArchivos>(
              find.descendant(
                of: sello,
                matching: find.byType(ZonaSoltarArchivos),
              ),
            );
            expect(zonaSello.habilitada, editable);
            if (editable) {
              expect(find.text('Asignar'), findsOneWidget);
              expect(find.text('Dejar vacante'), findsOneWidget);
              expect(
                find.text(imagenes ? 'Cambiar sello' : 'Subir sello'),
                findsOneWidget,
              );
              expect(
                find.text(imagenes ? 'Editar' : 'Subir firma'),
                findsWidgets,
              );
            } else {
              for (final texto in [
                'Asignar',
                'Cambiar',
                'Dejar vacante',
                'Subir sello',
                'Cambiar sello',
                'Editar imagen',
                'Editar',
                'Borrar',
                'Subir firma',
                'Subir pie de firma',
              ]) {
                expect(find.text(texto), findsNothing, reason: texto);
              }
              expect(find.byTooltip('Borrar Firma'), findsNothing);
              expect(find.byTooltip('Borrar Pie de firma'), findsNothing);
              expect(
                tester
                    .widgetList<ZonaSoltarArchivos>(
                      find.byType(ZonaSoltarArchivos),
                    )
                    .every((zona) => !zona.habilitada),
                isTrue,
              );
              if (!imagenes) {
                expect(
                  tester
                      .widget<InkWell>(
                        find.descendant(
                          of: sello,
                          matching: find.byType(InkWell),
                        ),
                      )
                      .onTap,
                  isNull,
                );
              }
            }
            if (editable && !imagenes) {
              await tester.tap(editarTelefono);
              await tester.pumpAndSettle();
              final entrada = find.widgetWithText(
                TextFormField,
                'Número de teléfono',
              );
              await tester.enterText(entrada, '+591 7123-4567');
              await tester.tap(find.text('Guardar'));
              await tester.pumpAndSettle();
              expect(api.telefono, '+591 7123-4567');
              expect(find.text('+591 7123-4567'), findsOneWidget);

              await tester.tap(editarTelefono);
              await tester.pumpAndSettle();
              expect(
                tester.widget<TextFormField>(entrada).initialValue,
                api.telefono,
              );
              await tester.enterText(entrada, '');
              await tester.tap(find.text('Guardar'));
              await tester.pumpAndSettle();
              expect(api.telefono, isNull);
              expect(find.text('Sin registrar'), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

class _ApiDirectorio extends ApiClient {
  _ApiDirectorio(this.ambito, this.imagenes);

  final Ambito ambito;
  final bool imagenes;
  String? telefono;
  final consultas = <String>[];
  String imagen(String tipo) =>
      '/api/v1/archivos/prueba/${ambito.recurso}-$tipo.png';

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    consultas.add(ruta);
    if (ruta.endsWith('/historial')) return [];
    expect(ruta, '/${ambito.recurso}/3/directorio');
    return _directorio();
  }

  @override
  Future<Object?> parchear(String ruta, {Object? cuerpo}) async {
    expect(ruta, '/${ambito.recurso}/3/directorio/telefono');
    final valor = (cuerpo as Map<String, Object?>)['telefono']! as String;
    telefono = valor.isEmpty ? null : valor;
    return _directorio();
  }

  Map<String, Object?> _directorio() => {
    'ambito': ambito.valor,
    'ambitoId': 3,
    'ambitoNombre': 'PRUEBA',
    'telefono': telefono,
    if (imagenes) 'selloUrl': imagen('sello'),
    'puestos': [
      {
        'cargo': 'SECRETARIO_GENERAL',
        'actual': {
          'id': 12,
          'cargo': 'SECRETARIO_GENERAL',
          'productorId': 8,
          'productorNombre': 'ANA PÉREZ',
          'ambito': ambito.valor,
          'ambitoId': 3,
          'ambitoNombre': 'PRUEBA',
          'desde': '2026-10-01',
          'vigente': true,
          if (imagenes) 'firmaUrl': imagen('firma'),
          if (imagenes) 'pieFirmaUrl': imagen('pie'),
        },
      },
      {'cargo': 'HACIENDAS'},
    ],
  };
}
