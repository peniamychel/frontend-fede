import 'package:flutter/material.dart';

import '../../core/guardar_archivo.dart';
import '../padron_scope.dart';
import 'elegir_orden_informe.dart';
import 'estados.dart';

class DescargarObservacionesPreimpresionBoton extends StatefulWidget {
  const DescargarObservacionesPreimpresionBoton.central({
    super.key,
    required this.id,
  }) : esCentral = true;
  const DescargarObservacionesPreimpresionBoton.sindicato({
    super.key,
    required this.id,
  }) : esCentral = false;

  final int id;
  final bool esCentral;

  @override
  State<DescargarObservacionesPreimpresionBoton> createState() =>
      _DescargarObservacionesPreimpresionBotonState();
}

class _DescargarObservacionesPreimpresionBotonState
    extends State<DescargarObservacionesPreimpresionBoton> {
  bool _eligiendoOrden = false;
  bool _descargando = false;

  Future<void> _descargar() async {
    if (_eligiendoOrden || _descargando) return;
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
          ? await padron.centrales.descargarObservacionesPreImpresion(
              widget.id,
              orden: orden,
            )
          : await padron.sindicatos.descargarObservacionesPreImpresion(
              widget.id,
              orden: orden,
            );
      if (!mounted) return;
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted)
        mostrarExito(context, 'Informe de observaciones descargado.');
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _eligiendoOrden = false;
          _descargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: _eligiendoOrden || _descargando ? null : _descargar,
    icon: _descargando
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.rule_outlined),
    label: const Text('Preimpresión con observaciones'),
  );
}
