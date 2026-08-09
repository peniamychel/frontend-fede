import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'informe_importacion.dart';

/// Carga masiva del padrón desde una planilla de Excel.
///
/// Son dos pasos, igual que el endpoint: primero un análisis que no escribe
/// nada y devuelve exactamente lo que pasaría, y después la confirmación. El
/// backend corre el mismo código en ambos —en el análisis deshace la
/// transacción al final—, así que la vista previa no puede prometer algo
/// distinto de lo que hará la confirmación.
class ImportacionPagina extends StatefulWidget {
  const ImportacionPagina({super.key});

  @override
  State<ImportacionPagina> createState() => _ImportacionPaginaState();
}

class _ImportacionPaginaState extends State<ImportacionPagina> {
  late Future<List<Federacion>> _federaciones;

  Federacion? _federacion;
  PlatformFile? _archivo;

  ImportacionResultado? _informe;
  bool _trabajando = false;
  bool _crearJerarquia = true;
  bool _ignorarFilasConError = false;

  /// Queda en true cuando la confirmación terminó, para no importar dos veces
  /// con el mismo archivo por un doble clic.
  bool _yaImportado = false;

  @override
  void initState() {
    super.initState();
    _federaciones = PadronScope.of(context).federaciones.listar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar padrón')),
      body: CargaAsync<List<Federacion>>(
        futuro: _federaciones,
        alReintentar: () => setState(() {
          _federaciones = PadronScope.of(context).federaciones.listar();
        }),
        constructor: (context, federaciones) {
          _federacion ??= federaciones.length == 1 ? federaciones.first : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _paso1(context, federaciones),
                      const SizedBox(height: 16),
                      if (_informe != null) ...[
                        InformeImportacion(informe: _informe!),
                        const SizedBox(height: 16),
                        _paso2(context),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- Paso 1: elegir y analizar ----------

  Widget _paso1(BuildContext context, List<Federacion> federaciones) {
    final tema = Theme.of(context);
    final listo = _federacion != null && _archivo != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('1. Elegí el destino y la planilla',
                style: tema.textTheme.titleMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<Federacion>(
              initialValue: _federacion,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Federación destino',
                helperText: 'La planilla trae la central, pero no la federación.',
              ),
              items: [
                for (final f in federaciones)
                  DropdownMenuItem(value: f, child: Text(f.nombre)),
              ],
              onChanged: _trabajando
                  ? null
                  : (f) => setState(() {
                        _federacion = f;
                        _informe = null;
                      }),
            ),
            const SizedBox(height: 16),
            _selectorArchivo(context),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _trabajando ? null : _descargarPlantilla,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Descargar plantilla de ejemplo'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (!listo || _trabajando) ? null : _analizar,
              icon: _trabajando && _informe == null
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.fact_check_outlined),
              label: Text(_informe == null
                  ? 'Analizar sin importar'
                  : 'Volver a analizar'),
            ),
            const SizedBox(height: 8),
            Text(
              'El análisis no modifica nada: sirve para ver qué se importaría.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectorArchivo(BuildContext context) {
    final tema = Theme.of(context);
    final archivo = _archivo;

    return InkWell(
      onTap: _trabajando ? null : _elegirArchivo,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: archivo == null
                ? tema.colorScheme.outlineVariant
                : tema.colorScheme.primary,
          ),
          color: archivo == null ? null : tema.colorScheme.primaryContainer,
        ),
        child: Row(
          children: [
            Icon(
              archivo == null ? Icons.upload_file_outlined : Icons.description,
              color: archivo == null
                  ? tema.colorScheme.outline
                  : tema.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: archivo == null
                  ? Text('Elegir planilla .xlsx',
                      style: tema.textTheme.bodyLarge)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(archivo.name,
                            style: tema.textTheme.bodyLarge?.copyWith(
                              color: tema.colorScheme.onPrimaryContainer,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '${(archivo.size / 1024).toStringAsFixed(1)} KB',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
            ),
            if (archivo != null)
              TextButton(
                onPressed: _trabajando ? null : _elegirArchivo,
                child: const Text('Cambiar'),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Paso 2: decidir y confirmar ----------

  Widget _paso2(BuildContext context) {
    final tema = Theme.of(context);
    final informe = _informe!;

    if (!informe.simulacion) {
      // Ya se confirmó: no hay nada más que decidir.
      return Card(
        color: tema.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.check_circle,
                  color: tema.colorScheme.onPrimaryContainer),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Importación terminada: ${informe.productores} productores '
                  'quedaron cargados.',
                  style: tema.textTheme.titleSmall?.copyWith(
                    color: tema.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final puedeImportar = informe.hayAlgoQueImportar &&
        (!informe.hayRechazos || _ignorarFilasConError);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('2. Confirmá qué hacer', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _crearJerarquia,
              onChanged: _trabajando
                  ? null
                  : (v) {
                      setState(() => _crearJerarquia = v);
                      // Cambiar esto cambia qué filas son válidas, así que hay
                      // que rehacer el análisis: mostrar el anterior sería
                      // mostrar algo que ya no corresponde.
                      _analizar();
                    },
              title: const Text('Crear las centrales y sindicatos que falten'),
              subtitle: Text(
                _crearJerarquia
                    ? 'Se darán de alta los que aparecen arriba.'
                    : 'Las filas con jerarquía inexistente se rechazan.',
              ),
            ),
            if (informe.hayRechazos)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _ignorarFilasConError,
                onChanged: _trabajando
                    ? null
                    : (v) => setState(() => _ignorarFilasConError = v),
                title: Text('Importar igual las ${informe.filasValidas} filas '
                    'válidas'),
                subtitle: Text(
                  _ignorarFilasConError
                      ? 'Las ${informe.filasRechazadas} rechazadas quedan afuera.'
                      : 'Con una sola fila inválida no se importa nada.',
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  (!puedeImportar || _trabajando || _yaImportado) ? null : _confirmar,
              style: FilledButton.styleFrom(
                backgroundColor: tema.colorScheme.primary,
              ),
              icon: _trabajando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text('Importar ${informe.filasValidas} productores'),
            ),
            if (!puedeImportar) ...[
              const SizedBox(height: 8),
              Text(
                informe.hayAlgoQueImportar
                    ? 'Hay filas con errores. Corregí la planilla, o activá el '
                        'interruptor de arriba para importar solo las válidas.'
                    : 'Ninguna fila de la planilla se puede importar.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Acciones ----------

  Future<void> _elegirArchivo() async {
    try {
      // En file_picker 11 los métodos son estáticos: el `FilePicker.platform`
      // de las versiones anteriores ya no existe.
      final resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        // Hace falta en web, donde no hay ruta de archivo, y unifica el
        // tratamiento en las tres plataformas.
        withData: true,
      );
      final elegido = resultado?.files.firstOrNull;
      if (elegido == null || !mounted) return;

      setState(() {
        _archivo = elegido;
        _informe = null;
        _yaImportado = false;
      });
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  /// Abre la URL de la plantilla en vez de bajarla con el cliente HTTP: el
  /// backend la marca como adjunto y el navegador la guarda solo, sin que haya
  /// que decidir una carpeta de destino en cada plataforma.
  Future<void> _descargarPlantilla() async {
    final url = PadronScope.of(context).importaciones.urlPlantilla;
    try {
      final abierta = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!abierta && mounted) {
        mostrarAviso(context, 'No se pudo abrir la descarga: $url');
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _analizar() => _enviar(simular: true);

  Future<void> _confirmar() async {
    final informe = _informe;
    if (informe == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Importar al padrón?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se van a crear ${informe.productores} productores, '
                '${informe.lotes} lotes y ${informe.observaciones} '
                'observaciones en ${informe.federacionNombre}.'),
            if (informe.tocaLaJerarquia) ...[
              const SizedBox(height: 12),
              Text('Además, ${informe.centralesNuevas.length} central(es) y '
                  '${informe.sindicatosNuevos.length} sindicato(s) nuevos.'),
            ],
            if (informe.posiblesDuplicados > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${informe.posiblesDuplicados} fila(s) coinciden con '
                'productores que ya existen. Puede que esta planilla ya se '
                'haya cargado antes.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirmado == true) await _enviar(simular: false);
  }

  Future<void> _enviar({required bool simular}) async {
    final archivo = _archivo;
    final federacion = _federacion;
    final bytes = archivo?.bytes;

    if (archivo == null || federacion == null || bytes == null) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo leer el archivo. Elegilo de nuevo.');
      }
      return;
    }

    setState(() => _trabajando = true);

    try {
      final informe = await PadronScope.of(context).importaciones.importar(
            bytes: bytes,
            nombreArchivo: archivo.name,
            federacionId: federacion.id,
            simular: simular,
            crearJerarquia: _crearJerarquia,
            ignorarFilasConError: _ignorarFilasConError,
          );
      if (!mounted) return;
      setState(() {
        _informe = informe;
        _trabajando = false;
        // `simulacion` viene en true también cuando la ejecución real se
        // aborta por filas inválidas, así que hay que mirar las dos cosas.
        _yaImportado = !simular && !informe.simulacion;
      });
      if (_yaImportado && mounted) {
        mostrarExito(
          context,
          'Importación completada',
          detalle: '${informe.productores} productores, ${informe.lotes} lotes '
              'y ${informe.observaciones} observaciones '
              'en ${informe.duracionMs} ms.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _trabajando = false);
      mostrarError(context, e);
    }
  }
}
