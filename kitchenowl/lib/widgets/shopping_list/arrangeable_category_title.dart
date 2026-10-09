/// Nome di un reparto che si può trascinare per riordinare i reparti (feature
/// 005-reparti-dalla-lista del fork di Andrea). Il trascinamento parte con la
/// pressione lunga, col "tac" forte degli articoli, ma il riordino vero
/// (onStart) comincia solo oltre una piccola distanza: una pressione senza
/// movimento non deve chiudere tutti i reparti. Appena parte il riordino la
/// vista sostituisce i reparti con delle righe e questo nome si smonta: da lì
/// Flutter non passa più gli spostamenti del dito, ma chiama comunque la fine
/// del trascinamento, per questo onEnd è copiato all'inizio e lo scorrimento
/// ai bordi lo fa la vista con le righe.
library;

import 'package:flutter/material.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/services/strong_haptic.dart';
import 'package:kitchenowl/widgets/shopping_list/sliver_category_drop_header.dart';

class ArrangeableCategoryTitle extends StatefulWidget {
  final Category category;

  /// fingerY è la posizione verticale del dito sullo schermo.
  final void Function(Category category, double fingerY) onStart;
  final void Function() onEnd;
  final Widget child;

  const ArrangeableCategoryTitle({
    super.key,
    required this.category,
    required this.onStart,
    required this.onEnd,
    required this.child,
  });

  @override
  State<ArrangeableCategoryTitle> createState() =>
      _ArrangeableCategoryTitleState();
}

class _ArrangeableCategoryTitleState extends State<ArrangeableCategoryTitle> {
  // La stessa soglia degli articoli (ArrangeableItem)
  static const double _arrangeDistance = 16;

  Offset? _pointerDownPosition;
  bool _isArranging = false;
  void Function()? _onEnd;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Listener(
      onPointerDown: (event) => _pointerDownPosition = event.position,
      child: LongPressDraggable<Category>(
        data: widget.category,
        hapticFeedbackOnStart: false,
        feedback: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: width,
            child: CategoryRow(name: widget.category.name, isHighlighted: true),
          ),
        ),
        onDragStarted: _onDragStarted,
        onDragUpdate: _onDragUpdate,
        onDragCompleted: _onDragFinished,
        onDraggableCanceled: (velocity, offset) => _onDragFinished(),
        child: widget.child,
      ),
    );
  }

  void _onDragStarted() {
    strongHapticClick();
    _isArranging = false;
    _onEnd = widget.onEnd;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final start = _pointerDownPosition ?? details.globalPosition;
    if (_isArranging ||
        (details.globalPosition - start).distance <= _arrangeDistance) {
      return;
    }
    _isArranging = true;
    widget.onStart(widget.category, details.globalPosition.dy);
  }

  void _onDragFinished() {
    if (_isArranging) _onEnd?.call();
    _isArranging = false;
  }
}
