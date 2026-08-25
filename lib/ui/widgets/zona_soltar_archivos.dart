import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'estados.dart';

const extensionesImagen = <String>{'jpg', 'jpeg', 'png', 'webp'};
const extensionesHojaActa = <String>{...extensionesImagen, 'pdf'};

/// Agrega arrastrar y soltar sin reemplazar la selección tradicional.
///
/// En Android los botones de cámara y galería siguen siendo el mecanismo
/// principal. En web y escritorio esta zona permite soltar archivos desde el
/// explorador y muestra una guía solamente mientras el archivo está encima.
class ZonaSoltarArchivos extends StatefulWidget {
  const ZonaSoltarArchivos({
    super.key,
    required this.child,
    required this.alSoltar,
    required this.extensionesPermitidas,
    this.habilitada = true,
    this.permiteVarios = false,
    this.mensaje = 'Soltá la imagen aquí',
  });

  final Widget child;
  final Future<void> Function(List<DropItem>) alSoltar;
  final Set<String> extensionesPermitidas;
  final bool habilitada;
  final bool permiteVarios;
  final String mensaje;

  @override
  State<ZonaSoltarArchivos> createState() => _ZonaSoltarArchivosState();
}

class _ZonaSoltarArchivosState extends State<ZonaSoltarArchivos> {
  bool _arrastrando = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rutaVisible = ModalRoute.of(context)?.isCurrent ?? true;
    return DropTarget(
      // desktop_drop también detecta eventos detrás de un diálogo; se apaga
      // mientras otra ruta está encima para no abrir dos vistas previas.
      enable: widget.habilitada && rutaVisible,
      onDragEntered: (_) => setState(() => _arrastrando = true),
      onDragExited: (_) => setState(() => _arrastrando = false),
      onDragDone: (detalle) {
        setState(() => _arrastrando = false);
        final archivos = detalle.files;
        if (archivos.isEmpty) return;
        if (archivos.any((archivo) => archivo is DropItemDirectory)) {
          mostrarAviso(context, 'Soltá archivos, no carpetas');
          return;
        }
        if (!widget.permiteVarios && archivos.length != 1) {
          mostrarAviso(context, 'Soltá una sola imagen');
          return;
        }
        final noPermitidos = archivos
            .where(
              (archivo) => !_extensionPermitida(nombreArchivoSoltado(archivo)),
            )
            .map(nombreArchivoSoltado)
            .toList();
        if (noPermitidos.isNotEmpty) {
          mostrarAviso(
            context,
            'Tipo de archivo no permitido',
            detalle:
                '${noPermitidos.join(', ')}. Permitidos: ${widget.extensionesPermitidas.join(', ')}.',
          );
          return;
        }
        unawaited(widget.alSoltar(archivos));
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_arrastrando)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tema.colorScheme.primaryContainer.withValues(
                      alpha: .94,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tema.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 38,
                          color: tema.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.mensaje,
                          textAlign: TextAlign.center,
                          style: tema.textTheme.titleMedium?.copyWith(
                            color: tema.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _extensionPermitida(String nombre) {
    final punto = nombre.lastIndexOf('.');
    if (punto < 0 || punto == nombre.length - 1) return false;
    return widget.extensionesPermitidas.contains(
      nombre.substring(punto + 1).toLowerCase(),
    );
  }
}

/// Materializa un archivo soltado para los repositorios, también en web donde
/// no existe una ruta local que se pueda abrir después.
Future<PlatformFile> archivoSoltadoAPlatformFile(DropItem archivo) async {
  final bytes = await archivo.readAsBytes();
  return PlatformFile(
    name: nombreArchivoSoltado(archivo),
    size: bytes.length,
    bytes: bytes,
  );
}

String nombreArchivoSoltado(DropItem archivo) {
  final candidato = archivo.name.trim().isNotEmpty
      ? archivo.name
      : archivo.path;
  final segmentos = candidato.replaceAll('\\', '/').split('/');
  return segmentos.lastWhere(
    (segmento) => segmento.isNotEmpty,
    orElse: () => 'archivo-sin-nombre',
  );
}

/// Texto auxiliar para hacer visible la función sin agregar ruido en Android.
class AyudaArrastrarArchivo extends StatelessWidget {
  const AyudaArrastrarArchivo({
    super.key,
    this.texto = 'También podés arrastrar una imagen aquí.',
  });

  final String texto;

  @override
  Widget build(BuildContext context) {
    final disponible =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (!disponible) return const SizedBox.shrink();

    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.file_download_outlined,
            size: 15,
            color: tema.colorScheme.outline,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
