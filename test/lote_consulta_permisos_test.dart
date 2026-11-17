import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/lotes/lote_pagina.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/sesion_scope.dart';

void main() {
  for (final editable in [false, true]) {
    testWidgets('consulta del lote conserva datos, gestión general $editable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiLoteConsulta();
      addTearDown(api.cerrar);
      final sesion = SesionControlador(AutenticacionRepository(api));
      addTearDown(sesion.dispose);
      sesion.sesion = Sesion(
        token: 'prueba',
        usuario: 'registro',
        nombreCompleto: 'Registro',
        rol: 'OPERADOR',
        roles: {editable ? 'REGISTRO' : 'REGISTRO_REVISION'},
        permisos: {
          'PRODUCTORES_VER',
          'PRODUCTORES_REGISTRAR',
          'PRODUCTORES_EDITAR',
          'PRODUCTORES_ELIMINAR',
          'SIE_REVISAR',
          'FOTOS_PRODUCTORES_EDITAR',
          'PRODUCTORES_OBSERVAR',
          'NUMERO_LOTE_EDITAR',
          'LOTES_DESASIGNAR',
          if (editable) 'LOTES_EDITAR',
        },
        expiraEn: DateTime(2100),
      );
      await tester.pumpWidget(
        PadronScope(
          padron: Padron(api: api),
          child: SesionScope(
            controlador: sesion,
            child: const MaterialApp(home: LotePagina(loteId: 9)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lote 15 B'), findsOneWidget);
      expect(find.text('ANA PÉREZ'), findsOneWidget);
      expect(find.text('Quiénes la tuvieron'), findsOneWidget);
      for (final accion in [
        'Vender o traspasar',
        'Cambiar número',
        'Cambiar clasificación',
      ]) {
        expect(find.text(accion), editable ? findsOneWidget : findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _ApiLoteConsulta extends ApiClient {
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/lotes/9') {
      return {
        'id': 9,
        'numero': '15',
        'codigo': '15 B',
        'estado': 'CON_SISTEMA',
        'sindicatoId': 7,
        'sindicatoNombre': 'LIBERTAD',
        'tenedor': {
          'productorId': 42,
          'nombre': 'ANA PÉREZ',
          'desde': '2026-10-01',
        },
      };
    }
    if (ruta == '/lotes/9/historial' || ruta == '/lotes') return [];
    throw StateError('GET inesperado: $ruta');
  }
}
