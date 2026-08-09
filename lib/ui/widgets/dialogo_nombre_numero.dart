import 'package:flutter/material.dart';

/// Lo que devuelve [DialogoNombreNumero]: el nombre siempre, el número si se
/// cargó.
typedef NombreYNumero = ({String nombre, String? numero});

/// Diálogo de alta y edición para centrales y sindicatos.
///
/// Son dos campos porque ambos llevan, además del nombre, un número que asigna
/// la federación. El número es opcional pero único: si se repite, el backend
/// rechaza el guardado diciendo quién lo tiene.
///
/// Igual que [DialogoTexto], los controladores viven dentro del `State`. Es la
/// única forma de que se desechen cuando el árbol saca el diálogo de verdad y
/// no mientras la ruta todavía anima su salida.
class DialogoNombreNumero extends StatefulWidget {
  const DialogoNombreNumero({
    super.key,
    required this.titulo,
    this.etiquetaNombre = 'Nombre',
    this.nombreInicial = '',
    this.numeroInicial,
    this.textoAceptar = 'Guardar',
  });

  final String titulo;
  final String etiquetaNombre;
  final String nombreInicial;
  final String? numeroInicial;
  final String textoAceptar;

  /// Abre el diálogo. Devuelve null si se canceló.
  static Future<NombreYNumero?> mostrar(
    BuildContext context, {
    required String titulo,
    String etiquetaNombre = 'Nombre',
    String nombreInicial = '',
    String? numeroInicial,
    String textoAceptar = 'Guardar',
  }) {
    return showDialog<NombreYNumero>(
      context: context,
      builder: (context) => DialogoNombreNumero(
        titulo: titulo,
        etiquetaNombre: etiquetaNombre,
        nombreInicial: nombreInicial,
        numeroInicial: numeroInicial,
        textoAceptar: textoAceptar,
      ),
    );
  }

  @override
  State<DialogoNombreNumero> createState() => _DialogoNombreNumeroState();
}

class _DialogoNombreNumeroState extends State<DialogoNombreNumero> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _nombre =
      TextEditingController(text: widget.nombreInicial);
  late final TextEditingController _numero =
      TextEditingController(text: widget.numeroInicial ?? '');

  @override
  void dispose() {
    _nombre.dispose();
    _numero.dispose();
    super.dispose();
  }

  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;
    final numero = _numero.text.trim();
    Navigator.of(context).pop((
      nombre: _nombre.text.trim(),
      // Vacío es «sin número», no la cadena vacía: el backend guarda null y la
      // clave única deja convivir a todos los que no tienen.
      numero: numero.isEmpty ? null : numero,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombre,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '${widget.etiquetaNombre} *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Poné un nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numero,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Número',
                helperText: 'Opcional. No puede repetirse.',
              ),
              onFieldSubmitted: (_) => _aceptar(),
            ),
          ],
        ),
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
