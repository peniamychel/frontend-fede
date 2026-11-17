import '../imagen_autenticada.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import '../widgets/camara_windows_pagina.dart';
import 'foto_operador_recorte_pagina.dart';

class OperadorFormularioPagina extends StatefulWidget {
  const OperadorFormularioPagina({
    super.key,
    this.operador,
    this.selectorImagenes,
  });

  final OperadorCredencial? operador;
  final ImagePicker? selectorImagenes;

  @override
  State<OperadorFormularioPagina> createState() =>
      _OperadorFormularioPaginaState();
}

class _OperadorFormularioPaginaState extends State<OperadorFormularioPagina> {
  final _formulario = GlobalKey<FormState>();
  late final _nombres = TextEditingController(text: widget.operador?.nombres);
  late final _apellidos = TextEditingController(
    text: widget.operador?.apellidos,
  );
  late final _ci = TextEditingController(text: widget.operador?.ci);
  late final _cargo = TextEditingController(text: widget.operador?.cargo);
  late final _telefono = TextEditingController(text: widget.operador?.telefono);
  bool _guardando = false;
  bool _seleccionandoFoto = false;
  late int _operadorId = widget.operador?.id ?? 0;
  late String? _fotoUrl = widget.operador?.fotoUrl;
  Uint8List? _fotoPendiente;
  bool _quitarFoto = false;
  bool _falloFoto = false;

  bool get _ocupado => _guardando || _seleccionandoFoto;

  @override
  void dispose() {
    for (final controlador in [_nombres, _apellidos, _ci, _cargo, _telefono]) {
      controlador.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.operador == null ? 'Nuevo operador' : 'Editar operador',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formulario,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Datos para la credencial del personal operador. '
                    'Este registro no crea una cuenta de acceso al sistema.',
                  ),
                  const SizedBox(height: 24),
                  _campo('Nombres', _nombres, 60, autofocus: true),
                  _campo('Apellidos', _apellidos, 60),
                  _campo('Cédula de identidad', _ci, 20),
                  _campo('Cargo', _cargo, 100),
                  _campo(
                    'Teléfono',
                    _telefono,
                    30,
                    teclado: TextInputType.phone,
                    ultimo: true,
                  ),
                  _fotografia(context),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: FilledButton.icon(
            onPressed: _ocupado ? null : _guardar,
            icon: _guardando
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _guardando
                  ? 'Guardando…'
                  : _falloFoto
                  ? 'Reintentar guardar fotografía'
                  : 'Guardar',
            ),
          ),
        ),
      ),
    ),
  );

  Widget _campo(
    String etiqueta,
    TextEditingController controlador,
    int longitud, {
    bool autofocus = false,
    bool ultimo = false,
    TextInputType? teclado,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controlador,
      enabled: !_ocupado,
      autofocus: autofocus,
      maxLength: longitud,
      keyboardType: teclado,
      textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(labelText: etiqueta),
      validator: (valor) =>
          valor == null || valor.trim().isEmpty ? 'Completá este campo' : null,
      onFieldSubmitted: ultimo ? (_) => _guardar() : null,
    ),
  );

  Widget _fotografia(BuildContext context) {
    final pendiente = _fotoPendiente;
    final url = _quitarFoto ? null : _fotoUrl;
    final tieneFoto = pendiente != null || url != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotografía', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ClipOval(
          child: Container(
            width: 144,
            height: 144,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: pendiente != null
                ? Image.memory(pendiente, fit: BoxFit.cover)
                : url != null
                ? ImagenAutenticada(
                    ApiConfig.urlAbsoluta(url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 48),
                  )
                : const Icon(Icons.person_outline, size: 64),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _ocupado ? null : _elegirFoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(tieneFoto ? 'Reemplazar foto' : 'Subir foto'),
            ),
            if (tieneFoto)
              TextButton.icon(
                onPressed: _ocupado ? null : _editarFoto,
                icon: const Icon(Icons.crop),
                label: const Text('Encuadrar foto'),
              ),
            if (tieneFoto)
              TextButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => setState(() {
                        _fotoPendiente = null;
                        _quitarFoto = true;
                        _falloFoto = false;
                      }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Quitar foto'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          pendiente != null
              ? 'Fotografía preparada. Se subirá al guardar.'
              : _quitarFoto && _fotoUrl != null
              ? 'La fotografía se quitará al guardar.'
              : 'Podés seleccionar una imagen PNG o JPG o usar la cámara.',
        ),
        if (_seleccionandoFoto) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_falloFoto) ...[
          const SizedBox(height: 12),
          Text(
            'Los datos del operador quedaron guardados, pero no se confirmó '
            'el cambio de fotografía. La imagen se conserva para reintentar.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;
    setState(() => _seleccionandoFoto = true);
    try {
      final esCamaraWindows =
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.windows &&
          origen == ImageSource.camera;
      final archivo = esCamaraWindows
          ? await abrirCamaraWindows(context)
          : await (widget.selectorImagenes ?? ImagePicker()).pickImage(
              source: origen,
              requestFullMetadata: false,
            );
      if (archivo == null || !mounted) return;
      final bytes = await archivo.readAsBytes();
      if (!mounted) return;
      await _encuadrar(bytes);
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _seleccionandoFoto = false);
    }
  }

  Future<void> _editarFoto() async {
    if (_ocupado) return;
    setState(() => _seleccionandoFoto = true);
    try {
      final bytes =
          _fotoPendiente ??
          Uint8List.fromList(
            (await PadronScope.of(
              context,
            ).credencialesOperadores.descargarFoto(_operadorId)).bytes,
          );
      if (!mounted) return;
      await _encuadrar(bytes);
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _seleccionandoFoto = false);
    }
  }

  Future<void> _encuadrar(Uint8List bytes) async {
    final recortada = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => FotoOperadorRecortePagina(bytes: bytes),
      ),
    );
    if (recortada != null && mounted) {
      setState(() {
        _fotoPendiente = recortada;
        _quitarFoto = false;
        _falloFoto = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (_ocupado || !_formulario.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final repositorio = PadronScope.of(context).credencialesOperadores;
      var guardado = await repositorio.guardar(
        OperadorCredencial(
          id: _operadorId,
          nombres: _nombres.text,
          apellidos: _apellidos.text,
          ci: _ci.text,
          cargo: _cargo.text,
          telefono: _telefono.text,
        ),
      );
      // Un fallo de red al subir la foto no debe crear otro operador al reintentar.
      _operadorId = guardado.id;
      _fotoUrl = guardado.fotoUrl;
      _falloFoto = false;
      try {
        if (_fotoPendiente != null) {
          guardado = await repositorio.subirFoto(
            _operadorId,
            bytes: _fotoPendiente!,
          );
        } else if (_quitarFoto && _fotoUrl != null) {
          guardado = await repositorio.quitarFoto(_operadorId);
        }
      } catch (_) {
        _falloFoto = true;
        rethrow;
      }
      if (!mounted) return;
      setState(() => _guardando = false);
      Navigator.of(context).pop(guardado);
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}
