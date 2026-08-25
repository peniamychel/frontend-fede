import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/fondo_ia.dart';
import '../../models/imagen.dart';
import '../productores/recortador_imagen.dart';

enum ClaseImagenDirectorio {
  firma(
    etiqueta: 'firma',
    titulo: 'Preparar firma',
    instruccion: 'Recortá alrededor de los trazos de la firma.',
    ladoMaximo: 600,
    pesoMaximo: 200 * 1024,
  ),
  pieFirma(
    etiqueta: 'pie de firma',
    titulo: 'Preparar pie de firma',
    instruccion: 'Recortá alrededor del nombre, cargo y organización.',
    ladoMaximo: 600,
    pesoMaximo: 200 * 1024,
  ),
  sello(
    etiqueta: 'sello',
    titulo: 'Preparar sello',
    instruccion: 'Recortá alrededor del sello institucional.',
    ladoMaximo: 600,
    pesoMaximo: 500 * 1024,
  );

  const ClaseImagenDirectorio({
    required this.etiqueta,
    required this.titulo,
    required this.instruccion,
    required this.ladoMaximo,
    required this.pesoMaximo,
  });

  final String etiqueta;
  final String titulo;
  final String instruccion;
  final int ladoMaximo;
  final int pesoMaximo;
}

class ImagenDirectorioPreparada {
  const ImagenDirectorioPreparada({
    required this.bytes,
    required this.nombreArchivo,
  });

  final Uint8List bytes;
  final String nombreArchivo;
}

Future<ImagenDirectorioPreparada?> prepararImagenDirectorio(
  BuildContext context, {
  required PlatformFile archivo,
  required ClaseImagenDirectorio clase,
}) => showDialog<ImagenDirectorioPreparada>(
  context: context,
  builder: (context) =>
      PrepararImagenDirectorioDialogo(archivo: archivo, clase: clase),
);

/// Recorta una firma, pie de firma o sello y elimina el fondo del papel.
///
/// La vista previa se genera en el navegador. El archivo solo se sube después
/// de que la persona confirma el resultado, siempre como PNG con canal alfa.
class PrepararImagenDirectorioDialogo extends StatefulWidget {
  const PrepararImagenDirectorioDialogo({
    super.key,
    required this.archivo,
    required this.clase,
  });

  final PlatformFile archivo;
  final ClaseImagenDirectorio clase;

  @override
  State<PrepararImagenDirectorioDialogo> createState() =>
      _PrepararImagenDirectorioDialogoState();
}

class _PrepararImagenDirectorioDialogoState
    extends State<PrepararImagenDirectorioDialogo> {
  Recorte? _recorte;
  Uint8List? _preparada;
  bool _quitarFondo = true;
  bool _procesando = false;
  double _intensidad = 0.55;
  String? _error;

  Uint8List get _original => Uint8List.fromList(widget.archivo.bytes!);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(widget.clase.titulo),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.clase.instruccion} El archivo final será PNG y '
                'mantendrá la proporción elegida.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              RecortadorImagen(
                bytes: _original,
                alCambiar: (recorte) {
                  if (!mounted) return;
                  setState(() {
                    _recorte = recorte;
                    _preparada = null;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _quitarFondo,
                onChanged: _procesando
                    ? null
                    : (valor) => setState(() {
                        _quitarFondo = valor;
                        _preparada = null;
                        _error = null;
                      }),
                title: const Text('Quitar fondo claro'),
                subtitle: const Text(
                  'Detecta el color del papel en las esquinas y lo vuelve transparente.',
                ),
              ),
              if (_quitarFondo) ...[
                Text(
                  'Cantidad de fondo a eliminar',
                  style: tema.textTheme.labelMedium,
                ),
                Row(
                  children: [
                    const Text('Menos'),
                    Expanded(
                      child: Slider(
                        value: _intensidad,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label: '${(_intensidad * 100).round()} %',
                        onChanged: _procesando
                            ? null
                            : (valor) => setState(() {
                                _intensidad = valor;
                                _preparada = null;
                                _error = null;
                              }),
                      ),
                    ),
                    const Text('Más'),
                  ],
                ),
              ],
              if (_preparada != null) ...[
                const SizedBox(height: 8),
                Text('Vista previa', style: tema.textTheme.labelLarge),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 280,
                      maxHeight: 180,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: tema.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(
                            painter: _CuadriculaTransparencia(),
                          ),
                        ),
                        Image.memory(_preparada!, fit: BoxFit.contain),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'PNG${_quitarFondo ? ' transparente' : ''} · '
                  '${pesoLegible(_preparada!.length)}',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.outline,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tema.colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tema.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'La preparación se realiza localmente. Revisá la cuadrícula: '
                  'las zonas donde se ve representan transparencia.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _procesando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: _procesando ? null : _preparar,
          icon: _procesando
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: Text(_procesando ? 'Procesando…' : 'Preparar vista previa'),
        ),
        FilledButton(
          onPressed: _preparada == null || _procesando
              ? null
              : () => Navigator.of(context).pop(
                  ImagenDirectorioPreparada(
                    bytes: _preparada!,
                    nombreArchivo: _nombrePng(),
                  ),
                ),
          child: const Text('Subir PNG'),
        ),
      ],
    );
  }

  Future<void> _preparar() async {
    final recorte = _recorte;
    if (recorte == null) {
      setState(() => _error = 'Esperá a que cargue la imagen.');
      return;
    }
    if (!fondoDocumentoDisponible) {
      setState(
        () => _error =
            'La preparación transparente está disponible en la versión web/Electron.',
      );
      return;
    }

    setState(() {
      _procesando = true;
      _preparada = null;
      _error = null;
    });
    try {
      final resultado = await prepararDocumentoSinFondo(
        bytes: _original,
        recorte: recorte,
        quitarFondo: _quitarFondo,
        tipoMime: _tipoMime(),
        intensidad: _intensidad,
        ladoMaximo: widget.clase.ladoMaximo,
        pesoMaximo: widget.clase.pesoMaximo,
      );
      if (mounted) setState(() => _preparada = resultado.bytes);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  String _nombrePng() {
    final nombre = widget.archivo.name;
    final punto = nombre.lastIndexOf('.');
    return '${punto <= 0 ? nombre : nombre.substring(0, punto)}.png';
  }

  String _tipoMime() {
    final nombre = widget.archivo.name.toLowerCase();
    if (nombre.endsWith('.png')) return 'image/png';
    if (nombre.endsWith('.webp')) return 'image/webp';
    if (nombre.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

class _CuadriculaTransparencia extends CustomPainter {
  const _CuadriculaTransparencia();

  @override
  void paint(Canvas canvas, Size size) {
    const lado = 12.0;
    final claro = Paint()..color = const Color(0xffeeeeee);
    final oscuro = Paint()..color = const Color(0xffcccccc);
    for (var y = 0.0; y < size.height; y += lado) {
      for (var x = 0.0; x < size.width; x += lado) {
        final alternado = ((x / lado).floor() + (y / lado).floor()).isOdd;
        canvas.drawRect(
          Rect.fromLTWH(x, y, lado, lado),
          alternado ? oscuro : claro,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
