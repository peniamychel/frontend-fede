import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Alta y edición de productores.
///
/// Repite los límites que valida Jakarta en el backend para avisar antes de
/// gastar una petición, pero además vuelca los errores que sí devuelve el
/// servidor sobre el campo que los provocó.
class ProductorFormulario extends StatefulWidget {
  const ProductorFormulario({super.key, this.productor, this.sindicatoFijo});

  /// Null en alta; el productor a modificar en edición.
  final Productor? productor;

  /// Sindicato ya decidido por el contexto desde el que se abrió el formulario
  /// —por ejemplo, el listado de un sindicato concreto—. Cuando viene, los
  /// desplegables de central y sindicato se reemplazan por un resumen fijo, y
  /// el formulario abre al instante porque no necesita cargar la jerarquía.
  ///
  /// Solo aplica al alta: en edición hacen falta los desplegables, porque
  /// cambiar de sindicato es justamente una de las cosas que se editan.
  final Sindicato? sindicatoFijo;

  @override
  State<ProductorFormulario> createState() => _ProductorFormularioState();
}

class _ProductorFormularioState extends State<ProductorFormulario> {
  final _formulario = GlobalKey<FormState>();

  late final TextEditingController _nombres;
  late final TextEditingController _apellidos;
  late final TextEditingController _ci;
  late final TextEditingController _carnet;
  late final TextEditingController _nombresCorregidos;
  late final TextEditingController _apellidosCorregidos;
  late final TextEditingController _fotoDescripcion;

  late bool _marcado;

  Central? _central;
  Sindicato? _sindicato;
  List<Central> _centrales = const [];
  List<Sindicato> _sindicatos = const [];

  bool _cargando = true;
  bool _guardando = false;
  Object? _errorCarga;

  /// Con el sindicato fijado se muestra un resumen en vez de los desplegables.
  /// Se puede soltar desde la propia pantalla, para no dejar al usuario
  /// atrapado si se equivocó de sindicato al entrar.
  late bool _sindicatoBloqueado;

  /// Errores por campo devueltos por el backend en el último intento.
  Map<String, String> _erroresServidor = const {};

  bool get _esEdicion => widget.productor != null;

  @override
  void initState() {
    super.initState();
    final p = widget.productor;
    _nombres = TextEditingController(text: p?.nombres ?? '');
    _apellidos = TextEditingController(text: p?.apellidos ?? '');
    _ci = TextEditingController(text: p?.ci ?? '');
    _carnet = TextEditingController(text: p?.carnetProductor ?? '');
    _nombresCorregidos = TextEditingController(text: p?.nombresCorregidos ?? '');
    _apellidosCorregidos =
        TextEditingController(text: p?.apellidosCorregidos ?? '');
    _fotoDescripcion = TextEditingController(text: p?.fotoDescripcion ?? '');
    _marcado = p?.marcado ?? false;
    _sindicatoBloqueado = p == null && widget.sindicatoFijo != null;

    if (_sindicatoBloqueado) {
      // Nada que pedir al servidor: el sindicato ya vino resuelto.
      _sindicato = widget.sindicatoFijo;
      _cargando = false;
    } else {
      _cargarJerarquia();
    }
  }

  /// Suelta el sindicato fijado y pasa a los desplegables, preseleccionando lo
  /// que ya estaba elegido.
  void _cambiarSindicato() {
    setState(() {
      _sindicatoBloqueado = false;
      _cargando = true;
    });
    _cargarJerarquia();
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _ci.dispose();
    _carnet.dispose();
    _nombresCorregidos.dispose();
    _apellidosCorregidos.dispose();
    _fotoDescripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarJerarquia() async {
    final padron = PadronScope.of(context);
    try {
      final centrales = await padron.centrales.listar();
      Central? central;
      List<Sindicato> sindicatos = const [];
      Sindicato? sindicato;

      // Hay que reconstruir la cascada hacia lo ya elegido: en edición, el
      // sindicato del productor; al soltar el bloqueo, el que venía fijado.
      // Los objetos deben salir de estas listas y no de otro lado, porque los
      // DropdownButtonFormField comparan por identidad contra sus items.
      final destinoCentralId =
          widget.productor?.centralId ?? _sindicato?.centralId;
      final destinoSindicatoId = widget.productor?.sindicatoId ?? _sindicato?.id;

      if (destinoCentralId != null) {
        for (final c in centrales) {
          if (c.id == destinoCentralId) central = c;
        }
        if (central != null) {
          sindicatos = await padron.centrales.sindicatos(central.id);
          for (final s in sindicatos) {
            if (s.id == destinoSindicatoId) sindicato = s;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _centrales = centrales;
        _central = central;
        _sindicatos = sindicatos;
        _sindicato = sindicato;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = e;
        _cargando = false;
      });
    }
  }

  Future<void> _elegirCentral(Central? central) async {
    setState(() {
      _central = central;
      _sindicato = null;
      _sindicatos = const [];
    });
    if (central == null) return;

    try {
      final sindicatos =
          await PadronScope.of(context).centrales.sindicatos(central.id);
      if (mounted) setState(() => _sindicatos = sindicatos);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  String? _texto(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _guardar() async {
    setState(() => _erroresServidor = const {});

    if (!_formulario.currentState!.validate()) return;

    final sindicato = _sindicato;
    if (sindicato == null) {
      mostrarAviso(context, 'Elegí el sindicato al que pertenece.');
      return;
    }

    final request = ProductorRequest(
      nombres: _nombres.text.trim(),
      sindicatoId: sindicato.id,
      apellidos: _texto(_apellidos),
      ci: _texto(_ci),
      carnetProductor: _texto(_carnet),
      nombresCorregidos: _texto(_nombresCorregidos),
      apellidosCorregidos: _texto(_apellidosCorregidos),
      fotoDescripcion: _texto(_fotoDescripcion),
      marcado: _marcado,
    );

    setState(() => _guardando = true);

    try {
      final repo = PadronScope.of(context).productores;
      if (_esEdicion) {
        await repo.actualizar(widget.productor!.id, request);
      } else {
        await repo.crear(request);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _erroresServidor = e.errores;
      });
      // Repinta los errores del servidor sobre los campos.
      _formulario.currentState!.validate();
      if (e.errores.isEmpty) mostrarError(context, e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch ((_esEdicion, widget.sindicatoFijo)) {
            (true, _) => 'Editar productor',
            (false, final Sindicato s) => 'Nuevo productor en ${s.nombre}',
            _ => 'Nuevo productor',
          },
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: switch ((_cargando, _errorCarga)) {
        (true, _) => const Cargando(mensaje: 'Cargando la jerarquía…'),
        (_, final Object e) => FalloCarga(
            error: e,
            alReintentar: () {
              setState(() {
                _cargando = true;
                _errorCarga = null;
              });
              _cargarJerarquia();
            },
          ),
        _ => _cuerpo(context),
      },
    );
  }

  Widget _cuerpo(BuildContext context) {
    return Form(
      key: _formulario,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _titulo(context, 'Identificación'),
                  _campo(
                    controlador: _nombres,
                    etiqueta: 'Nombres *',
                    ayuda: 'Se guardan en mayúsculas y sin tildes.',
                    campoServidor: 'nombres',
                    maximo: ProductorRequest.maxNombres,
                    obligatorio: true,
                    textoEnMayusculas: true,
                  ),
                  _campo(
                    controlador: _apellidos,
                    etiqueta: 'Apellidos',
                    campoServidor: 'apellidos',
                    maximo: ProductorRequest.maxApellidos,
                    textoEnMayusculas: true,
                  ),
                  _campo(
                    controlador: _ci,
                    etiqueta: 'Cédula de identidad',
                    ayuda: 'Admite complemento, por ejemplo 8005906-1V.',
                    campoServidor: 'ci',
                    maximo: ProductorRequest.maxCi,
                  ),
                  _campo(
                    controlador: _carnet,
                    etiqueta: 'Carné de productor',
                    ayuda: 'Admite el valor NUEVO.',
                    campoServidor: 'carnetProductor',
                    maximo: ProductorRequest.maxCarnet,
                  ),
                  const SizedBox(height: 24),
                  _titulo(context, 'Ubicación en la jerarquía'),
                  if (_sindicatoBloqueado)
                    _resumenSindicato(context)
                  else ...[
                    DropdownButtonFormField<Central?>(
                      initialValue: _central,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Central *'),
                      items: [
                        for (final c in _centrales)
                          DropdownMenuItem<Central?>(
                              value: c, child: Text(c.nombre)),
                      ],
                      onChanged: _elegirCentral,
                      validator: (v) => v == null ? 'Elegí una central' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Sindicato?>(
                      initialValue: _sindicato,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Sindicato *',
                        helperText: _central == null
                            ? 'Elegí una central primero'
                            : null,
                        errorText: _erroresServidor['sindicatoId'],
                      ),
                      items: [
                        for (final s in _sindicatos)
                          DropdownMenuItem<Sindicato?>(
                              value: s, child: Text(s.nombre)),
                      ],
                      onChanged: _sindicatos.isEmpty
                          ? null
                          : (s) => setState(() => _sindicato = s),
                      validator: (v) => v == null ? 'Elegí un sindicato' : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _titulo(context, 'Revisión'),
                  _campo(
                    controlador: _nombresCorregidos,
                    etiqueta: 'Nombres corregidos',
                    ayuda: 'Columna «Nombre x» de la planilla.',
                    campoServidor: 'nombresCorregidos',
                    maximo: ProductorRequest.maxNombres,
                    textoEnMayusculas: true,
                  ),
                  _campo(
                    controlador: _apellidosCorregidos,
                    etiqueta: 'Apellidos corregidos',
                    campoServidor: 'apellidosCorregidos',
                    maximo: ProductorRequest.maxApellidos,
                    textoEnMayusculas: true,
                  ),
                  _campo(
                    controlador: _fotoDescripcion,
                    etiqueta: 'Rótulo de la fotografía',
                    ayuda: 'Dejarlo vacío es lo que cuenta como «sin foto».',
                    campoServidor: 'fotoDescripcion',
                    maximo: ProductorRequest.maxFotoDescripcion,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _marcado,
                    onChanged: (v) => setState(() => _marcado = v),
                    title: const Text('Marcado para seguimiento'),
                    subtitle:
                        const Text('Marca manual puesta durante la revisión.'),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_esEdicion ? 'Guardar cambios' : 'Registrar'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titulo(BuildContext context, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      );

  /// Resumen del sindicato ya decidido, en lugar de los dos desplegables.
  Widget _resumenSindicato(BuildContext context) {
    final tema = Theme.of(context);
    final s = _sindicato!;
    final error = _erroresServidor['sindicatoId'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: tema.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(Icons.groups_outlined, color: tema.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.nombre, style: tema.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Central ${s.centralNombre}',
                        style: tema.textTheme.bodySmall
                            ?.copyWith(color: tema.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _cambiarSindicato,
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              error,
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _campo({
    required TextEditingController controlador,
    required String etiqueta,
    required String campoServidor,
    required int maximo,
    String? ayuda,
    bool obligatorio = false,
    bool textoEnMayusculas = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controlador,
        maxLength: maximo,
        textCapitalization: textoEnMayusculas
            ? TextCapitalization.characters
            : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: etiqueta,
          helperText: ayuda,
          counterText: '',
        ),
        validator: (valor) {
          final servidor = _erroresServidor[campoServidor];
          if (servidor != null) return servidor;

          final v = (valor ?? '').trim();
          if (obligatorio && v.isEmpty) return 'Este campo es obligatorio';
          if (v.length > maximo) return 'No puede superar los $maximo caracteres';
          return null;
        },
      ),
    );
  }
}
