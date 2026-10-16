import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/guardar_archivo.dart';
import '../../repositories/padron.dart';
import '../credenciales/tarjeta_previa.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

class OperadorCredencialPreviaPagina extends StatefulWidget {
  const OperadorCredencialPreviaPagina({super.key, required this.operadorId});

  final int operadorId;

  @override
  State<OperadorCredencialPreviaPagina> createState() =>
      _OperadorCredencialPreviaPaginaState();
}

class _OperadorCredencialPreviaPaginaState
    extends State<OperadorCredencialPreviaPagina> {
  late Future<(OperadorCredencialPrevia, EditorDisenoCredencial)> _futuro;
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<(OperadorCredencialPrevia, EditorDisenoCredencial)> _cargar() async {
    final padron = PadronScope.of(context);
    final previa = await padron.credencialesOperadores.previa(
      widget.operadorId,
    );
    final editor = await padron.disenoCredencialOperador.obtener();
    return (previa, editor);
  }

  void _recargar() => setState(() {
    _futuro = _cargar();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vista previa de credencial de operador'),
      actions: [
        IconButton(
          tooltip: 'Actualizar vista previa',
          onPressed: _generando ? null : _recargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: CargaAsync<(OperadorCredencialPrevia, EditorDisenoCredencial)>(
      futuro: _futuro,
      alReintentar: _recargar,
      constructor: (context, datos) {
        final previa = datos.$1;
        final editor = datos.$2;
        final firmaLista = previa.ejecutivo?.firmaUrl != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    previa.operador.nombreCompleto,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, espacio) => Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: [
                        for (final reverso in [false, true])
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reverso ? 'Reverso' : 'Anverso'),
                              const SizedBox(height: 8),
                              TarjetaPrevia(
                                ancho: espacio.maxWidth.clamp(0.0, 420.0),
                                previa: previa.tarjeta,
                                reverso: reverso,
                                diseno: editor.diseno,
                                valores: previa.valores,
                                plantillaPorDefecto: false,
                                plantillaUrl: reverso
                                    ? editor.plantillaReversoUrl
                                    : editor.plantillaCaraUrl,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!firmaLista) ...[
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.warning_amber_outlined),
                      title: Text(
                        'Falta la firma del ejecutivo de la federación',
                      ),
                      subtitle: Text(
                        'Configurá un ejecutivo vigente y su firma en '
                        'Jerarquía → Directorio de la federación. '
                        'Se puede revisar el diseño, pero todavía no emitir el PDF.',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _generando || !firmaLista
                            ? null
                            : () => _pdf('COMPLETA'),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Credencial completa en PDF'),
                      ),
                      OutlinedButton(
                        onPressed: _generando || !firmaLista
                            ? null
                            : () => _pdf('ANVERSO'),
                        child: const Text('PDF del anverso'),
                      ),
                      OutlinedButton(
                        onPressed: _generando || !firmaLista
                            ? null
                            : () => _pdf('REVERSO'),
                        child: const Text('PDF del reverso'),
                      ),
                    ],
                  ),
                  if (_generando) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Generando la credencial…'),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _pdf(String cara) async {
    if (_generando) return;
    setState(() => _generando = true);
    try {
      final archivo = await PadronScope.of(
        context,
      ).credencialesOperadores.pdf(widget.operadorId, cara: cara);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _PdfOperadorPagina(
            bytes: Uint8List.fromList(archivo.bytes),
            nombre: archivo.nombreArchivo,
          ),
        ),
      );
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }
}

class _PdfOperadorPagina extends StatelessWidget {
  const _PdfOperadorPagina({required this.bytes, required this.nombre});

  final Uint8List bytes;
  final String nombre;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PDF de credencial de operador'),
      actions: [
        IconButton(
          tooltip: 'Descargar PDF',
          icon: const Icon(Icons.download_outlined),
          onPressed: () async {
            try {
              await guardarArchivo(bytes, nombre, 'application/pdf');
              if (context.mounted) {
                mostrarExito(context, 'PDF guardado');
              }
            } catch (error) {
              if (context.mounted) mostrarError(context, error);
            }
          },
        ),
      ],
    ),
    body: PdfPreview(
      build: (_) async => bytes,
      pdfFileName: nombre,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
    ),
  );
}
