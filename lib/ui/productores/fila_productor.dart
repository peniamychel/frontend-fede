import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../widgets/marca_estado.dart';

/// Fila de productor para listados.
///
/// La usan el padrón completo y el listado por sindicato, así que vive aparte:
/// si cambia cómo se muestra un productor, cambia en los dos sitios a la vez.
class FilaProductor extends StatelessWidget {
  const FilaProductor({
    super.key,
    required this.productor,
    required this.alTocar,
    this.mostrarRuta = true,
  });

  final Productor productor;
  final VoidCallback alTocar;

  /// Dentro de un sindicato concreto la ruta es la misma en todas las filas y
  /// solo ocupa espacio.
  final bool mostrarRuta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final documentos = [
      if (productor.ci != null && productor.ci!.isNotEmpty)
        'CI ${productor.ci}',
    ].join('  ·  ');

    final subtitulos = [
      if (documentos.isNotEmpty) documentos,
      if (mostrarRuta) productor.ruta,
      if (productor.revisionLotePendiente) productor.resumenRevisionLote,
      if (productor.observado)
        'Observado: ${productor.observacion ?? 'Sin detalle'}',
      if (productor.revisionSieBloqueaImpresion) 'Revisión SIE pendiente',
    ];

    return ListTile(
      onTap: alTocar,
      leading: _avatar(context),
      title: TituloConEstado(
        nombre: productor.nombreCompleto.isEmpty
            ? productor.nombres
            : productor.nombreCompleto,
        habilitado: productor.habilitado,
      ),
      subtitle: subtitulos.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, texto) in subtitulos.indexed)
                  Text(
                    texto,
                    maxLines:
                        (productor.revisionLotePendiente &&
                                texto == productor.resumenRevisionLote) ||
                            (productor.observado &&
                                texto.startsWith('Observado:'))
                        ? 2
                        : 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color:
                          (productor.revisionLotePendiente &&
                                  texto == productor.resumenRevisionLote) ||
                              (productor.observado &&
                                  texto.startsWith('Observado:'))
                          ? tema.colorScheme.error
                          : i == subtitulos.length - 1 && mostrarRuta
                          ? tema.colorScheme.outline
                          : null,
                    ),
                  ),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EstadoImpresion(productor: productor),
          const SizedBox(width: 5),
          _ClasificacionProductor(productor: productor),
          const SizedBox(width: 5),
          if (productor.marcado)
            Tooltip(
              message: 'Marcado en la revisión',
              child: Icon(
                Icons.bookmark,
                size: 18,
                color: tema.colorScheme.tertiary,
              ),
            ),
          if (productor.tieneCorreccionPendiente)
            Tooltip(
              message: 'Corrección de nombre sin confirmar',
              child: Icon(
                Icons.edit_note,
                size: 20,
                color: tema.colorScheme.error,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }

  /// La miniatura real si está cargada; si no, el icono de siempre.
  ///
  /// El icono distingue dos ausencias que no son lo mismo: no tener imagen
  /// subida, y no tener siquiera el rótulo de la foto en la planilla.
  Widget _avatar(BuildContext context) {
    final tema = Theme.of(context);
    final miniatura = productor.miniaturaUrl;

    if (miniatura != null) {
      return CircleAvatar(
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
        // foregroundImage y no backgroundImage: si la carga falla, se ve el
        // child de respaldo en vez de un círculo vacío.
        foregroundImage: NetworkImage(ApiConfig.urlAbsoluta(miniatura)),
        child: Icon(Icons.person, size: 20, color: tema.colorScheme.outline),
      );
    }

    return CircleAvatar(
      backgroundColor: productor.tieneFoto
          ? tema.colorScheme.primaryContainer
          : tema.colorScheme.surfaceContainerHighest,
      child: Icon(
        productor.tieneFoto ? Icons.person : Icons.person_off_outlined,
        size: 20,
        color: productor.tieneFoto
            ? tema.colorScheme.onPrimaryContainer
            : tema.colorScheme.outline,
      ),
    );
  }
}

/// Identifica la clasificación sin ocupar el espacio de una etiqueta completa.
///
/// `SIN_SISTEMA` usa N para no confundirse con la S de `CON_SISTEMA`. Los
/// estados que no representan una clasificación válida se muestran igual que
/// la ausencia de clasificación: un círculo gris vacío.
class _ClasificacionProductor extends StatelessWidget {
  const _ClasificacionProductor({required this.productor});

  final Productor productor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final clasificacion = productor.clasificacion;
    final (letra, etiqueta) = switch (clasificacion) {
      EstadoLote.conSistema => ('S', 'Sistema'),
      EstadoLote.sinSistema => ('N', 'Sin sistema'),
      EstadoLote.blanco => ('B', 'Blanco'),
      EstadoLote.fraccionado => ('F', 'Fraccionado'),
      EstadoLote.detallista => ('D', 'Detallista'),
      EstadoLote.comunitario => ('C', 'Comunitario'),
      _ => ('', 'Sin clasificación'),
    };
    final tieneClasificacion = letra.isNotEmpty;
    final color = tieneClasificacion
        ? tema.colorScheme.primary
        : tema.colorScheme.outline;

    return Tooltip(
      message: 'Clasificación: $etiqueta',
      child: Semantics(
        label: 'Clasificación: $etiqueta',
        child: Container(
          key: ValueKey('clasificacion-productor-${productor.id}'),
          width: 21,
          height: 21,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: tieneClasificacion
              ? Text(
                  letra,
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _EstadoImpresion extends StatelessWidget {
  const _EstadoImpresion({required this.productor});

  final Productor productor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (mensaje, color) = !productor.habilitado
        ? ('Deshabilitado: excluido de impresión', tema.colorScheme.outline)
        : productor.observado
        ? ('Observado: excluido de impresión', tema.colorScheme.error)
        : productor.revisionSieBloqueaImpresion
        ? ('Revisión SIE pendiente: excluido de impresión', Colors.orange)
        : productor.revisionLotePendiente
        ? ('En revisión: falta número de lote', tema.colorScheme.outline)
        : !productor.credencialLista
        ? ('Credencial incompleta o sin fotografía', tema.colorScheme.outline)
        : productor.credencialImpresa
        ? ('Credencial impresa', Colors.green)
        : ('Lista, pendiente de impresión', Colors.amber.shade700);
    return Tooltip(
      message: mensaje,
      child: Icon(Icons.print, size: 19, color: color),
    );
  }
}
