import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../models/imagen.dart';
import '../productores/recortador_imagen.dart';
import '../widgets/estados.dart';

/// Conserva transparencia y prepara un retrato cuadrado sin ampliar el original.
Uint8List prepararFotoOperador((Uint8List, Recorte) datos) {
  final decodificada = img.decodeImage(datos.$1);
  if (decodificada == null) {
    throw const FormatException('Seleccioná una fotografía PNG o JPG válida.');
  }
  final imagen = img.bakeOrientation(decodificada);
  final recorte = datos.$2;
  final x = recorte.x.clamp(0, imagen.width - 1);
  final y = recorte.y.clamp(0, imagen.height - 1);
  final lado = math.min(
    math.min(recorte.ancho, recorte.alto),
    math.min(imagen.width - x, imagen.height - y),
  );
  if (lado < 1) throw const FormatException('El recorte está vacío.');
  final cuadrada = img.copyCrop(imagen, x: x, y: y, width: lado, height: lado);
  final salida = lado > 600
      ? img.copyResize(
          cuadrada,
          width: 600,
          height: 600,
          interpolation: img.Interpolation.cubic,
        )
      : cuadrada;
  return Uint8List.fromList(img.encodePng(salida));
}

class FotoOperadorRecortePagina extends StatefulWidget {
  const FotoOperadorRecortePagina({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<FotoOperadorRecortePagina> createState() =>
      _FotoOperadorRecortePaginaState();
}

class _FotoOperadorRecortePaginaState extends State<FotoOperadorRecortePagina> {
  Recorte? _recorte;
  bool _preparando = false;
  bool _ajustando = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_preparando,
    child: Scaffold(
      appBar: AppBar(title: const Text('Encuadrar fotografía del operador')),
      body: SingleChildScrollView(
        physics: _ajustando ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                const Text(
                  'Ajustá el recorte alrededor del rostro. '
                  'El diseño puede mostrar esta foto dentro de un círculo.',
                ),
                const SizedBox(height: 20),
                RecortadorImagen(
                  bytes: widget.bytes,
                  proporcionFija: Proporcion.cuadrada,
                  alCambiar: (recorte) {
                    _recorte = recorte;
                  },
                  alCambiarInteraccion: (valor) =>
                      setState(() => _ajustando = valor),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _preparando ? null : () => Navigator.pop(context),
                child: const Text('Atrás'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _preparando ? null : _usarFoto,
                icon: _preparando
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_preparando ? 'Preparando…' : 'Usar fotografía'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _usarFoto() async {
    final recorte = _recorte;
    if (_preparando || recorte == null) return;
    setState(() => _preparando = true);
    try {
      final png = await compute(prepararFotoOperador, (widget.bytes, recorte));
      if (!mounted) return;
      setState(() => _preparando = false);
      Navigator.pop(context, png);
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _preparando = false);
    }
  }
}
