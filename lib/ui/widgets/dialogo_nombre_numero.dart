import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lo que devuelve [DialogoNombreNumero]: el nombre siempre, el segundo campo
/// si se cargó.
///
/// El segundo se sigue llamando `numero` por cómo nació el diálogo, pero ahí
/// viaja lo que describa [SegundoCampo]: el número del sindicato, la sigla de
/// la central o la descripción de un sistema.
typedef NombreYNumero = ({String nombre, String? numero});

/// Qué se pide en el segundo campo del diálogo.
///
/// Existe porque no todos los que abren este diálogo piden lo mismo ahí: el
/// sindicato lleva un número, la central una sigla de tres letras y un sistema
/// su descripción. Sin esto habría tres diálogos casi iguales, o uno con la
/// etiqueta equivocada.
class SegundoCampo {
  const SegundoCampo({
    required this.etiqueta,
    this.ayuda,
    this.formateadores = const [],
    this.validador,
  });

  final String etiqueta;

  /// Línea de abajo. Es donde se explica la regla, así que conviene que la diga
  /// antes de que el guardado falle.
  final String? ayuda;

  /// Lo que se puede tipear. Se aplican también al pegar, que es por donde se
  /// cuela lo que el teclado no deja escribir.
  final List<TextInputFormatter> formateadores;

  /// Recibe el texto ya recortado y devuelve el error, o null si está bien.
  ///
  /// No se lo llama con el campo vacío: vacío siempre vale, porque el segundo
  /// campo es opcional en todos los casos.
  final String? Function(String)? validador;

  /// El número que asigna la federación, que es lo que llevan los sindicatos.
  static const numero = SegundoCampo(
    etiqueta: 'Número',
    ayuda: 'Opcional. No puede repetirse.',
  );

  /// La sigla de la central: tres caracteres, siempre en mayúsculas.
  ///
  /// Admite números además de letras porque varias centrales empiezan con uno:
  /// la sigla de 1RO DE MAYO es 1MO.
  ///
  /// El largo y las mayúsculas se imponen mientras se escribe en vez de avisar
  /// después: son tres caracteres, no hay nada que explicar si el campo solo
  /// deja escribir eso. El validador cubre lo que el formateador no puede, que
  /// es haber escrito uno o dos y frenar ahí.
  static final abreviatura = SegundoCampo(
    etiqueta: 'Abreviatura',
    ayuda: 'Opcional. Tres letras o números, y no puede repetirse.',
    formateadores: [
      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
      LengthLimitingTextInputFormatter(3),
      _AMayusculas(),
    ],
    validador: (v) => v.length == 3 ? null : 'Son tres caracteres',
  );
}

/// Pasa a mayúsculas lo que se escribe.
///
/// [TextCapitalization] no sirve acá: le sugiere el turno de mayúsculas al
/// teclado del teléfono y no toca el texto, así que en escritorio o al pegar no
/// hace nada. Como el largo no cambia, la selección sigue siendo válida.
class _AMayusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue anterior, TextEditingValue nuevo) =>
      nuevo.copyWith(text: nuevo.text.toUpperCase());
}

/// Diálogo de alta y edición para centrales, sindicatos y sistemas.
///
/// Son dos campos: el nombre, y algo corto que lo acompaña y describe
/// [SegundoCampo]. Ese segundo es siempre opcional, y cuando es único lo
/// controla el backend, que rechaza el guardado diciendo quién lo tiene.
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
    this.segundo = SegundoCampo.numero,
    this.textoAceptar = 'Guardar',
  });

  final String titulo;
  final String etiquetaNombre;
  final String nombreInicial;
  final String? numeroInicial;
  final SegundoCampo segundo;
  final String textoAceptar;

  /// Abre el diálogo. Devuelve null si se canceló.
  static Future<NombreYNumero?> mostrar(
    BuildContext context, {
    required String titulo,
    String etiquetaNombre = 'Nombre',
    String nombreInicial = '',
    String? numeroInicial,
    SegundoCampo segundo = SegundoCampo.numero,
    String textoAceptar = 'Guardar',
  }) {
    return showDialog<NombreYNumero>(
      context: context,
      builder: (context) => DialogoNombreNumero(
        titulo: titulo,
        etiquetaNombre: etiquetaNombre,
        nombreInicial: nombreInicial,
        numeroInicial: numeroInicial,
        segundo: segundo,
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
      // Vacío es «sin cargar», no la cadena vacía: el backend guarda null y la
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
              inputFormatters: widget.segundo.formateadores,
              decoration: InputDecoration(
                labelText: widget.segundo.etiqueta,
                helperText: widget.segundo.ayuda,
              ),
              validator: (v) {
                final texto = (v ?? '').trim();
                // Vacío es «sin cargar», no un error: el campo es opcional.
                if (texto.isEmpty) return null;
                return widget.segundo.validador?.call(texto);
              },
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
