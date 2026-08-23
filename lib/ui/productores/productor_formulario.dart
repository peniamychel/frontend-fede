import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'productor_detalle_pagina.dart';

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

  late bool _marcado;

  // ---------------------------------------------------- parcela y sistema
  //
  // Solo en el alta. En la edición la parcela se maneja desde la ficha, que
  // además tiene traspaso e historial: acá lo único que se resuelve es con qué
  // tierra entra al padrón alguien que recién se registra.

  _OpcionParcela _opcionParcela = _OpcionParcela.ninguna;
  late final TextEditingController _parcelaNumero;
  late final TextEditingController _parcelaSuperficie;
  ExtensionLote? _parcelaExtension;
  Lote? _parcelaExistente;

  /// Parcelas del sindicato elegido que hoy no tiene nadie. Son las únicas que
  /// se pueden asignar sin quitárselas a otro: eso es un traspaso, tiene fecha
  /// y motivo, y se hace desde la ficha de la parcela.
  List<Lote> _parcelasLibres = const [];

  _OpcionSistema _opcionSistema = _OpcionSistema.ninguno;
  late final TextEditingController _sistemaCodigo;
  late final TextEditingController _sistemaDescripcion;
  Sistema? _sistemaExistente;

  /// Sistemas dados de alta que no están instalados en ninguna parcela.
  List<Sistema> _sistemasLibres = const [];

  bool _cargandoDisponibles = false;

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

  _EstadoCedula _estadoCedula = _EstadoCedula.pendiente;
  String? _cedulaConsultada;
  String? _mensajeCedula;

  bool get _esEdicion => widget.productor != null;
  bool get _datosHabilitados =>
      _esEdicion ||
      _estadoCedula == _EstadoCedula.encontradaSie ||
      _estadoCedula == _EstadoCedula.ingresoManual;
  bool get _verificandoCedula => _estadoCedula == _EstadoCedula.buscando;

  @override
  void initState() {
    super.initState();
    final p = widget.productor;
    _nombres = TextEditingController(text: p?.nombres ?? '');
    _apellidos = TextEditingController(text: p?.apellidos ?? '');
    _ci = TextEditingController(text: p?.ci ?? '');
    if (!_esEdicion) _ci.addListener(_alCambiarCedula);
    _parcelaNumero = TextEditingController();
    _parcelaSuperficie = TextEditingController();
    _sistemaCodigo = TextEditingController();
    _sistemaDescripcion = TextEditingController();
    _marcado = p?.marcado ?? false;
    _sindicatoBloqueado = p == null && widget.sindicatoFijo != null;

    if (_sindicatoBloqueado) {
      // Nada que pedir al servidor: el sindicato ya vino resuelto.
      _sindicato = widget.sindicatoFijo;
      _cargando = false;
      _cargarDisponibles();
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
    if (!_esEdicion) _ci.removeListener(_alCambiarCedula);
    _nombres.dispose();
    _apellidos.dispose();
    _ci.dispose();
    _parcelaNumero.dispose();
    _parcelaSuperficie.dispose();
    _sistemaCodigo.dispose();
    _sistemaDescripcion.dispose();
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
      final destinoSindicatoId =
          widget.productor?.sindicatoId ?? _sindicato?.id;

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
      _olvidarParcelaElegida();
    });
    if (central == null) return;

    try {
      final sindicatos = await PadronScope.of(
        context,
      ).centrales.sindicatos(central.id);
      if (mounted) setState(() => _sindicatos = sindicatos);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  void _elegirSindicato(Sindicato? sindicato) {
    setState(() {
      _sindicato = sindicato;
      // Las parcelas libres son de un sindicato: la que estaba elegida ya no
      // aplica, y dejarla puesta terminaría asignando tierra de otro lado.
      _olvidarParcelaElegida();
    });
    _cargarDisponibles();
  }

  void _olvidarParcelaElegida() {
    _parcelaExistente = null;
    _parcelasLibres = const [];
    if (_opcionParcela == _OpcionParcela.existente) {
      _opcionParcela = _OpcionParcela.ninguna;
      _opcionSistema = _OpcionSistema.ninguno;
    }
  }

  /// Trae lo que se puede asignar sin quitárselo a nadie: las parcelas del
  /// sindicato que hoy no tiene ningún productor, y los sistemas que no están
  /// instalados en ninguna parcela.
  ///
  /// Si falla no se avisa con un error: es material opcional del alta, y
  /// bloquear el registro de un productor porque no se pudo listar lo
  /// disponible sería desproporcionado. Las listas quedan vacías y la pantalla
  /// lo dice.
  Future<void> _cargarDisponibles() async {
    final sindicato = _sindicato;
    if (_esEdicion || sindicato == null) return;

    setState(() => _cargandoDisponibles = true);
    final padron = PadronScope.of(context);
    try {
      final resultados = await Future.wait([
        padron.lotes.listar(sindicatoId: sindicato.id),
        padron.sistemas.listar(disponibles: true),
      ]);
      if (!mounted) return;
      setState(() {
        _parcelasLibres = (resultados[0] as List<Lote>)
            .where((l) => !l.tieneTenedor)
            .toList(growable: false);
        _sistemasLibres = resultados[1] as List<Sistema>;
        _cargandoDisponibles = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _parcelasLibres = const [];
        _sistemasLibres = const [];
        _cargandoDisponibles = false;
      });
    }
  }

  String? _texto(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  /// Productores ya registrados con la cédula que se está escribiendo.
  List<Productor> _yaRegistrados = const [];

  void _alCambiarCedula() {
    final consultada = _cedulaConsultada;
    if (consultada == null || _ci.text.trim() == consultada) return;
    setState(() {
      _estadoCedula = _EstadoCedula.pendiente;
      _cedulaConsultada = null;
      _mensajeCedula = null;
      _yaRegistrados = const [];
      _nombres.clear();
      _apellidos.clear();
    });
  }

  Future<void> _verificarCedula() async {
    if (_esEdicion || _verificandoCedula) return;
    final buscado = _ci.text.trim();
    if (buscado.isEmpty) {
      mostrarAviso(context, 'Ingresá la cédula de identidad.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _estadoCedula = _EstadoCedula.buscando;
      _cedulaConsultada = buscado;
      _mensajeCedula = null;
      _yaRegistrados = const [];
      _nombres.clear();
      _apellidos.clear();
    });

    try {
      final repositorio = PadronScope.of(context).productores;
      final encontrados = await repositorio.porCedula(buscado);
      if (!_consultaVigente(buscado)) return;
      if (encontrados.isNotEmpty) {
        setState(() {
          _estadoCedula = _EstadoCedula.existente;
          _yaRegistrados = encontrados;
        });
        return;
      }

      final consulta = await repositorio.consultarPersona(buscado);
      if (!_consultaVigente(buscado)) return;
      switch (consulta.estado) {
        case EstadoConsultaPersona.encontrada:
          _nombres.text = consulta.nombres ?? '';
          _apellidos.text = consulta.apellidos ?? '';
          setState(() {
            _estadoCedula = _EstadoCedula.encontradaSie;
            _mensajeCedula = consulta.mensaje;
          });
          break;
        case EstadoConsultaPersona.noEncontrada:
          setState(() {
            _estadoCedula = _EstadoCedula.ingresoManual;
            _mensajeCedula = consulta.mensaje;
          });
          break;
        case EstadoConsultaPersona.noDisponible:
          setState(() {
            _estadoCedula = _EstadoCedula.noDisponible;
            _mensajeCedula = consulta.mensaje;
          });
          break;
      }
    } catch (e) {
      if (!_consultaVigente(buscado)) return;
      setState(() {
        _estadoCedula = _EstadoCedula.noDisponible;
        _mensajeCedula = switch (e) {
          ApiException error => error.descripcion,
          SinConexionException error => error.descripcion,
          _ => 'No se pudo verificar la cédula en este momento.',
        };
      });
    }
  }

  bool _consultaVigente(String buscado) =>
      mounted && _ci.text.trim() == buscado && _cedulaConsultada == buscado;

  void _continuarManualmente() {
    setState(() {
      _estadoCedula = _EstadoCedula.ingresoManual;
      _mensajeCedula = 'Ingreso manual habilitado sin datos de SIE.';
    });
  }

  Widget _avisoDeCedulaRepetida(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: tema.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _yaRegistrados.length == 1
                      ? 'Esa cédula ya está registrada.'
                      : 'Esa cédula ya está registrada en '
                            '${_yaRegistrados.length} productores.',
                  style: tema.textTheme.titleSmall?.copyWith(
                    color: tema.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in _yaRegistrados)
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  p.habilitado
                      ? Icons.person_outline
                      : Icons.person_off_outlined,
                  size: 20,
                ),
                title: Text(
                  p.nombreCompleto.isEmpty ? p.nombres : p.nombreCompleto,
                ),
                subtitle: Text(
                  p.habilitado
                      ? p.ruta
                      : '${p.ruta} · dado de baja, se lo puede reincorporar',
                  style: tema.textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _abrirFicha(p),
              ),
            ),
        ],
      ),
    );
  }

  /// Abre una ficha y, al volver de ella, cierra también el formulario.
  ///
  /// Se usa tanto cuando la cédula ya estaba registrada como después de crear
  /// un productor. Mantener el formulario debajo de la ficha permite esperar
  /// a que se cargue la fotografía y recién entonces refrescar el listado del
  /// que se vino.
  Future<void> _abrirFicha(Productor p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductorDetallePagina(productorId: p.id),
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  // ------------------------------------------------ la sección de parcela

  List<Widget> _seccionParcela(BuildContext context) {
    final tema = Theme.of(context);
    return [
      const SizedBox(height: 24),
      _titulo(context, 'Parcela'),
      Text(
        'Opcional. Se le puede dar una parcela nueva o una del sindicato que '
        'hoy no tenga nadie.',
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.outline,
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<_OpcionParcela>(
        segments: const [
          ButtonSegment(
            value: _OpcionParcela.ninguna,
            label: Text('Sin parcela'),
          ),
          ButtonSegment(value: _OpcionParcela.nueva, label: Text('Nueva')),
          ButtonSegment(
            value: _OpcionParcela.existente,
            label: Text('Existente'),
          ),
        ],
        selected: {_opcionParcela},
        onSelectionChanged: (elegido) => setState(() {
          _opcionParcela = elegido.first;
          if (_opcionParcela == _OpcionParcela.ninguna) {
            // Sin parcela no hay dónde instalar un sistema.
            _opcionSistema = _OpcionSistema.ninguno;
          }
        }),
      ),
      if (_opcionParcela == _OpcionParcela.nueva) ...[
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _campo(
                controlador: _parcelaNumero,
                etiqueta: 'N° de parcela',
                campoServidor: 'numero',
                maximo: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<ExtensionLote?>(
                initialValue: _parcelaExtension,
                decoration: const InputDecoration(labelText: 'Extensión'),
                items: [
                  const DropdownMenuItem<ExtensionLote?>(
                    value: null,
                    child: Text('—'),
                  ),
                  for (final e in ExtensionLote.values)
                    DropdownMenuItem<ExtensionLote?>(
                      value: e,
                      child: Text(e.valor),
                    ),
                ],
                onChanged: (v) => setState(() => _parcelaExtension = v),
              ),
            ),
          ],
        ),
        _campo(
          controlador: _parcelaSuperficie,
          etiqueta: 'Superficie en hectáreas',
          ayuda: 'Opcional. Se puede medir después.',
          campoServidor: 'superficie',
          maximo: 12,
        ),
      ],
      if (_opcionParcela == _OpcionParcela.existente) ...[
        const SizedBox(height: 12),
        if (_cargandoDisponibles)
          const LinearProgressIndicator()
        else if (_parcelasLibres.isEmpty)
          _Aviso(
            texto: _sindicato == null
                ? 'Elegí primero el sindicato.'
                : 'En ${_sindicato!.nombre} no hay parcelas sin tenedor. '
                      'Podés crear una nueva.',
          )
        else
          DropdownButtonFormField<Lote?>(
            initialValue: _parcelaExistente,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Parcela sin tenedor *',
            ),
            items: [
              for (final l in _parcelasLibres)
                DropdownMenuItem<Lote?>(
                  value: l,
                  child: Text(
                    l.codigo.isEmpty ? 'Parcela ${l.id}' : l.codigo,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _parcelaExistente = v),
            validator: (v) => v == null ? 'Elegí una parcela' : null,
          ),
      ],
      if (_opcionParcela != _OpcionParcela.ninguna) ..._seccionSistema(context),
    ];
  }

  List<Widget> _seccionSistema(BuildContext context) {
    final tema = Theme.of(context);
    return [
      const SizedBox(height: 20),
      Text(
        'Sistema de la parcela',
        style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      Text(
        'Opcional. El sistema es un agregado que la parcela puede tener, y que '
        'después se puede trasladar a otra.',
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.outline,
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<_OpcionSistema>(
        segments: const [
          ButtonSegment(
            value: _OpcionSistema.ninguno,
            label: Text('Sin sistema'),
          ),
          ButtonSegment(value: _OpcionSistema.nuevo, label: Text('Nuevo')),
          ButtonSegment(
            value: _OpcionSistema.existente,
            label: Text('Existente'),
          ),
        ],
        selected: {_opcionSistema},
        onSelectionChanged: (elegido) =>
            setState(() => _opcionSistema = elegido.first),
      ),
      if (_opcionSistema == _OpcionSistema.nuevo) ...[
        const SizedBox(height: 12),
        _campo(
          controlador: _sistemaCodigo,
          etiqueta: 'Código del sistema *',
          campoServidor: 'codigo',
          maximo: 40,
          obligatorio: true,
          textoEnMayusculas: true,
        ),
        _campo(
          controlador: _sistemaDescripcion,
          etiqueta: 'Descripción',
          campoServidor: 'descripcion',
          maximo: 200,
        ),
      ],
      if (_opcionSistema == _OpcionSistema.existente) ...[
        const SizedBox(height: 12),
        if (_cargandoDisponibles)
          const LinearProgressIndicator()
        else if (_sistemasLibres.isEmpty)
          const _Aviso(
            texto: 'No hay sistemas sin instalar. Podés dar de alta uno nuevo.',
          )
        else
          DropdownButtonFormField<Sistema?>(
            initialValue: _sistemaExistente,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sistema disponible *',
            ),
            items: [
              for (final s in _sistemasLibres)
                DropdownMenuItem<Sistema?>(
                  value: s,
                  child: Text(s.codigo, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _sistemaExistente = v),
            validator: (v) => v == null ? 'Elegí un sistema' : null,
          ),
      ],
    ];
  }

  /// Le da la parcela al productor recién creado, y el sistema a la parcela.
  ///
  /// Va después del alta y no dentro, porque hacen falta el id del productor y
  /// el de la parcela para encadenarlos. Si algo de esto falla, el productor ya
  /// quedó registrado: se avisa exactamente eso, para que nadie lo cargue dos
  /// veces creyendo que no se guardó.
  Future<void> _asignarParcela(Productor productor, Sindicato sindicato) async {
    final padron = PadronScope.of(context);

    final Lote parcela = switch (_opcionParcela) {
      _OpcionParcela.nueva => await padron.lotes.crear(
        LoteRequest(
          sindicatoId: sindicato.id,
          productorId: productor.id,
          numero: _texto(_parcelaNumero),
          extension: _parcelaExtension,
          superficie: double.tryParse(
            (_texto(_parcelaSuperficie) ?? '').replaceAll(',', '.'),
          ),
        ),
      ),
      _OpcionParcela.existente => await padron.lotes.traspasar(
        _parcelaExistente!.id,
        TraspasoRequest(motivo: MotivoTraspaso.otro, productorId: productor.id),
      ),
      _OpcionParcela.ninguna => throw StateError(
        'sin parcela no hay nada que asignar',
      ),
    };

    switch (_opcionSistema) {
      case _OpcionSistema.ninguno:
        break;
      case _OpcionSistema.nuevo:
        final creado = await padron.sistemas.crear(
          SistemaRequest(
            codigo: _texto(_sistemaCodigo)!,
            descripcion: _texto(_sistemaDescripcion),
          ),
        );
        await padron.sistemas.trasladar(
          creado.id,
          parcela.id,
          const TraspasoRequest(motivo: MotivoTraspaso.otro),
        );
      case _OpcionSistema.existente:
        await padron.sistemas.trasladar(
          _sistemaExistente!.id,
          parcela.id,
          const TraspasoRequest(motivo: MotivoTraspaso.otro),
        );
    }
  }

  Future<void> _guardar() async {
    setState(() => _erroresServidor = const {});

    if (!_datosHabilitados) {
      mostrarAviso(context, 'Verificá primero la cédula de identidad.');
      return;
    }

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
      // Los tres campos de la revisión del padrón salieron del formulario, pero
      // se siguen mandando tal como vinieron. El backend los asigna sin
      // preguntar, así que omitirlos no los dejaría quietos: los borraría, y
      // cada edición de una ficha se llevaría puesta la corrección de nombre
      // que la revisión había propuesto. En un alta valen null, que es lo
      // correcto: un productor nuevo no tiene nada que corregir.
      nombresCorregidos: widget.productor?.nombresCorregidos,
      apellidosCorregidos: widget.productor?.apellidosCorregidos,
      fotoDescripcion: widget.productor?.fotoDescripcion,
      marcado: _marcado,
    );

    setState(() => _guardando = true);

    try {
      final repo = PadronScope.of(context).productores;
      if (_esEdicion) {
        await repo.actualizar(widget.productor!.id, request);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      final creado = await repo.crear(request);
      if (_opcionParcela != _OpcionParcela.ninguna) {
        if (!mounted) return;
        try {
          await _asignarParcela(creado, sindicato);
        } catch (e) {
          // El productor ya está registrado; lo que falló es lo de después.
          // Se dice tal cual, o alguien vuelve a cargarlo creyendo que no se
          // guardó y termina con la persona duplicada en el padrón.
          if (!mounted) return;
          setState(() => _guardando = false);
          mostrarAviso(
            context,
            '${creado.nombreCompleto} quedó registrado, pero no se le pudo '
            'asignar la parcela.',
            detalle: e is ApiException
                ? '${e.descripcion} Se la podés dar desde su ficha.'
                : 'Se la podés dar desde su ficha.',
          );
          await _abrirFicha(creado);
          return;
        }
      }
      if (!mounted) return;
      await _abrirFicha(creado);
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
                  _campoCedula(),
                  if (_yaRegistrados.isNotEmpty)
                    _avisoDeCedulaRepetida(context),
                  if (!_esEdicion) _estadoDeCedula(context),
                  IgnorePointer(
                    ignoring: !_datosHabilitados,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _datosHabilitados ? 1 : 0.45,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          const SizedBox(height: 24),
                          _titulo(context, 'Ubicación en la jerarquía'),
                          if (_sindicatoBloqueado)
                            _resumenSindicato(context)
                          else ...[
                            DropdownButtonFormField<Central?>(
                              initialValue: _central,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Central *',
                              ),
                              items: [
                                for (final c in _centrales)
                                  DropdownMenuItem<Central?>(
                                    value: c,
                                    child: Text(c.nombre),
                                  ),
                              ],
                              onChanged: _elegirCentral,
                              validator: (v) =>
                                  v == null ? 'Elegí una central' : null,
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
                                    value: s,
                                    child: Text(s.nombre),
                                  ),
                              ],
                              onChanged: _sindicatos.isEmpty
                                  ? null
                                  : _elegirSindicato,
                              validator: (v) =>
                                  v == null ? 'Elegí un sindicato' : null,
                            ),
                          ],
                          if (!_esEdicion) ..._seccionParcela(context),
                          const SizedBox(height: 24),
                          _titulo(context, 'Revisión'),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _marcado,
                            onChanged: (v) => setState(() => _marcado = v),
                            title: const Text('Marcado para seguimiento'),
                            subtitle: const Text(
                              'Marca manual puesta durante la revisión.',
                            ),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _esEdicion ? 'Guardar cambios' : 'Registrar',
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _campoCedula() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _ci,
        maxLength: ProductorRequest.maxCi,
        textInputAction: _esEdicion
            ? TextInputAction.next
            : TextInputAction.search,
        onFieldSubmitted: _esEdicion ? null : (_) => _verificarCedula(),
        decoration: InputDecoration(
          labelText: _esEdicion
              ? 'Cédula de identidad'
              : 'Cédula de identidad *',
          helperText: 'Admite complemento, por ejemplo 8005906-1V.',
          counterText: '',
          suffixIcon: _esEdicion
              ? null
              : _verificandoCedula
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Verificar cédula',
                  onPressed: _verificarCedula,
                  icon: const Icon(Icons.search),
                ),
        ),
        validator: (valor) {
          final servidor = _erroresServidor['ci'];
          if (servidor != null) return servidor;
          final limpio = (valor ?? '').trim();
          if (!_esEdicion && limpio.isEmpty) {
            return 'Ingresá la cédula de identidad';
          }
          if (limpio.length > ProductorRequest.maxCi) {
            return 'No puede superar los ${ProductorRequest.maxCi} caracteres';
          }
          return null;
        },
      ),
    );
  }

  Widget _estadoDeCedula(BuildContext context) {
    final tema = Theme.of(context);
    return switch (_estadoCedula) {
      _EstadoCedula.existente => const SizedBox.shrink(),
      _EstadoCedula.pendiente => _panelCedula(
        context,
        icono: Icons.lock_outline,
        texto:
            'Ingresá la cédula y presioná buscar para habilitar los demás datos.',
        color: tema.colorScheme.surfaceContainerHighest,
      ),
      _EstadoCedula.buscando => _panelCedula(
        context,
        icono: Icons.manage_search,
        texto: 'Buscando primero en el padrón y después en SIE…',
        color: tema.colorScheme.surfaceContainerHighest,
      ),
      _EstadoCedula.encontradaSie => _panelCedula(
        context,
        icono: Icons.verified_outlined,
        texto: _mensajeCedula ?? 'Datos encontrados y completados desde SIE.',
        color: tema.colorScheme.primaryContainer,
      ),
      _EstadoCedula.ingresoManual => _panelCedula(
        context,
        icono: Icons.edit_outlined,
        texto:
            _mensajeCedula ??
            'La persona no fue encontrada. Completá sus datos manualmente.',
        color: tema.colorScheme.secondaryContainer,
      ),
      _EstadoCedula.noDisponible => _panelCedula(
        context,
        icono: Icons.cloud_off_outlined,
        texto: _mensajeCedula ?? 'No se pudo consultar el servicio SIE.',
        color: tema.colorScheme.errorContainer,
        acciones: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _verificarCedula,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
            FilledButton.tonalIcon(
              onPressed: _continuarManualmente,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Continuar manualmente'),
            ),
          ],
        ),
      ),
    };
  }

  Widget _panelCedula(
    BuildContext context, {
    required IconData icono,
    required String texto,
    required Color color,
    Widget? acciones,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(texto)),
            ],
          ),
          if (acciones != null) ...[const SizedBox(height: 10), acciones],
        ],
      ),
    );
  }

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
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.outline,
                        ),
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
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.error,
              ),
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
    ValueChanged<String>? alSalir,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Focus(
        onFocusChange: (tieneFoco) {
          if (!tieneFoco && alSalir != null) alSalir(controlador.text);
        },
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
            if (v.length > maximo) {
              return 'No puede superar los $maximo caracteres';
            }
            return null;
          },
        ),
      ),
    );
  }
}

/// Qué hacer con la parcela al registrar a alguien.
enum _OpcionParcela { ninguna, nueva, existente }

/// Y con el sistema de esa parcela.
enum _OpcionSistema { ninguno, nuevo, existente }

enum _EstadoCedula {
  pendiente,
  buscando,
  existente,
  encontradaSie,
  ingresoManual,
  noDisponible,
}

/// Nota dentro del formulario, para cuando no hay nada que elegir.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: tema.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: tema.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
