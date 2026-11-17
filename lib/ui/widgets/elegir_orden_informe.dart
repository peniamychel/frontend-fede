import 'package:flutter/material.dart';

import '../../models/orden_informes.dart';
export '../../models/orden_informes.dart';

/// Cada descarga comienza con su propia elección; cerrar no genera un archivo.
Future<OrdenInformes?> elegirOrdenInforme(BuildContext context) =>
    showDialog<OrdenInformes>(
      context: context,
      builder: (_) => const _ElegirOrdenInforme(),
    );

class _ElegirOrdenInforme extends StatefulWidget {
  const _ElegirOrdenInforme();

  @override
  State<_ElegirOrdenInforme> createState() => _ElegirOrdenInformeState();
}

class _ElegirOrdenInformeState extends State<_ElegirOrdenInforme> {
  OrdenInformes _orden = OrdenInformes.apellidos;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Orden de la lista'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: RadioGroup<OrdenInformes>(
          groupValue: _orden,
          onChanged: (valor) {
            if (valor != null) setState(() => _orden = valor);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final orden in OrdenInformes.values)
                RadioListTile<OrdenInformes>(
                  value: orden,
                  title: Text(orden.etiqueta),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_orden),
        child: const Text('Generar'),
      ),
    ],
  );
}
