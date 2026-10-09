/// Scorrimento della lista mentre si trascina un reparto (feature
/// 005-reparti-dalla-lista del fork di Andrea). Quando i reparti si chiudono
/// in righe la lista si accorcia: start porta la riga del reparto trascinato
/// (quella con originRowKey) sotto il dito. follow fa scorrere la lista da
/// sola quando il reparto si avvicina al bordo alto o basso; lo chiamano le
/// righe con i loro spostamenti, perché il nome da cui è partito il
/// trascinamento a quel punto non c'è più. stop ferma tutto a fine
/// trascinamento.
library;

import 'package:flutter/widgets.dart';

class CategoryDragScroll {
  // La stessa velocità dello scorrimento degli articoli (ArrangeableItem)
  static const double _autoScrollVelocity = 50;
  static const double _rowHeight = 56;

  final GlobalKey originRowKey = GlobalKey();
  EdgeDraggingAutoScroller? _autoScroller;

  void start(ScrollableState scrollable, double fingerY) {
    _autoScroller = EdgeDraggingAutoScroller(
      scrollable,
      velocityScalar: _autoScrollVelocity,
    );
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _bringOriginUnder(scrollable, fingerY));
  }

  void follow(Offset feedbackTopLeft, double width) {
    _autoScroller?.startAutoScrollIfNecessary(
      feedbackTopLeft & Size(width, _rowHeight),
    );
  }

  void stop() {
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
  }

  void _bringOriginUnder(ScrollableState scrollable, double fingerY) {
    final row = originRowKey.currentContext?.findRenderObject();
    if (row is! RenderBox || !row.attached) return;
    final rowCenter = row.localToGlobal(row.size.center(Offset.zero)).dy;
    final position = scrollable.position;
    position.jumpTo((position.pixels + rowCenter - fingerY).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ));
  }
}
