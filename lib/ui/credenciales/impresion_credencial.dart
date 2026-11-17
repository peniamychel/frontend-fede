import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart';
import '../../models/lado_credencial.dart';
import '../widgets/estados.dart';

typedef CargarLadoCredencial =
    Future<DescargaBinaria> Function(LadoCredencial lado);
typedef RegistrarAnversoImpreso = Future<void> Function();

/// El controlador de Windows no informa un porcentaje de envío.
/// Mantiene visible la espera y bloquea nuevas acciones hasta que responda.
Future<T> ejecutarConProgresoImpresion<T>(
  BuildContext context, {
  required String mensaje,
  required Future<T> Function() accion,
}) async {
  final navegador = Navigator.of(context, rootNavigator: true);
  final ruta = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Impresión en proceso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 20),
            Text(mensaje),
            const SizedBox(height: 12),
            const Text(
              'Esperá a que termine el envío. No vuelvas a imprimir este trabajo.',
            ),
          ],
        ),
      ),
    ),
  );
  unawaited(navegador.push(ruta));
  try {
    await WidgetsBinding.instance.endOfFrame;
    return await accion();
  } finally {
    if (ruta.isActive) navegador.removeRoute(ruta);
  }
}

/// Una sola tarjeta de muestra; la cantidad corresponde al trabajo a imprimir,
/// no al número de imágenes que debe cargar la vista previa.
Future<bool> confirmarVistaPreviaReverso(
  BuildContext context,
  DescargaBinaria descarga, {
  int cantidad = 1,
}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _VistaPreviaImpresionReverso(
          descarga: descarga,
          cantidad: cantidad,
        ),
      ),
    ) ??
    false;

class _VistaPreviaImpresionReverso extends StatelessWidget {
  const _VistaPreviaImpresionReverso({
    required this.descarga,
    required this.cantidad,
  });

  final DescargaBinaria descarga;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final bytes = Uint8List.fromList(descarga.bytes);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa de impresión del reverso'),
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        pages: const [0],
        maxPageWidth: 400,
        initialPageFormat: const PdfPageFormat(
          85.6 * PdfPageFormat.mm,
          53.98 * PdfPageFormat.mm,
          marginAll: 0,
        ),
        // La resolución del PDF no depende del ancho de la muestra en pantalla.
        // El cálculo automático usa A4 por defecto y reduce demasiado el carnet.
        dpi: 600,
        pdfFileName: descarga.nombreArchivo,
        allowPrinting: false,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        useActions: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Cantidad a imprimir: $cantidad ${cantidad == 1 ? 'reverso' : 'reversos'}',
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimir reverso'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La impresión física se ofrece solo en el ejecutable de Windows.
@visibleForTesting
bool? debugImpresionDeCredencialesDisponible;

bool get impresionDeCredencialesDisponible =>
    debugImpresionDeCredencialesDisponible ??
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

String? get nombreImpresoraCredencialesSeleccionada =>
    _ImpresionWindows.impresoraSeleccionada?.name;

/// Abre el mismo selector usado por la impresión individual.
Future<void> cambiarImpresoraCredencialesWindows(BuildContext context) async {
  if (!impresionDeCredencialesDisponible) {
    throw StateError('La impresión física solo está disponible en Windows.');
  }
  await _ImpresionWindows.seleccionar(context, forzar: true);
}

/// Envía un PDF CR80 de una o varias páginas al controlador de Windows.
/// Cada página representa una tarjeta física en la Zebra.
Future<bool> imprimirTrabajoCredencialesWindows(
  BuildContext context,
  DescargaBinaria descarga,
) {
  if (!impresionDeCredencialesDisponible) {
    throw StateError('La impresión física solo está disponible en Windows.');
  }
  return _ImpresionWindows.imprimir(context, descarga, vertical: false);
}

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
    this.alAnversoImpreso,
    this.vertical = false,
  });

  final bool habilitada;
  final String nombre;
  final CargarLadoCredencial cargar;
  final RegistrarAnversoImpreso? alAnversoImpreso;
  final bool vertical;

  @override
  State<PanelImpresionCredencial> createState() =>
      _PanelImpresionCredencialState();
}

class _PanelImpresionCredencialState extends State<PanelImpresionCredencial> {
  bool _imprimiendo = false;
  bool _anversoEnviado = false;
  bool _anversoPendienteDeRegistro = false;

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
              label: Text(
                _anversoPendienteDeRegistro
                    ? 'Registrar anverso ya enviado'
                    : '1. Imprimir anverso',
              ),
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
    if (_imprimiendo || !widget.habilitada) return;
    // Bloquear desde el primer clic, incluso mientras se espera la decisión.
    setState(() => _imprimiendo = true);
    try {
      if (lado == LadoCredencial.anverso &&
          _anversoPendienteDeRegistro &&
          widget.alAnversoImpreso != null) {
        await widget.alAnversoImpreso!();
        _anversoPendienteDeRegistro = false;
        if (!mounted) return;
        mostrarExito(context, 'La impresión anterior quedó registrada.');
        return;
      }
      final confirmado = await _confirmarImpresion(lado);
      if (!confirmado || !mounted) return;
      final descarga = lado == LadoCredencial.reverso
          ? await ejecutarConProgresoImpresion(
              context,
              mensaje: 'Preparando el reverso para la vista previa…',
              accion: () => widget.cargar(lado),
            )
          : await widget.cargar(lado);
      if (!mounted) return;
      if (lado == LadoCredencial.reverso) {
        final confirmado = await confirmarVistaPreviaReverso(context, descarga);
        if (!confirmado || !mounted) return;
      }
      final enviada = await _ImpresionWindows.imprimir(
        context,
        descarga,
        vertical: widget.vertical,
      );
      if (!mounted) return;
      if (enviada) {
        if (lado == LadoCredencial.anverso) {
          _anversoEnviado = true;
          if (widget.alAnversoImpreso != null) {
            // Desde acá el trabajo ya fue aceptado por Windows. Si falla el
            // registro, el próximo clic reintenta solo el registro y no vuelve
            // a imprimir físicamente la tarjeta.
            _anversoPendienteDeRegistro = true;
            await widget.alAnversoImpreso!();
            _anversoPendienteDeRegistro = false;
            if (!mounted) return;
          }
        }
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

  Future<bool> _confirmarImpresion(LadoCredencial lado) async {
    final reverso = lado == LadoCredencial.reverso;
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(
          '¿Imprimir ${reverso ? 'el reverso' : 'la cara'} del carnet?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Se enviará una impresión ${reverso ? 'del reverso' : 'de la cara'} '
              'a la impresora. Confirmá solo si querés imprimir este carnet.',
            ),
            if (reverso) ...[
              const SizedBox(height: 12),
              Text(
                '${_anversoEnviado ? 'La cara ya fue enviada. ' : ''}'
                'Retirá la tarjeta de la Zebra y volvé a introducirla con la cara '
                'sin imprimir en la posición indicada por tu modelo. '
                'La dirección del giro depende de la Zebra; hacé la primera '
                'calibración con una tarjeta de prueba.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(reverso ? 'Imprimir reverso' : 'Imprimir cara'),
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
    if (!context.mounted) return false;
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

    return ejecutarConProgresoImpresion<bool>(
      context,
      mensaje:
          'Enviando el trabajo a ${impresora?.name ?? 'la impresora'}… '
          'Si son muchas tarjetas, Windows puede tardar en procesarlas antes de empezar a imprimir.',
      accion: () async {
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
      },
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
