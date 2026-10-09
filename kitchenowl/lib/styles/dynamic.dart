enum GridSize {
  small,
  normal,
  large,
}

enum ListStyle {
  minimalist,
  cards,
}

class DynamicStyling {
  static int itemCrossAxisCount(double availableSpace, GridSize? sizing) =>
      (availableSpace ~/ 115).clamp(1, 9) - ((sizing?.index ?? 1) - 1);
}

class ShoppingListStyle {
  final bool advancedItemView;
  final bool isList;
  final bool? allRaised;
  final GridSize gridSize;
  final ListStyle listStyle;

  /// Caselle col solo nome, senza icona (features/006-icone-nascoste).
  final bool hideIcons;

  const ShoppingListStyle({
    this.advancedItemView = false,
    this.isList = false,
    this.allRaised,
    this.gridSize = GridSize.normal,
    this.listStyle = ListStyle.cards,
    this.hideIcons = false,
  });
}
