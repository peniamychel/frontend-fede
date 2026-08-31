import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart' show ArchivoAdjunto, DescargaBinaria;
import '../../core/guardar_archivo.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import '../widgets/zona_soltar_archivos.dart';

const _extensionesListaFisica = {'jpg', 'jpeg', 'png'};

/// Fotografías optimizadas y PDF consolidado de la lista física del sindicato.
class ListaFisicaSindicatoPagina extends StatefulWidget {
  const ListaFisicaSindicatoPagina({super.key, required this.sindicato});

  final Sindicato sindicato;

  @override
  State<ListaFisicaSindicatoPagina> createState() =>
      _ListaFisicaSindicatoPaginaState();
}

class _ListaFisicaSindicatoPaginaState
    extends State<ListaFisicaSindicatoPagina> {
  late Future<ListaFisicaSindicato> _carga;
  bool _inicializada = false;
  bool _guardando = false;

  SindicatoRepository get _repositorio => PadronScope.of(context).sindicatos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicializada) return;
    _inicializada = true;
    _carga = _repositorio.listaFisica(widget.sindicato.id);
  }

  void _recargar() {
    setState(() => _carga = _repositorio.listaFisica(widget.sindicato.id));
  }

  Future<void> _elegirFotografias() async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensionesListaFisica.toList(),
      allowMultiple: true,
      withData: true,
    );
    if (resultado == null) return;
    await _agregar(resultado.files);
  }

  Future<void> _tomarFotografia() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    await _agregar([
      PlatformFile(name: foto.name, size: bytes.length, bytes: bytes),
    ]);
  }

  Future<void> _alSoltar(List<DropItem> archivos) async {
    final materializados = <PlatformFile>[];
    for (final archivo in archivos) {
      materializados.add(await archivoSoltadoAPlatformFile(archivo));
    }
    await _agregar(materializados);
  }

  Future<void> _agregar(List<PlatformFile> archivos) async {
    final adjuntos = _adjuntos(archivos);
    if (adjuntos == null || adjuntos.isEmpty) return;
    await _mutar(
      () =>
          _repositorio.agregarPaginasListaFisica(widget.sindicato.id, adjuntos),
      'Las fotografías se agregaron y el PDF quedó actualizado.',
    );
  }

  Future<void> _reemplazar(PaginaListaFisica pagina) async {
    final resultado = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensionesListaFisica.toList(),
      allowMultiple: false,
      withData: true,
    );
    if (resultado == null) return;
    final adjuntos = _adjuntos(resultado.files);
    if (adjuntos == null || adjuntos.isEmpty) return;
    await _mutar(
      () => _repositorio.reemplazarPaginaListaFisica(
        widget.sindicato.id,
        pagina.id,
        adjuntos.single,
      ),
      'La página ${pagina.orden} fue reemplazada.',
    );
  }

  Future<void> _quitar(PaginaListaFisica pagina) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quitar página ${pagina.orden}'),
        content: const Text(
          'La fotografía original se eliminará y el PDF se volverá a generar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _mutar(
      () =>
          _repositorio.quitarPaginaListaFisica(widget.sindicato.id, pagina.id),
      'La página fue eliminada y las restantes se renumeraron.',
    );
  }

  List<ArchivoAdjunto>? _adjuntos(List<PlatformFile> archivos) {
    final incompletos = archivos.where((archivo) => archivo.bytes == null);
    if (incompletos.isNotEmpty) {
      mostrarAviso(
        context,
        'No se pudo leer una de las fotografías.',
        detalle: incompletos.map((a) => a.name).join(', '),
      );
      return null;
    }
    return archivos
        .map(
          (archivo) => ArchivoAdjunto(
            bytes: archivo.bytes!,
            nombreArchivo: archivo.name,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _mutar(
    Future<ListaFisicaSindicato> Function() accion,
    String mensaje,
  ) async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final actualizado = await accion();
      if (!mounted) return;
      setState(() => _carga = Future.value(actualizado));
      mostrarExito(context, mensaje);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _verPdf() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VisorListaFisicaPdf(
          sindicato: widget.sindicato,
          descarga: _repositorio.descargarListaFisica(widget.sindicato.id),
        ),
      ),
    );
  }

  Future<void> _descargarPdf() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final archivo = await _repositorio.descargarListaFisica(
        widget.sindicato.id,
      );
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted) mostrarExito(context, 'PDF descargado.');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lista física'),
            Text(
              widget.sindicato.nombre,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _guardando ? null : _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<ListaFisicaSindicato>(
        futuro: _carga,
        alReintentar: _recargar,
        constructor: (context, lista) => ZonaSoltarArchivos(
          habilitada: !_guardando,
          permiteVarios: true,
          extensionesPermitidas: _extensionesListaFisica,
          mensaje: 'Soltá aquí las páginas de la lista física',
          alSoltar: _alSoltar,
          child: _contenido(lista),
        ),
      ),
    );
  }

  Widget _contenido(ListaFisicaSindicato lista) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(child: _encabezado(lista)),
              ),
              if (!lista.tienePaginas)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SinResultados(
                    icono: Icons.document_scanner_outlined,
                    mensaje: 'Todavía no hay páginas guardadas.',
                    detalle:
                        'Agregá varias fotografías en su orden. Se reducirán a menos de 300 KB manteniendo la lectura y se unirán en un PDF.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverLayoutBuilder(
                    builder: (context, restricciones) {
                      final columnas = restricciones.crossAxisExtent >= 1100
                          ? 4
                          : restricciones.crossAxisExtent >= 720
                          ? 3
                          : restricciones.crossAxisExtent >= 460
                          ? 2
                          : 1;
                      return SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnas,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .72,
                        ),
                        itemCount: lista.detallePaginas.length,
                        itemBuilder: (context, indice) =>
                            _tarjeta(lista.detallePaginas[indice]),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_guardando)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .7),
              child: const Cargando(mensaje: 'Actualizando el PDF…'),
            ),
          ),
      ],
    );
  }

  Widget _encabezado(ListaFisicaSindicato lista) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${lista.paginas} ${lista.paginas == 1 ? 'página' : 'páginas'}',
                  style: tema.textTheme.titleLarge,
                ),
                if (lista.actualizadaEn != null)
                  Text(
                    'Actualizado ${_fecha(lista.actualizadaEn!)}',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _guardando ? null : _elegirFotografias,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Agregar fotografías'),
                ),
                OutlinedButton.icon(
                  onPressed: _guardando ? null : _tomarFotografia,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Usar cámara'),
                ),
                if (lista.tienePaginas) ...[
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _verPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Ver PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _descargarPdf,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Descargar PDF'),
                  ),
                ],
              ],
            ),
            const AyudaArrastrarArchivo(
              texto: 'También podés arrastrar varias imágenes aquí.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(PaginaListaFisica pagina) {
    final tema = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: tema.colorScheme.surfaceContainerHighest,
              child: Image.network(
                ApiConfig.urlAbsoluta(pagina.url),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 44),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
            child: Row(
              children: [
                CircleAvatar(radius: 15, child: Text('${pagina.orden}')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pagina.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        pesoLegible(pagina.tamanoBytes),
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Reemplazar página',
                  onPressed: _guardando ? null : () => _reemplazar(pagina),
                  icon: const Icon(Icons.swap_horiz),
                ),
                IconButton(
                  tooltip: 'Quitar página',
                  onPressed: _guardando ? null : () => _quitar(pagina),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fecha(DateTime fecha) {
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }
}

class _VisorListaFisicaPdf extends StatelessWidget {
  const _VisorListaFisicaPdf({required this.sindicato, required this.descarga});

  final Sindicato sindicato;
  final Future<DescargaBinaria> descarga;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lista física · ${sindicato.nombre}')),
      body: FutureBuilder<DescargaBinaria>(
        future: descarga,
        builder: (context, estado) {
          if (estado.connectionState == ConnectionState.waiting) {
            return const Cargando(mensaje: 'Abriendo el PDF…');
          }
          if (estado.hasError) return FalloCarga(error: estado.error!);
          final archivo = estado.data!;
          return PdfPreview(
            build: (_) async => Uint8List.fromList(archivo.bytes),
            pdfFileName: archivo.nombreArchivo,
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            useActions: false,
          );
        },
      ),
    );
  }
}
