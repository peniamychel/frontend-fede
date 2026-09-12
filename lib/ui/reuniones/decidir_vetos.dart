import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Poner y quitar vetos, desde la reunión que lo decide.
///
/// El veto no se decide mirando la ficha de una persona: se decide en asamblea,
/// y la asamblea ya está elegida cuando se llega acá —es la reunión en la que
/// se está parado—. Por eso estos dos diálogos no preguntan en qué reunión fue:
/// preguntan a quién, y por qué.
///
/// A la persona se la busca como se la nombra en la asamblea: por su nombre,
/// por la cédula que trae en la mano, o por cualquiera de sus dos códigos. Las
/// dos operaciones buscan igual, porque son el mismo acto en dos direcciones.

/// Veta a alguien en esta reunión. Devuelve true si se guardó.
Future<bool> vetarEnLaReunion(BuildContext context, Reunion reunion) async {
  final padron = PadronScope.of(context);

  final elegido = await showDialog<_Decision<Productor>>(
    context: context,
    builder: (_) => _DialogoDecision<Productor>(
      titulo: 'Vetar en «${reunion.titulo}»',
      explicacion:
          'Queda observado hasta que otra asamblea decida sacarlo de '
          'la lista: su credencial deja de emitirse, deja el cargo si ocupaba '
          'alguno, y no se le toma asistencia. No se lo da de baja ni pierde '
          'su parcela.',
      buscar: (texto) async =>
          (await padron.productores.listar(texto: texto)).contenido,
      fila: (p) => _Fila(
        titulo: p.nombreCompleto.isEmpty ? p.nombres : p.nombreCompleto,
        detalle: [
          if (p.ci != null) 'CI ${p.ci}',
          if (p.codigoPadron != null) p.codigoPadron!,
          p.sindicatoNombre,
        ].join(' · '),
      ),
      sinResultados: 'Nadie con ese nombre, cédula ni código.',
      etiquetaMotivo: 'Por qué se lo veta *',
      textoAceptar: 'Vetar',
    ),
  );
  if (elegido == null || !context.mounted) return false;

  try {
    await padron.vetos.vetar(
      VetoRequest(
        productorId: elegido.item.id,
        reunionId: reunion.id,
        motivo: elegido.motivo,
      ),
    );
    if (context.mounted) {
      mostrarExito(context, '${elegido.item.nombreCompleto} quedó observado');
    }
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

/// Saca a alguien de la lista en esta reunión. Devuelve true si se guardó.
///
/// Solo se ofrecen los vetos que rigen hoy, y no los que impuso esta misma
/// reunión: la asamblea que vetó no puede desdecirse en el mismo acto.
Future<bool> levantarEnLaReunion(BuildContext context, Reunion reunion) async {
  final padron = PadronScope.of(context);

  final elegido = await showDialog<_Decision<Veto>>(
    context: context,
    builder: (_) => _DialogoDecision<Veto>(
      titulo: 'Sacar de la lista en «${reunion.titulo}»',
      explicacion:
          'Al levantarlo, su credencial vuelve a emitirse. No '
          'aparecen los vetos que impuso esta misma reunión: eso se decide en '
          'otra asamblea.',
      buscar: (texto) async {
        final vigentes = await padron.vetos.buscar(texto: texto);
        return vigentes
            .where((v) => v.reunion?.id != reunion.id)
            .toList(growable: false);
      },
      fila: (v) => _Fila(
        titulo: v.productorNombre,
        detalle: [
          if (v.ci != null) 'CI ${v.ci}',
          if (v.codigoPadron != null) v.codigoPadron!,
          if (v.reunion != null) 'vetado en «${v.reunion!.titulo}»',
        ].join(' · '),
        nota: v.motivo,
      ),
      sinResultados: 'Nadie vetado con ese nombre, cédula ni código.',
      etiquetaMotivo: 'Por qué se lo saca *',
      textoAceptar: 'Levantar',
    ),
  );
  if (elegido == null || !context.mounted) return false;

  try {
    await padron.vetos.levantar(
      elegido.item.id,
      LevantarVetoRequest(reunionId: reunion.id, motivo: elegido.motivo),
    );
    if (context.mounted) {
      mostrarExito(
        context,
        '${elegido.item.productorNombre} salió de la lista',
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}

/// Lo elegido: a quién, y con qué detalle.
class _Decision<T> {
  const _Decision(this.item, this.motivo);

  final T item;
  final String motivo;
}

/// Cómo se dibuja un resultado de la búsqueda.
class _Fila {
  const _Fila({required this.titulo, required this.detalle, this.nota});

  final String titulo;
  final String detalle;

  /// Una segunda línea, para el motivo del veto que se va a levantar.
  final String? nota;
}

/// Buscar a alguien, elegirlo, y decir por qué.
///
/// Los dos pasos van en el mismo diálogo y no en dos pantallas: quien lo usa
/// está en una asamblea leyendo el acta en voz alta, y volver atrás para ver a
/// quién había elegido es justo lo que no se puede hacer ahí.
class _DialogoDecision<T> extends StatefulWidget {
  const _DialogoDecision({
    required this.titulo,
    required this.explicacion,
    required this.buscar,
    required this.fila,
    required this.sinResultados,
    required this.etiquetaMotivo,
    required this.textoAceptar,
  });

  final String titulo;
  final String explicacion;
  final Future<List<T>> Function(String texto) buscar;
  final _Fila Function(T item) fila;
  final String sinResultados;
  final String etiquetaMotivo;
  final String textoAceptar;

  @override
  State<_DialogoDecision<T>> createState() => _DialogoDecisionState<T>();
}

class _DialogoDecisionState<T> extends State<_DialogoDecision<T>> {
  final _formulario = GlobalKey<FormState>();
  final _busqueda = TextEditingController();
  final _motivo = TextEditingController();

  Timer? _espera;
  bool _buscando = false;
  String? _fallo;
  List<T> _resultados = const [];

  /// Null hasta que se elige a alguien. Con alguien elegido, la búsqueda se
  /// esconde: lo que queda por hacer es escribir el motivo.
  T? _elegido;

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    _motivo.dispose();
    super.dispose();
  }

  /// Se busca sola mientras se escribe, pero no en cada tecla: con el padrón
  /// entero detrás, una consulta por letra sería una consulta por letra.
  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    final limpio = texto.trim();
    if (limpio.length < 2) {
      setState(() {
        _resultados = const [];
        _fallo = null;
        _buscando = false;
      });
      return;
    }

    setState(() {
      _buscando = true;
      _fallo = null;
    });
    try {
      final encontrados = await widget.buscar(limpio);
      if (!mounted) return;
      setState(() {
        _resultados = encontrados;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resultados = const [];
        _fallo = e is ApiException ? e.mensaje : '$e';
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formulario,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.explicacion, style: tema.textTheme.bodySmall),
                const SizedBox(height: 16),
                if (_elegido == null) ...[
                  _campoDeBusqueda(),
                  const SizedBox(height: 8),
                  _resultado(context),
                ] else ...[
                  _elegidoFijo(context),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _motivo,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: widget.etiquetaMotivo,
                      helperText: 'Con el detalle que dé el acta.',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Hay que decir el motivo'
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _elegido == null ? null : _aceptar,
          child: Text(widget.textoAceptar),
        ),
      ],
    );
  }

  Widget _campoDeBusqueda() {
    return TextField(
      controller: _busqueda,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: 'Buscar a la persona',
        helperText: 'Por nombre, cédula o código (2IVI1 o el del QR).',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _buscando
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
        border: const OutlineInputBorder(),
      ),
      onChanged: _alEscribir,
      onSubmitted: _buscar,
    );
  }

  Widget _resultado(BuildContext context) {
    final tema = Theme.of(context);

    if (_fallo != null) {
      return Text(
        _fallo!,
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.error,
        ),
      );
    }
    if (_busqueda.text.trim().length < 2) {
      return Text(
        'Escribí al menos dos letras, o el código entero.',
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.outline,
        ),
      );
    }
    if (_buscando) {
      return const SizedBox.shrink();
    }
    if (_resultados.isEmpty) {
      return Text(
        widget.sinResultados,
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.outline,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in _resultados)
              _FilaResultado(
                fila: widget.fila(item),
                alElegir: () => setState(() => _elegido = item),
              ),
          ],
        ),
      ),
    );
  }

  /// A quién se eligió, ya fijo, con la salida para cambiarlo.
  Widget _elegidoFijo(BuildContext context) {
    final tema = Theme.of(context);
    final fila = widget.fila(_elegido as T);

    return Card(
      margin: EdgeInsets.zero,
      color: tema.colorScheme.secondaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.person,
          color: tema.colorScheme.onSecondaryContainer,
        ),
        title: Text(
          fila.titulo,
          style: tema.textTheme.titleSmall?.copyWith(
            color: tema.colorScheme.onSecondaryContainer,
          ),
        ),
        subtitle: Text(
          fila.detalle,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSecondaryContainer,
          ),
        ),
        trailing: TextButton(
          onPressed: () => setState(() => _elegido = null),
          child: const Text('Cambiar'),
        ),
      ),
    );
  }

  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;
    Navigator.of(context).pop(_Decision<T>(_elegido as T, _motivo.text.trim()));
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({required this.fila, required this.alElegir});

  final _Fila fila;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(fila.titulo),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fila.detalle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (fila.nota != null)
            Text(
              fila.nota!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
        ],
      ),
      onTap: alElegir,
    );
  }
}
