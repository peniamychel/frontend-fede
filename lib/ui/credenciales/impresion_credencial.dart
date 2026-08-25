import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart';
import '../../models/lado_credencial.dart';
import '../widgets/estados.dart';

typedef CargarLadoCredencial =
    Future<DescargaBinaria> Function(LadoCredencial lado);

/// La impresión física se ofrece solo en el ejecutable de Windows.
@visibleForTesting
bool? debugImpresionDeCredencialesDisponible;

bool get impresionDeCredencialesDisponible =>
    debugImpresionDeCredencialesDisponible ??
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

/// Abre el flujo de impresión desde pantallas que no tienen una vista previa
/// propia, como el directorio de dirigentes.
Future<void> mostrarPanelImpresionCredencial(
  BuildContext context, {
  required String nombre,
  required CargarLadoCredencial cargar,
  bool vertical = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(nombre, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              PanelImpresionCredencial(
                habilitada: true,
                nombre: nombre,
                cargar: cargar,
                vertical: vertical,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Flujo para impresoras de tarjetas de una sola cara, como la Zebra disponible.
class PanelImpresionCredencial extends StatefulWidget {
  const PanelImpresionCredencial({
    super.key,
    required this.habilitada,
    required this.nombre,
    required this.cargar,
    this.vertical = false,
  });

  final bool habilitada;
  final String nombre;
  final CargarLadoCredencial cargar;
  final bool vertical;

  @override
  State<PanelImpresionCredencial> createState() =>
      _PanelImpresionCredencialState();
}

class _PanelImpresionCredencialState extends State<PanelImpresionCredencial> {
  bool _imprimiendo = false;
  bool _anversoEnviado = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (!impresionDeCredencialesDisponible) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.desktop_windows_outlined,
                color: tema.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Esta plataforma permite revisar la credencial. La impresión '
                  'física está disponible en la aplicación para Windows.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final impresora = _ImpresionWindows.impresoraSeleccionada;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.print_outlined, color: tema.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Impresión manual Zebra',
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              impresora == null
                  ? 'Seleccioná la impresora al enviar el anverso.'
                  : 'Impresora: ${impresora.name}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
            if (impresora != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _imprimiendo ? null : _cambiarImpresora,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Cambiar impresora'),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: widget.habilitada && !_imprimiendo
                  ? () => _imprimir(LadoCredencial.anverso)
                  : null,
              icon: _imprimiendo
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.looks_one_outlined),
              label: const Text('1. Imprimir anverso'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.habilitada && !_imprimiendo
                  ? () => _imprimir(LadoCredencial.reverso)
                  : null,
              icon: const Icon(Icons.flip_outlined),
              label: Text(
                _anversoEnviado
                    ? '2. Tarjeta volteada: imprimir reverso'
                    : '2. Imprimir reverso',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cada botón envía una sola página CR80 al controlador de Windows. '
              'La escala debe quedar en 100 % y sin ajustar al papel.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarImpresora() async {
    await _ImpresionWindows.seleccionar(context, forzar: true);
    if (mounted) setState(() {});
  }

  Future<void> _imprimir(LadoCredencial lado) async {
    if (lado == LadoCredencial.reverso && !await _confirmarReverso()) return;

    setState(() => _imprimiendo = true);
    try {
      final descarga = await widget.cargar(lado);
      if (!mounted) return;
      final enviada = await _ImpresionWindows.imprimir(
        context,
        descarga,
        vertical: widget.vertical,
      );
      if (!mounted) return;
      if (enviada) {
        if (lado == LadoCredencial.anverso) _anversoEnviado = true;
        mostrarExito(
          context,
          '${lado.etiqueta[0].toUpperCase()}${lado.etiqueta.substring(1)} '
          'enviado a la impresora.',
        );
      } else {
        mostrarAviso(context, 'La impresión fue cancelada.');
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  Future<bool> _confirmarReverso() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.flip_outlined),
        title: const Text('Preparar el reverso'),
        content: Text(
          '${_anversoEnviado ? 'El anverso ya fue enviado. ' : ''}'
          'Retirá la tarjeta de la Zebra y volvé a introducirla con la cara '
          'sin imprimir en la posición de impresión indicada por tu modelo. '
          'La dirección exacta del giro depende de la Zebra; hacé la primera '
          'calibración con una tarjeta de prueba.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tarjeta reinsertada'),
          ),
        ],
      ),
    );
    return confirmado == true;
  }
}

class _ImpresionWindows {
  const _ImpresionWindows._();

  static Printer? impresoraSeleccionada;

  static Future<Printer?> seleccionar(
    BuildContext context, {
    bool forzar = false,
  }) async {
    final info = await Printing.info();
    if (!info.canPrint) {
      throw StateError('Windows no tiene disponible el servicio de impresión.');
    }

    if (!info.canListPrinters) return null;
    final impresoras =
        (await Printing.listPrinters())
            .where((p) => p.isAvailable)
            .toList(growable: false)
          ..sort(_compararImpresoras);
    if (impresoras.isEmpty) {
      throw StateError(
        'Windows no encontró impresoras disponibles. Instalá primero el '
        'controlador oficial de la Zebra.',
      );
    }

    if (!forzar && impresoraSeleccionada != null) {
      final vigente = impresoras.where(
        (p) => p.url == impresoraSeleccionada!.url,
      );
      if (vigente.isNotEmpty) {
        impresoraSeleccionada = vigente.first;
        return impresoraSeleccionada;
      }
    }

    if (!context.mounted) return null;
    final elegida = await showDialog<Printer>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Seleccionar impresora'),
        children: [
          for (final impresora in impresoras)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(impresora),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _esZebra(impresora)
                      ? Icons.badge_outlined
                      : Icons.print_outlined,
                ),
                title: Text(impresora.name),
                subtitle: Text(
                  [
                    if (_esZebra(impresora)) 'Zebra',
                    if (impresora.isDefault) 'Predeterminada',
                    if (impresora.model?.isNotEmpty == true) impresora.model!,
                  ].join(' · '),
                ),
              ),
            ),
        ],
      ),
    );
    if (elegida != null) impresoraSeleccionada = elegida;
    return elegida;
  }

  static Future<bool> imprimir(
    BuildContext context,
    DescargaBinaria descarga, {
    required bool vertical,
  }) async {
    final impresora = await seleccionar(context);
    final bytes = Uint8List.fromList(descarga.bytes);
    final formato = vertical
        ? const PdfPageFormat(
            53.98 * PdfPageFormat.mm,
            85.6 * PdfPageFormat.mm,
            marginAll: 0,
          )
        : const PdfPageFormat(
            85.6 * PdfPageFormat.mm,
            53.98 * PdfPageFormat.mm,
            marginAll: 0,
          );

    if (impresora == null) {
      return Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: descarga.nombreArchivo,
        format: formato,
        dynamicLayout: false,
        usePrinterSettings: true,
        windowsModernDialog: true,
      );
    }

    return Printing.directPrintPdf(
      printer: impresora,
      onLayout: (_) => bytes,
      name: descarga.nombreArchivo,
      format: formato,
      dynamicLayout: false,
      usePrinterSettings: true,
      windowsModernDialog: true,
    );
  }

  static int _compararImpresoras(Printer a, Printer b) {
    final prioridad = _prioridad(a).compareTo(_prioridad(b));
    return prioridad != 0 ? prioridad : a.name.compareTo(b.name);
  }

  static int _prioridad(Printer impresora) {
    if (_esZebra(impresora)) return 0;
    if (impresora.isDefault) return 1;
    return 2;
  }

  static bool _esZebra(Printer impresora) =>
      '${impresora.name} ${impresora.model ?? ''}'.toLowerCase().contains(
        'zebra',
      );
}
