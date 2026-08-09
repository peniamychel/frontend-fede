import 'package:flutter/material.dart';

/// Diálogo con un único campo de texto.
///
/// Existe como widget propio, y no como una función que arma un `AlertDialog`,
/// por un motivo concreto: el controlador tiene que vivir y morir con el
/// diálogo.
///
/// El patrón intuitivo —crear el controlador, `await showDialog`, desecharlo—
/// rompe la aplicación. Cuando `showDialog` devuelve, la ruta todavía está
/// animando su salida y el `TextField` sigue montado usando ese controlador:
/// al reconstruirse durante la animación intenta escuchar un `ChangeNotifier`
/// ya desechado. El árbol queda a medio desmontar y aparece la pantalla roja.
///
/// Con el controlador dentro del `State`, se desecha en `dispose`, que corre
/// cuando el árbol ya sacó el diálogo de verdad.
class DialogoTexto extends StatefulWidget {
  const DialogoTexto({
    super.key,
    required this.titulo,
    this.etiqueta = 'Nombre',
    this.inicial = '',
    this.ayuda,
    this.lineas = 1,
    this.mayusculas = true,
    this.textoAceptar = 'Guardar',
  });

  final String titulo;
  final String etiqueta;
  final String inicial;
  final String? ayuda;
  final int lineas;
  final bool mayusculas;
  final String textoAceptar;

  /// Abre el diálogo y devuelve el texto, o null si se canceló o quedó vacío.
  static Future<String?> mostrar(
    BuildContext context, {
    required String titulo,
    String etiqueta = 'Nombre',
    String inicial = '',
    String? ayuda,
    int lineas = 1,
    bool mayusculas = true,
    String textoAceptar = 'Guardar',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => DialogoTexto(
        titulo: titulo,
        etiqueta: etiqueta,
        inicial: inicial,
        ayuda: ayuda,
        lineas: lineas,
        mayusculas: mayusculas,
        textoAceptar: textoAceptar,
      ),
    );
  }

  @override
  State<DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<DialogoTexto> {
  late final TextEditingController _controlador =
      TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _aceptar() {
    final texto = _controlador.text.trim();
    Navigator.of(context).pop(texto.isEmpty ? null : texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _controlador,
        autofocus: true,
        maxLines: widget.lineas,
        textCapitalization: widget.mayusculas
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: widget.etiqueta,
          helperText: widget.ayuda,
        ),
        // Enter confirma solo en los de una línea; en los multilínea hace falta
        // para escribir.
        onSubmitted: widget.lineas == 1 ? (_) => _aceptar() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aceptar,
          child: Text(widget.textoAceptar),
        ),
      ],
    );
  }
}
