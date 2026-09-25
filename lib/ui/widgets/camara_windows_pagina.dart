import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _preferenciaUltimaCamaraWindows = 'ultima_camara_windows';

/// Interfaz de captura usada por la aplicación de escritorio en Windows.
///
/// `image_picker` no incluye una cámara en Windows, por lo que la captura se
/// realiza con el complemento `camera_windows` y devuelve el mismo [XFile]
/// que consumen los flujos de fotografía existentes.
class CamaraWindowsPagina extends StatefulWidget {
  const CamaraWindowsPagina({super.key});

  @override
  State<CamaraWindowsPagina> createState() => _CamaraWindowsPaginaState();
}

class _CamaraWindowsPaginaState extends State<CamaraWindowsPagina> {
  CameraController? _controlador;
  List<CameraDescription> _camaras = const [];
  int? _indiceCamara;
  Object? _error;
  bool _capturando = false;
  bool _cambiandoCamara = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        throw StateError('No se encontró ninguna cámara conectada.');
      }
      final preferencias = await SharedPreferences.getInstance();
      final ultimaCamara = preferencias.getString(
        _preferenciaUltimaCamaraWindows,
      );
      final indiceGuardado = ultimaCamara == null
          ? -1
          : camaras.indexWhere((camara) => camara.name == ultimaCamara);
      final indiceFrontal = camaras.indexWhere(
        (camara) => camara.lensDirection == CameraLensDirection.front,
      );
      _camaras = camaras;
      await _abrirCamara(
        indiceGuardado >= 0
            ? indiceGuardado
            : indiceFrontal < 0
            ? 0
            : indiceFrontal,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _abrirCamara(int indice) async {
    if (_cambiandoCamara || indice < 0 || indice >= _camaras.length) return;
    _cambiandoCamara = true;
    final anterior = _controlador;
    if (mounted) {
      setState(() {
        _controlador = null;
        _indiceCamara = indice;
        _error = null;
      });
      // La textura nativa debe desaparecer de la vista antes de liberar la
      // cámara. Si se dispone mientras Flutter aún la pinta, Windows puede
      // cerrar el proceso con una violación de acceso.
      await WidgetsBinding.instance.endOfFrame;
    }
    await anterior?.dispose();

    final controlador = CameraController(
      _camaras[indice],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controlador.initialize();
      if (!mounted) {
        await controlador.dispose();
        return;
      }
      setState(() => _controlador = controlador);
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString(
        _preferenciaUltimaCamaraWindows,
        _camaras[indice].name,
      );
    } catch (error) {
      await controlador.dispose();
      if (mounted) setState(() => _error = error);
    } finally {
      _cambiandoCamara = false;
    }
  }

  String _nombreCamara(CameraDescription camara, int indice) {
    final tipo = switch (camara.lensDirection) {
      CameraLensDirection.front => 'frontal',
      CameraLensDirection.back => 'trasera',
      CameraLensDirection.external => 'externa',
    };
    // En Windows el nombre suele terminar con la ruta técnica completa del
    // dispositivo (usb#vid_...). Para elegir una cámara basta con conservar
    // el nombre legible que aparece antes de esa ruta.
    final nombreLegible = camara.name.split(RegExp(r'\s*<\\\\\?')).first.trim();
    final nombre = nombreLegible.isEmpty
        ? 'Cámara ${indice + 1}'
        : nombreLegible;
    return '${indice + 1}. $nombre ($tipo)';
  }

  @override
  void dispose() {
    _controlador?.dispose();
    super.dispose();
  }

  Future<void> _capturar() async {
    final controlador = _controlador;
    if (controlador == null || _capturando) return;
    setState(() => _capturando = true);
    try {
      final archivo = await controlador.takePicture();
      if (!mounted) return;
      setState(() => _controlador = null);
      await WidgetsBinding.instance.endOfFrame;
      await controlador.dispose();
      if (mounted) Navigator.of(context).pop(archivo);
    } catch (error) {
      if (mounted) {
        setState(() {
          _capturando = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controlador = _controlador;
    return Scaffold(
      appBar: AppBar(title: const Text('Tomar fotografía')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No se pudo abrir la cámara.\n$_error\n\n'
                          'Revisá en Windows: Configuración > Privacidad y '
                          'seguridad > Cámara.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : controlador == null || !controlador.value.isInitialized
                    ? const CircularProgressIndicator()
                    : AspectRatio(
                        aspectRatio: controlador.value.aspectRatio,
                        child: CameraPreview(controlador),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_camaras.length > 1) ...[
                    Flexible(
                      child: DropdownButtonFormField<int>(
                        initialValue: _indiceCamara,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Cámara',
                          prefixIcon: Icon(Icons.videocam_outlined),
                        ),
                        items: [
                          for (var i = 0; i < _camaras.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                _nombreCamara(_camaras[i], i),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _capturando || _cambiandoCamara
                            ? null
                            : (indice) {
                                if (indice != null && indice != _indiceCamara) {
                                  _abrirCamara(indice);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  FilledButton.icon(
                    onPressed:
                        controlador == null || _capturando || _cambiandoCamara
                        ? null
                        : _capturar,
                    icon: _capturando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera),
                    label: const Text('Capturar fotografía'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<XFile?> abrirCamaraWindows(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<XFile>(MaterialPageRoute(builder: (_) => const CamaraWindowsPagina()));
}
