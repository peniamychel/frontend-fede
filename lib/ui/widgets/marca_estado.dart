import 'package:flutter/material.dart';

import 'estados.dart';

/// Nombre de un registro, atenuado y con una etiqueta si está deshabilitado.
///
/// Los deshabilitados se siguen mostrando en las listas a propósito: si
/// desaparecieran no habría forma de volver a habilitarlos, y quien
/// deshabilitó por error pensaría que borró.
class TituloConEstado extends StatelessWidget {
  const TituloConEstado({
    super.key,
    required this.nombre,
    required this.habilitado,
  });

  final String nombre;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (habilitado) return Text(nombre);

    return Row(
      children: [
        Flexible(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tema.colorScheme.outline),
          ),
        ),
        const SizedBox(width: 8),
        const EtiquetaDeshabilitado(),
      ],
    );
  }
}

/// Etiqueta chica que dice que el registro está deshabilitado.
class EtiquetaDeshabilitado extends StatelessWidget {
  const EtiquetaDeshabilitado({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Text(
        'Deshabilitado',
        style: tema.textTheme.labelSmall?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Entrada de menú para habilitar o deshabilitar.
PopupMenuItem<String> itemCambiarEstado(bool habilitado) {
  return PopupMenuItem(
    value: 'estado',
    child: ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(habilitado ? Icons.block : Icons.check_circle_outline),
      title: Text(habilitado ? 'Deshabilitar' : 'Habilitar'),
    ),
  );
}

/// Pide confirmación solo para deshabilitar, ejecuta y avisa.
///
/// Habilitar no pregunta: devolver algo a la circulación no rompe nada, y la
/// confirmación sería un trámite. Deshabilitar sí, porque el registro deja de
/// contar y conviene que sea deliberado.
Future<bool> cambiarEstadoConAviso(
  BuildContext context, {
  required String nombre,
  required bool habilitado,
  required Future<void> Function(bool estado) accion,
  String? titulo,
  String? mensaje,
}) async {
  final nuevo = !habilitado;

  if (!nuevo) {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo ?? '¿Deshabilitar?'),
        content: Text(
          mensaje ??
              '«$nombre» va a quedar marcado como deshabilitado. No se borra '
                  'nada: sigue en la lista y lo podés volver a habilitar '
                  'cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deshabilitar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return false;
  }

  if (!context.mounted) return false;
  try {
    await accion(nuevo);
    if (context.mounted) {
      mostrarExito(context,
          nuevo ? '«$nombre» está habilitado.' : '«$nombre» quedó deshabilitado.');
    }
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}
