import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import 'estados.dart';

/// Lista con scroll infinito sobre un endpoint paginado del backend.
///
/// Pide la página siguiente cuando el usuario se acerca al final, y vuelve a
/// empezar desde cero si cambia [clave] — que es la firma de los filtros
/// activos.
class ListaPaginada<T> extends StatefulWidget {
  const ListaPaginada({
    super.key,
    required this.cargar,
    required this.constructor,
    required this.clave,
    this.vacio,
    this.tamanoPagina = Pagina.tamanoPorDefecto,
    this.separador,
    this.relleno,
  });

  /// Trae una página concreta. Recibe la paginación ya calculada.
  final Future<Pagina<T>> Function(Paginacion) cargar;

  final Widget Function(BuildContext, T) constructor;

  /// Firma de los filtros. Al cambiar, la lista se reinicia.
  final String clave;

  final Widget? vacio;
  final int tamanoPagina;
  final Widget? separador;
  final EdgeInsetsGeometry? relleno;

  @override
  State<ListaPaginada<T>> createState() => ListaPaginadaState<T>();
}

class ListaPaginadaState<T> extends State<ListaPaginada<T>> {
  final ScrollController _scroll = ScrollController();
  final List<T> _elementos = [];

  Pagina<T>? _ultima;
  bool _cargando = false;
  Object? _error;

  int get total => _ultima?.totalElementos ?? _elementos.length;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alHacerScroll);
    _reiniciar();
  }

  @override
  void didUpdateWidget(ListaPaginada<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clave != widget.clave) _reiniciar();
  }

  @override
  void dispose() {
    _scroll.removeListener(_alHacerScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _alHacerScroll() {
    if (!_scroll.hasClients) return;
    final restante = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (restante < 400) _cargarMas();
  }

  Future<void> _reiniciar() async {
    setState(() {
      _elementos.clear();
      _ultima = null;
      _error = null;
    });
    await _cargar(const Paginacion().pagina);
  }

  /// Recarga desde la primera página. Es lo que se dispara al tirar hacia
  /// abajo, y lo que hay que llamar después de crear o borrar un registro.
  Future<void> refrescar() => _reiniciar();

  void _cargarMas() {
    final ultima = _ultima;
    if (_cargando || ultima == null || ultima.esUltima) return;
    _cargar(ultima.numero + 1);
  }

  Future<void> _cargar(int numeroPagina) async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      if (numeroPagina == 0) _error = null;
    });

    try {
      final pagina = await widget.cargar(
        Paginacion(pagina: numeroPagina, tamano: widget.tamanoPagina),
      );
      if (!mounted) return;
      setState(() {
        // Una página 0 que llega tarde no debe duplicar lo ya cargado.
        if (numeroPagina == 0) _elementos.clear();
        _elementos.addAll(pagina.contenido);
        _ultima = pagina;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _elementos.isEmpty) {
      return FalloCarga(error: _error!, alReintentar: _reiniciar);
    }

    if (_elementos.isEmpty) {
      if (_cargando) return const Cargando();
      return RefreshIndicator(
        onRefresh: refrescar,
        child: LayoutBuilder(
          builder: (context, restricciones) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: restricciones.maxHeight,
              child: widget.vacio ??
                  const SinResultados(mensaje: 'No hay registros que mostrar.'),
            ),
          ),
        ),
      );
    }

    // Una fila extra al final: indicador de carga, aviso de error parcial, o
    // el total ya alcanzado.
    final extra = 1;

    return RefreshIndicator(
      onRefresh: refrescar,
      child: ListView.separated(
        controller: _scroll,
        padding: widget.relleno,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _elementos.length + extra,
        separatorBuilder: (_, _) =>
            widget.separador ?? const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i < _elementos.length) {
            return widget.constructor(context, _elementos[i]);
          }
          return _pie(context);
        },
      ),
    );
  }

  Widget _pie(BuildContext context) {
    final tema = Theme.of(context);

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 18, color: tema.colorScheme.error),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'No se pudo cargar más.',
                style: tema.textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: _cargarMas,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '${_elementos.length} de $total',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
