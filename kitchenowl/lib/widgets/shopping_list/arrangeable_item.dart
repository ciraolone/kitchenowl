/// Casella della lista della spesa che si può trascinare e su cui si può
/// lasciare un altro articolo (feature 004-riordino-trascinamento del fork di
/// Andrea). ItemArrangement dice cosa fare all'inizio del trascinamento, alla
/// fine e al rilascio su un altro articolo; ArrangeableItem lo applica a una
/// casella. Il trascinamento parte con la pressione lunga, che quindi la
/// casella stessa non deve avere: se il dito si lascia senza essersi mosso, è
/// ArrangeableItem ad aprire la scheda dell'articolo. Il trascinamento "vero"
/// (onStart) comincia solo oltre una piccola distanza, così una pressione per
/// aprire la scheda non fa chiudere i reparti. Durante il trascinamento la
/// lista scorre da sola ai bordi e la casella resta viva anche se esce dallo
/// schermo, altrimenti la griglia la smonterebbe e i movimenti del dito non
/// arriverebbero più.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kitchenowl/models/item.dart';

class ItemArrangement<T extends Item> {
  final void Function(T item) onStart;
  final void Function() onEnd;
  final void Function(T moved, T target) onDrop;

  const ItemArrangement({
    required this.onStart,
    required this.onEnd,
    required this.onDrop,
  });
}

class ArrangeableItem<T extends Item> extends StatefulWidget {
  final T item;
  final ItemArrangement<T> arrangement;
  final void Function() onOpen;
  final Widget child;

  const ArrangeableItem({
    super.key,
    required this.item,
    required this.arrangement,
    required this.onOpen,
    required this.child,
  });

  @override
  State<ArrangeableItem<T>> createState() => _ArrangeableItemState<T>();
}

class _ArrangeableItemState<T extends Item> extends State<ArrangeableItem<T>>
    with AutomaticKeepAliveClientMixin {
  static const double _arrangeDistance = 16;
  static const double _autoScrollVelocity = 50;

  Offset? _pointerDownPosition;
  bool _isDragging = false;
  bool _isArranging = false;
  Size? _tileSize;
  EdgeDraggingAutoScroller? _autoScroller;

  // Copiati all'inizio del trascinamento: se la casella esce dall'albero,
  // la fine del trascinamento deve comunque arrivare a chi l'ha iniziato
  ItemArrangement<T>? _arrangement;
  void Function()? _onOpen;

  @override
  bool get wantKeepAlive => _isDragging;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Listener(
      onPointerDown: (event) => _pointerDownPosition = event.position,
      child: DragTarget<T>(
        onWillAcceptWithDetails: (details) =>
            details.data.name != widget.item.name,
        onAcceptWithDetails: (details) =>
            widget.arrangement.onDrop(details.data, widget.item),
        builder: (context, candidates, rejected) => LongPressDraggable<T>(
          data: widget.item,
          feedback: Builder(builder: _buildFeedback),
          childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
          // Il "tac" lo dà _onDragStarted: quello di serie (selectionClick)
          // su molti Android è così debole che non si sente
          hapticFeedbackOnStart: false,
          onDragStarted: _onDragStarted,
          onDragUpdate: _onDragUpdate,
          onDragCompleted: () => _onDragFinished(wasDropped: true),
          onDraggableCanceled: (velocity, offset) =>
              _onDragFinished(wasDropped: false),
          child: candidates.isEmpty
              ? widget.child
              : _HighlightedTarget(child: widget.child),
        ),
      ),
    );
  }

  Widget _buildFeedback(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: SizedBox.fromSize(
          size: _tileSize ?? const Size(96, 96),
          child: Opacity(opacity: 0.9, child: widget.child),
        ),
      );

  void _onDragStarted() {
    HapticFeedback.heavyImpact();
    _isDragging = true;
    _isArranging = false;
    _arrangement = widget.arrangement;
    _onOpen = widget.onOpen;
    _tileSize = context.size;
    _autoScroller = EdgeDraggingAutoScroller(
      Scrollable.of(context),
      velocityScalar: _autoScrollVelocity,
    );
    updateKeepAlive();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final start = _pointerDownPosition ?? details.globalPosition;
    if (!_isArranging &&
        (details.globalPosition - start).distance > _arrangeDistance) {
      _startArranging();
    }
    if (!_isArranging) return;
    final size = _tileSize ?? const Size(96, 96);
    _autoScroller?.startAutoScrollIfNecessary(Rect.fromCenter(
      center: details.globalPosition,
      width: size.width,
      height: size.height,
    ));
  }

  void _startArranging() {
    _isArranging = true;
    final topBefore = _globalTop();
    _arrangement?.onStart(widget.item);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _keepUnderFinger(topBefore));
  }

  // Nell'ordinamento per reparti onStart chiude i reparti sopra a questo:
  // la casella sale, e si scorre indietro della stessa misura
  void _keepUnderFinger(double? topBefore) {
    final topAfter = _globalTop();
    if (!mounted || topBefore == null || topAfter == null) return;
    final position = Scrollable.of(context).position;
    position.jumpTo((position.pixels + topAfter - topBefore).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ));
  }

  double? _globalTop() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  void _onDragFinished({required bool wasDropped}) {
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    final wasArranging = _isArranging;
    _isArranging = false;
    _isDragging = false;
    if (mounted) updateKeepAlive();
    if (wasArranging) {
      _arrangement?.onEnd();
    } else if (!wasDropped) {
      _onOpen?.call();
    }
  }
}

class _HighlightedTarget extends StatelessWidget {
  final Widget child;

  const _HighlightedTarget({required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}
