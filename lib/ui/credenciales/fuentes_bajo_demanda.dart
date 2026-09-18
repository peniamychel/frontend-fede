import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/diseno_credencial.dart';

/// Comparte incluso las cargas en curso entre anverso, reverso y editor.
final _cargas = <FuenteCredencial, Future<void>>{};
final _listas = <FuenteCredencial>{};

Future<void> cargarFuenteCredencial(FuenteCredencial fuente) =>
    _cargas.putIfAbsent(fuente, () async {
      try {
        final nombre = fuente.familiaFlutter.replaceFirst('Credencial', '');
        final loader = FontLoader(fuente.familiaFlutter);
        for (final variante in ['Regular', 'Bold']) {
          loader.addFont(rootBundle.load('assets/fonts/$nombre-$variante.ttf'));
        }
        await loader.load();
        _listas.add(fuente);
      } catch (_) {
        _cargas.remove(fuente);
        rethrow;
      }
    });

class FuentesBajoDemanda extends StatefulWidget {
  const FuentesBajoDemanda({
    super.key,
    required this.fuentes,
    required this.child,
  });
  final Set<FuenteCredencial> fuentes;
  final Widget child;

  @override
  State<FuentesBajoDemanda> createState() => _FuentesBajoDemandaState();
}

class _FuentesBajoDemandaState extends State<FuentesBajoDemanda> {
  late Future<void> _carga;

  void _cargar() {
    _carga = Future.wait(widget.fuentes.map(cargarFuenteCredencial));
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(FuentesBajoDemanda oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fuentes.length != widget.fuentes.length ||
        !oldWidget.fuentes.containsAll(widget.fuentes)) {
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _carga,
    builder: (context, snapshot) {
      if (_listas.containsAll(widget.fuentes)) return widget.child;
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () => setState(_cargar),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar carga de fuentes'),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return widget.child;
    },
  );
}
