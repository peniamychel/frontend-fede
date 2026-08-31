import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'administracion/backups_pagina.dart';
import 'calidad/calidad_pagina.dart';
import 'credenciales/editor_credencial_pagina.dart';
import 'jerarquia/jerarquia_pagina.dart';
import 'productores/productores_pagina.dart';
import 'reuniones/reuniones_pagina.dart';

/// Armazón de la app con navegación adaptativa.
///
/// La misma app corre en escritorio, web y teléfono, así que la navegación
/// cambia de forma según el ancho disponible: barra inferior en móvil, riel
/// lateral en tablet, y riel extendido con etiquetas en escritorio.
class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int _seccion = 0;
  final List<int> _historialSecciones = [];
  final JerarquiaControlador _jerarquia = JerarquiaControlador();
  bool _preguntandoSalida = false;

  static const List<_Destino> _destinos = [
    _Destino('Productores', Icons.people_outline, Icons.people),
    _Destino('Jerarquía', Icons.account_tree_outlined, Icons.account_tree),
    _Destino('Reuniones', Icons.event_note_outlined, Icons.event_note),
    _Destino('Calidad', Icons.fact_check_outlined, Icons.fact_check),
    _Destino('Carnet', Icons.badge_outlined, Icons.badge),
    _Destino('Respaldos', Icons.backup_outlined, Icons.backup),
  ];

  /// Secciones que el usuario ya visitó.
  ///
  /// El IndexedStack conserva el scroll y los filtros al ir y volver, que es lo
  /// que se quiere, pero construye **todos** sus hijos de entrada: al abrir la
  /// app se disparaban once consultas a la API para dibujar cinco pantallas de
  /// las que se ve una. Sobre la red de una oficina, o desde un teléfono en el
  /// campo, eso es un segundo largo de espera por datos que nadie pidió.
  ///
  /// Con esto cada sección se arma la primera vez que se entra, y de ahí en
  /// adelante se conserva igual que antes.
  final Set<int> _visitadas = {0};

  @override
  Widget build(BuildContext context) {
    final paginas = [
      const ProductoresPagina(),
      JerarquiaPagina(controlador: _jerarquia),
      const ReunionesPagina(),
      const CalidadPagina(),
      const EditorCredencialPagina(),
      const BackupsPagina(),
    ];

    final contenido = IndexedStack(
      index: _seccion,
      children: [
        for (var i = 0; i < paginas.length; i++)
          _visitadas.contains(i) ? paginas[i] : const SizedBox.shrink(),
      ],
    );

    final armazon = LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth;

        if (ancho < 700) {
          return Scaffold(
            body: contenido,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _seccion,
              onDestinationSelected: _ir,
              destinations: [
                for (final d in _destinos)
                  NavigationDestination(
                    icon: Icon(d.icono),
                    selectedIcon: Icon(d.iconoActivo),
                    label: d.etiqueta,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _seccion,
                onDestinationSelected: _ir,
                extended: ancho >= 1100,
                labelType: ancho >= 1100
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: ancho >= 1100
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.badge_outlined),
                            SizedBox(width: 12),
                            Text(
                              'PADRÓN FEDERACIÓN\nCARRASCO TROPICAL',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(height: 8),
                destinations: [
                  for (final d in _destinos)
                    NavigationRailDestination(
                      icon: Icon(d.icono),
                      selectedIcon: Icon(d.iconoActivo),
                      label: Text(d.etiqueta),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: contenido),
            ],
          ),
        );
      },
    );

    return PopScope(
      // En la raíz, web conserva el historial normal del navegador. Android
      // intercepta siempre el último retroceso para confirmar antes de salir.
      canPop: kIsWeb && _seccion == 0 && _historialSecciones.isEmpty,
      onPopInvokedWithResult: (fueDescartado, _) {
        if (!fueDescartado) _retroceder();
      },
      child: armazon,
    );
  }

  void _ir(int indice) {
    if (indice == _seccion) return;
    setState(() {
      _historialSecciones.add(_seccion);
      _seccion = indice;
      // Queda anotada para siempre: a partir de acá esta sección se
      // construye como antes y conserva su estado al ir y volver.
      _visitadas.add(indice);
    });
  }

  Future<void> _retroceder() async {
    if (_seccion == 1 && _jerarquia.retroceder()) return;

    if (_historialSecciones.isNotEmpty) {
      setState(() => _seccion = _historialSecciones.removeLast());
      return;
    }

    if (_seccion != 0) {
      setState(() => _seccion = 0);
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _confirmarSalida();
    }
  }

  Future<void> _confirmarSalida() async {
    if (_preguntandoSalida || !mounted) return;
    _preguntandoSalida = true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir de la aplicación?'),
        content: const Text(
          '¿Querés cerrar PADRÓN FEDERACIÓN CARRASCO TROPICAL?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    _preguntandoSalida = false;
    if (salir == true) await SystemNavigator.pop();
  }
}

class _Destino {
  const _Destino(this.etiqueta, this.icono, this.iconoActivo);

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
}
