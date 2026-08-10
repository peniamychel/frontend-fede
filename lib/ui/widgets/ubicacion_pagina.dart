import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mapas_config.dart';
import 'estados.dart';

/// Marca en el mapa dónde está algo: la sede de un sindicato, una parcela.
///
/// Hay dos formas de fijar el punto y las dos están siempre disponibles: tocar
/// el mapa, o escribir las coordenadas. La segunda no es un parche por si falla
/// la primera — es lo que hace que la función sirva sin clave de Google, con
/// coordenadas leídas de un GPS, o cuando alguien las dicta por teléfono.
class UbicacionPagina extends StatefulWidget {
  const UbicacionPagina({
    super.key,
    required this.titulo,
    required this.queEs,
    required this.latitud,
    required this.longitud,
    required this.alGuardar,
    required this.alBorrar,
    this.subtitulo,
    this.ubicacionActualizadaEn,
  });

  /// Nombre de lo que se ubica: el sindicato o el lote.
  final String titulo;

  /// Línea de contexto bajo el título.
  final String? subtitulo;

  /// Qué es el punto, para los textos: «la sede», «la parcela».
  final String queEs;

  final double? latitud;
  final double? longitud;
  final DateTime? ubicacionActualizadaEn;

  final Future<void> Function(double latitud, double longitud) alGuardar;
  final Future<void> Function() alBorrar;

  bool get tieneUbicacion => latitud != null && longitud != null;

  String get coordenadas => tieneUbicacion
      ? '${latitud!.toStringAsFixed(6)}, ${longitud!.toStringAsFixed(6)}'
      : 'Sin ubicación';

  @override
  State<UbicacionPagina> createState() =>
      _UbicacionPaginaState();
}

class _UbicacionPaginaState extends State<UbicacionPagina> {
  late final TextEditingController _latitud;
  late final TextEditingController _longitud;

  GoogleMapController? _mapa;
  LatLng? _punto;
  bool _guardando = false;

  /// Queda en true si se guardó o se borró, para que la jerarquía se recargue.
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    final w = widget;
    _punto = w.tieneUbicacion ? LatLng(w.latitud!, w.longitud!) : null;
    _latitud = TextEditingController(
        text: w.latitud?.toStringAsFixed(7) ?? '');
    _longitud = TextEditingController(
        text: w.longitud?.toStringAsFixed(7) ?? '');
  }

  @override
  void dispose() {
    _latitud.dispose();
    _longitud.dispose();
    _mapa?.dispose();
    super.dispose();
  }

  LatLng get _centro =>
      _punto ??
      const LatLng(MapasConfig.latitudPorDefecto,
          MapasConfig.longitudPorDefecto);

  /// Mueve el punto desde el mapa y refleja el cambio en los campos de texto,
  /// para que las dos formas de editar muestren siempre lo mismo.
  void _moverA(LatLng destino, {bool moverCamara = false}) {
    setState(() {
      _punto = destino;
      _latitud.text = destino.latitude.toStringAsFixed(7);
      _longitud.text = destino.longitude.toStringAsFixed(7);
    });
    if (moverCamara) {
      _mapa?.animateCamera(CameraUpdate.newLatLng(destino));
    }
  }

  /// Toma lo escrito en los campos y lo lleva al mapa. Devuelve null si el
  /// texto no es un par de coordenadas válido.
  LatLng? _leerCampos({bool avisar = true}) {
    final lat = double.tryParse(_latitud.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_longitud.text.trim().replaceAll(',', '.'));

    if (lat == null || lon == null) {
      if (avisar) {
        mostrarAviso(context, 'Escribí las dos coordenadas en números.');
      }
      return null;
    }
    if (lat < -90 || lat > 90) {
      if (avisar) mostrarAviso(context, 'La latitud va de -90 a 90.');
      return null;
    }
    if (lon < -180 || lon > 180) {
      if (avisar) mostrarAviso(context, 'La longitud va de -180 a 180.');
      return null;
    }
    return LatLng(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fueDescartado, _) {
        if (!fueDescartado) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ubicación de ${w.titulo}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (w.subtitulo != null)
                Text(w.subtitulo!,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (context, restricciones) {
            final ancho = restricciones.maxWidth >= 900;
            final mapa = _panelMapa(context);
            final panel = SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _panelDatos(context),
            );

            if (ancho) {
              return Row(
                children: [
                  Expanded(flex: 3, child: mapa),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 380, child: panel),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(height: 280, child: mapa),
                const Divider(height: 1),
                Expanded(child: panel),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- Mapa ----------

  Widget _panelMapa(BuildContext context) {
    if (!MapasConfig.hayClave) return _sinClave(context);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _centro, zoom: 15),
          onMapCreated: (c) => _mapa = c,
          // Híbrido y no el mapa de calles: en zona rural los caminos suelen no
          // estar trazados, y el satélite es lo único que permite reconocer
          // dónde está la sede.
          mapType: MapType.hybrid,
          onTap: (destino) => _moverA(destino),
          markers: {
            if (_punto != null)
              Marker(
                markerId: const MarkerId('sede'),
                position: _punto!,
                draggable: true,
                onDragEnd: (destino) => _moverA(destino),
                infoWindow: InfoWindow(title: widget.titulo),
              ),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Card(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Tocá el mapa para marcar ${widget.queEs}, '
                  'o arrastrá el pin'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sinClave(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      color: tema.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 44, color: tema.colorScheme.outline),
              const SizedBox(height: 12),
              Text('El mapa necesita una clave de Google Maps',
                  style: tema.textTheme.titleSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Mientras tanto podés cargar las coordenadas a mano: la '
                'ubicación se guarda igual.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SelectableText(
                'flutter run --dart-define=GOOGLE_MAPS_API_KEY=...',
                style: tema.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: tema.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Panel de datos ----------

  Widget _panelDatos(BuildContext context) {
    final tema = Theme.of(context);
    final hayPunto = _punto != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Coordenadas', style: tema.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'En grados decimales. Se actualizan solas al tocar el mapa, y podés '
          'escribirlas directamente si ya las tenés.',
          style: tema.textTheme.bodySmall
              ?.copyWith(color: tema.colorScheme.outline),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _campo(_latitud, 'Latitud', '-16.8574321')),
            const SizedBox(width: 12),
            Expanded(child: _campo(_longitud, 'Longitud', '-64.7891234')),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final destino = _leerCampos();
              if (destino != null) _moverA(destino, moverCamara: true);
            },
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('Llevar el mapa a estas coordenadas'),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: const Text('Guardar ubicación'),
        ),
        const SizedBox(height: 24),
        if (widget.tieneUbicacion) ...[
          const Divider(),
          const SizedBox(height: 8),
          Text('Ubicación guardada', style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(widget.coordenadas,
              style: tema.textTheme.bodyMedium),
          if (widget.ubicacionActualizadaEn != null)
            Text('Marcada el ${_fecha(widget.ubicacionActualizadaEn!)}',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline)),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _abrirEnGoogleMaps,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Abrir en Google Maps'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _guardando ? null : _borrar,
                icon: Icon(Icons.location_off_outlined,
                    size: 18, color: tema.colorScheme.error),
                label: Text('Quitar',
                    style: TextStyle(color: tema.colorScheme.error)),
              ),
            ],
          ),
        ] else if (!hayPunto)
          Text(
            'Todavía no se marcó ${widget.queEs}.',
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.outline),
          ),
      ],
    );
  }

  Widget _campo(TextEditingController controlador, String etiqueta, String ejemplo) {
    return TextField(
      controller: controlador,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      inputFormatters: [
        // Números con signo y decimales, nada más. Se admite la coma porque en
        // el teclado latinoamericano es lo que sale, y se convierte a punto al
        // leerla.
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,\-]')),
      ],
      decoration: InputDecoration(labelText: etiqueta, hintText: ejemplo),
    );
  }

  // ---------- Acciones ----------

  Future<void> _guardar() async {
    final destino = _leerCampos();
    if (destino == null) return;

    setState(() => _guardando = true);
    try {
      await widget.alGuardar(destino.latitude, destino.longitude);
      if (!mounted) return;
      _huboCambios = true;
      setState(() => _guardando = false);
      mostrarExito(context, 'Ubicación guardada',
          detalle: '${destino.latitude.toStringAsFixed(6)}, '
              '${destino.longitude.toStringAsFixed(6)}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarError(context, e);
    }
  }

  Future<void> _borrar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Quitar la ubicación?'),
        content: Text('${widget.titulo} deja de estar ubicado en el mapa. '
            'No se toca ningún otro dato.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await widget.alBorrar();
      if (!mounted) return;
      setState(() => _guardando = false);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarError(context, e);
    }
  }

  Future<void> _abrirEnGoogleMaps() async {
    final w = widget;
    if (!w.tieneUbicacion) return;
    // Esta URL es pública y no consume la clave de API.
    final url = MapasConfig.enlaceExterno(w.latitud!, w.longitud!);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  static String _fecha(DateTime d) {
    final l = d.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    return '$dd/$mm/${l.year}';
  }
}
