import 'package:flutter/material.dart';
import '../imagen_autenticada.dart';

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
    this.seleccionado = false,
  });

  final Productor productor;
  final VoidCallback alTocar;
  final bool seleccionado;

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
      if (productor.fotografiaPendienteEdicion)
        'Fotografía pendiente de edición',
      if (documentos.isNotEmpty) documentos,
      if (productor.numeroLote?.isNotEmpty ?? false)
        'N° lote: ${productor.numeroLote}',
      if (mostrarRuta) productor.ruta,
      if (productor.revisionLotePendiente) productor.resumenRevisionLote,
      if (productor.ciDuplicada) 'Revisión CI · Cédula repetida',
      if (productor.observado)
        'Observado: ${productor.observacion ?? 'Sin detalle'}',
      if (productor.revisionSiePendiente ||
          productor.revisionSieBloqueaImpresion)
        'Revisión SIE pendiente',
    ];

    return ListTile(
      key: ValueKey('fila-productor-${productor.id}'),
      onTap: alTocar,
      selected: seleccionado,
      tileColor: productor.ciDuplicada
          ? tema.colorScheme.errorContainer.withValues(alpha: 0.3)
          : productor.revisionSiePendiente
          ? tema.colorScheme.surfaceContainerHighest
          : null,
      textColor: productor.ciDuplicada
          ? tema.colorScheme.error
          : productor.revisionSiePendiente
          ? tema.colorScheme.outline
          : null,
      selectedColor: productor.ciDuplicada
          ? tema.colorScheme.error
          : productor.revisionSiePendiente
          ? tema.colorScheme.outline
          : null,
      selectedTileColor:
          (productor.ciDuplicada
                  ? tema.colorScheme.errorContainer
                  : tema.colorScheme.primaryContainer)
              .withValues(alpha: 0.55),
      shape: seleccionado
          ? RoundedRectangleBorder(
              side: BorderSide(
                color: productor.ciDuplicada
                    ? tema.colorScheme.error
                    : tema.colorScheme.primary,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      leading: _miniatura(context),
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
                          productor.ciDuplicada ||
                              (productor.revisionLotePendiente &&
                                  texto == productor.resumenRevisionLote) ||
                              (productor.observado &&
                                  texto.startsWith('Observado:')) ||
                              (productor.revisionSieBloqueaImpresion &&
                                  texto == 'Revisión SIE pendiente')
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
  Widget _miniatura(BuildContext context) {
    const lado = 40.0;
    final colores = Theme.of(context).colorScheme;
    final miniatura = productor.miniaturaUrl;
    final fotoArchivada = miniatura == null && productor.tieneFoto;

    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fotoArchivada
            ? colores.primaryContainer
            : colores.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: miniatura != null
          ? ImagenAutenticada(
              ApiConfig.urlAbsoluta(miniatura),
              width: lado,
              height: lado,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.person, size: 20, color: colores.outline),
            )
          : Icon(
              fotoArchivada ? Icons.person : Icons.person_off_outlined,
              size: 20,
              color: fotoArchivada
                  ? colores.onPrimaryContainer
                  : colores.outline,
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
    final (mensaje, color) = productor.ciDuplicada
        ? (
            'Revisión CI: cédula repetida, excluido de impresión',
            tema.colorScheme.error,
          )
        : !productor.habilitado
        ? ('Deshabilitado: excluido de impresión', tema.colorScheme.outline)
        : productor.observado
        ? ('Observado: excluido de impresión', tema.colorScheme.error)
        : productor.revisionSieBloqueaImpresion
        ? (
            'Revisión SIE pendiente: excluido de impresión',
            tema.colorScheme.error,
          )
        : productor.fotografiaPendienteEdicion
        ? (
            'Fotografía pendiente de edición: impresión bloqueada',
            tema.colorScheme.error,
          )
        : productor.revisionLotePendiente
        ? ('En revisión: falta número de lote', tema.colorScheme.outline)
        : productor.faseImpresionPendiente &&
              (productor.credencialLista || productor.reimpresionFasePendiente)
        ? (
            productor.reimpresionFasePendiente
                ? 'Reimpresión pendiente para la fase actual o la próxima'
                : 'Pendiente para la fase actual o la próxima',
            Colors.orange.shade800,
          )
        : !productor.credencialLista
        ? ('Credencial incompleta o sin fotografía', tema.colorScheme.outline)
        : productor.credencialImpresa
        ? ('Credencial impresa', Colors.green)
        : (
            'Datos completos, sin marca pendiente para una fase',
            Colors.amber.shade700,
          );
    return Tooltip(
      message: mensaje,
      child: Icon(Icons.print, size: 19, color: color),
    );
  }
}
