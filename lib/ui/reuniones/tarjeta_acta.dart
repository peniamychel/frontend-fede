import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// El acta de la reunión, hoja por hoja.
///
/// El acta casi nunca es un solo archivo: lo habitual es fotografiar el
/// cuaderno de actas con el teléfono, ahí mismo en la asamblea. Por eso las
/// hojas se suben de a una y quedan ordenadas, en vez de exigir un PDF armado
/// antes, que es un paso que nadie hace en el campo.
class TarjetaActa extends StatefulWidget {
  const TarjetaActa({super.key, required this.reunion, required this.alCambiar});

  final Reunion reunion;

  /// Se llama cuando el acta cambió, para que la reunión se recargue.
  final VoidCallback alCambiar;

  @override
  State<TarjetaActa> createState() => _TarjetaActaState();
}

class _TarjetaActaState extends State<TarjetaActa> {
  bool _subiendo = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hojas = widget.reunion.hojasActa;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Acta', style: tema.textTheme.titleLarge),
                ),
                if (hojas.isNotEmpty)
                  Text(
                    hojas.length == 1 ? '1 hoja' : '${hojas.length} hojas',
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: tema.colorScheme.outline),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Toda reunión tiene acta. Se sube hoja por hoja, en el orden en '
              'que están en el cuaderno, con el número que lleva en el libro.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            if (hojas.isEmpty)
              _SinActa(tema: tema)
            else ...[
              _numero(context),
              const SizedBox(height: 8),
              Column(
                children: [
                  for (final h in hojas)
                    _FilaHoja(
                      hoja: h,
                      alVer: () => _verHoja(h),
                      alQuitar: () => _quitarHoja(h),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _subiendo
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: _agregarHoja,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(hojas.isEmpty
                          ? 'Subir la primera hoja'
                          : 'Agregar otra hoja'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// El número del acta, arriba de las hojas.
  ///
  /// Va destacado y no como un dato más: es lo que permite volver al libro. Las
  /// actas que se cargaron antes de que el sistema lo pidiera quedaron sin él,
  /// así que se marcan en rojo con la salida para ponérselo.
  Widget _numero(BuildContext context) {
    final tema = Theme.of(context);
    final codigo = widget.reunion.codigoActa;
    final falta = codigo == null || codigo.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: falta
            ? tema.colorScheme.errorContainer
            : tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.tag,
              size: 18,
              color: falta
                  ? tema.colorScheme.onErrorContainer
                  : tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              falta ? 'Sin número de acta' : 'Acta N° $codigo',
              style: tema.textTheme.titleSmall?.copyWith(
                  color: falta ? tema.colorScheme.onErrorContainer : null),
            ),
          ),
          if (falta)
            Text(
              'Se cargó antes de que se pidiera',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.onErrorContainer),
            ),
          TextButton(
            onPressed: _cambiarNumero,
            child: Text(falta ? 'Ponerlo' : 'Corregir'),
          ),
        ],
      ),
    );
  }

  /// Corrige el número sin tocar las hojas.
  ///
  /// Que se haya tipeado mal no es motivo para volver a cargar el acta: el
  /// número es un dato del acta, no de cada foto.
  Future<void> _cambiarNumero() async {
    final codigo = await pedirNumeroDeActa(context,
        actual: widget.reunion.codigoActa, textoAceptar: 'Guardar');
    if (codigo == null || !mounted) return;

    try {
      setState(() => _subiendo = true);
      await PadronScope.of(context)
          .reuniones
          .ponerCodigoActa(widget.reunion.id, codigo);
      if (!mounted) return;
      setState(() => _subiendo = false);
      mostrarExito(context, 'Acta N° $codigo');
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendo = false);
      mostrarError(context, e);
    }
  }

  Future<void> _verHoja(HojaActa hoja) async {
    final url =
        PadronScope.of(context).reuniones.urlHoja(widget.reunion.id, hoja.id);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  /// Sube hojas al acta, pidiendo antes su número si todavía no lo tiene.
  ///
  /// El número se pregunta **antes** de abrir el selector de archivos: quien
  /// está subiendo tiene el libro abierto adelante en ese momento, y descubrir
  /// después de elegir seis fotos que además hacía falta un dato es la forma
  /// segura de que lo escriban de memoria o inventen algo.
  Future<void> _agregarHoja() async {
    var codigo = widget.reunion.codigoActa;
    if (codigo == null || codigo.isEmpty) {
      codigo = await pedirNumeroDeActa(context, textoAceptar: 'Elegir el archivo');
      if (codigo == null || !mounted) return;
    } else {
      // Las que siguen son del mismo acta: no se vuelve a preguntar.
      codigo = null;
    }

    try {
      final resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        // Hace falta en web, donde no hay ruta de archivo.
        withData: true,
        // Seis fotos de un cuaderno se eligen de una vez, no una por una.
        allowMultiple: true,
      );
      final elegidos = resultado?.files ?? const [];
      if (elegidos.isEmpty || !mounted) return;

      setState(() => _subiendo = true);
      final repo = PadronScope.of(context).reuniones;
      var subidas = 0;
      // De a una y en orden: el backend numera por orden de llegada, y en
      // paralelo dos hojas podrían pelearse el mismo número.
      for (final archivo in elegidos) {
        final bytes = archivo.bytes;
        if (bytes == null) continue;
        await repo.agregarHoja(
          reunionId: widget.reunion.id,
          bytes: bytes,
          nombreArchivo: archivo.name,
          // Solo con la primera: las que siguen ya lo tienen.
          codigo: subidas == 0 ? codigo : null,
        );
        subidas++;
      }
      if (!mounted) return;
      setState(() => _subiendo = false);
      mostrarExito(context, subidas == 1 ? 'Hoja agregada' : '$subidas hojas agregadas');
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendo = false);
      mostrarError(context, e);
      // Puede haber subido algunas antes de fallar.
      widget.alCambiar();
    }
  }

  Future<void> _quitarHoja(HojaActa hoja) async {
    final ultima = widget.reunion.hojasActa.length == 1;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Quitar la hoja ${hoja.orden}?'),
        content: Text(
          ultima
              ? 'Es la única hoja: la reunión se queda sin acta, y hasta que '
                  'se suba otra no se van a poder decidir vetos en ella.'
              : 'Las hojas que siguen se renumeran para no dejar un hueco.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await PadronScope.of(context)
          .reuniones
          .quitarHoja(widget.reunion.id, hoja.id);
      if (!mounted) return;
      mostrarExito(context, 'Hoja quitada');
      widget.alCambiar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }
}

/// Pregunta el número del acta. Devuelve null si se canceló.
///
/// Es obligatorio y por eso el diálogo no deja aceptar vacío: el archivo que se
/// sube es una foto de una hoja del libro, y sin el número de esa acta la foto
/// no se puede cotejar con el original meses después.
Future<String?> pedirNumeroDeActa(
  BuildContext context, {
  String? actual,
  required String textoAceptar,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _DialogoNumero(actual: actual, textoAceptar: textoAceptar),
    );

class _DialogoNumero extends StatefulWidget {
  const _DialogoNumero({required this.actual, required this.textoAceptar});

  final String? actual;
  final String textoAceptar;

  @override
  State<_DialogoNumero> createState() => _DialogoNumeroState();
}

class _DialogoNumeroState extends State<_DialogoNumero> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _codigo =
      TextEditingController(text: widget.actual ?? '');

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Número del acta'),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El que lleva en el libro del sindicato, como está escrito ahí. '
              'Es lo que permite volver al original a cotejar lo que se '
              'decidió.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codigo,
              autofocus: true,
              maxLength: 40,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'N° de acta *',
                hintText: '12/2026',
                prefixIcon: Icon(Icons.tag),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Poné el número del acta'
                  : null,
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

  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;
    Navigator.of(context).pop(_codigo.text.trim());
  }
}

class _SinActa extends StatelessWidget {
  const _SinActa({required this.tema});

  final ThemeData tema;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.upload_file_outlined,
              color: tema.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Todavía sin acta. Subí el PDF o las fotos del cuaderno, con el '
              'número que lleva en el libro.',
              style: tema.textTheme.bodyMedium
                  ?.copyWith(color: tema.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaHoja extends StatelessWidget {
  const _FilaHoja({
    required this.hoja,
    required this.alVer,
    required this.alQuitar,
  });

  final HojaActa hoja;
  final VoidCallback alVer;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: tema.colorScheme.secondaryContainer,
        child: Text('${hoja.orden}',
            style: tema.textTheme.labelMedium
                ?.copyWith(color: tema.colorScheme.onSecondaryContainer)),
      ),
      title: Text(hoja.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${hoja.esPdf ? 'PDF' : 'Imagen'} · ${hoja.pesoLegible}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Ver la hoja',
            onPressed: alVer,
            icon: const Icon(Icons.open_in_new, size: 20),
          ),
          IconButton(
            tooltip: 'Quitar la hoja',
            onPressed: alQuitar,
            icon: Icon(Icons.delete_outline,
                size: 20, color: tema.colorScheme.error),
          ),
        ],
      ),
      onTap: alVer,
    );
  }
}
