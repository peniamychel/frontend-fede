import 'package:flutter/material.dart';

import '../../core/guardar_archivo.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import 'estados.dart';
import 'elegir_orden_informe.dart';

class DescargarProductoresExcelBoton extends StatefulWidget {
  const DescargarProductoresExcelBoton.central({super.key, required this.id})
    : esCentral = true;
  const DescargarProductoresExcelBoton.sindicato({super.key, required this.id})
    : esCentral = false;

  final int id;
  final bool esCentral;

  @override
  State<DescargarProductoresExcelBoton> createState() =>
      _DescargarProductoresExcelBotonState();
}

class _DescargarProductoresExcelBotonState
    extends State<DescargarProductoresExcelBoton> {
  bool _descargando = false;
  bool _eligiendoOrden = false;

  Future<void> _descargar() async {
    if (_descargando || _eligiendoOrden) return;
    setState(() => _eligiendoOrden = true);
    try {
      final orden = await elegirOrdenInforme(context);
      if (orden == null || !mounted) return;
      setState(() {
        _eligiendoOrden = false;
        _descargando = true;
      });
      final padron = PadronScope.of(context);
      final archivo = widget.esCentral
          ? await padron.centrales.descargarProductoresExcel(
              widget.id,
              orden: orden,
            )
          : await padron.sindicatos.descargarProductoresExcel(
              widget.id,
              orden: orden,
            );
      if (!mounted) return;
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted) {
        mostrarExito(context, 'Lista de productores en Excel descargada.');
      }
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _descargando = false;
          _eligiendoOrden = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.puede('INFORMES_DESCARGAR')) return const SizedBox.shrink();
    return FilledButton.tonalIcon(
      onPressed: _descargando || _eligiendoOrden ? null : _descargar,
      icon: _descargando
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.table_chart_outlined),
      label: const Text('Lista de productores en Excel'),
    );
  }
}
