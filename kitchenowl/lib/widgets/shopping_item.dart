import 'package:flutter/material.dart';
import 'package:kitchenowl/item_icons.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/styles/dynamic.dart';
import 'package:kitchenowl/widgets/selectable_button_card.dart';
import 'package:kitchenowl/widgets/selectable_button_list_tile.dart';

class ShoppingItemWidget<T extends Item> extends StatelessWidget {
  final T item;
  final void Function(T)? onPressed;
  final void Function(T)? onLongPressed;
  final bool selected;
  final Widget? extraOption;

  /// Only applicable if gridStyle = false, raises the list items and makes them fully opaque.
  /// defaults to true for item is ShoppinglistItem || item is RecipeItem && selected
  final bool? raised;
  final bool gridStyle;
  final ListStyle listStyle;
  final bool showIcon;

  const ShoppingItemWidget({
    super.key,
    required this.item,
    this.onPressed,
    this.onLongPressed,
    this.selected = false,
    this.gridStyle = true,
    this.listStyle = ListStyle.cards,
    this.raised,
    this.extraOption,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return gridStyle
        ? SelectableButtonCard(
            title: item.name,
            selected: selected,
            icon: showIcon ? ItemIcons.get(item) : null,
            // Se l'item ha foto allegate, la prima viene mostrata come copertina
            // al posto dell'icona/emoji nella lista della spesa.
            coverPhoto: item.coverPhoto,
            coverHash: item.coverHash,
            description: (item is ItemWithDescription)
                ? (item as ItemWithDescription).description
                : null,
            onPressed: onPressed != null ? () => onPressed!(item) : null,
            onLongPressed:
                onLongPressed != null ? () => onLongPressed!(item) : null,
            extraOption: extraOption,
          )
        : SelectableButtonListTile(
            title: item.name,
            selected: selected,
            icon: showIcon ? ItemIcons.get(item) : null,
            listStyle: listStyle,
            raised: raised ??
                item is ShoppinglistItem || item is RecipeItem && selected,
            description: (item is ItemWithDescription)
                ? (item as ItemWithDescription).description
                : null,
            onPressed: onPressed != null ? () => onPressed!(item) : null,
            onLongPressed:
                onLongPressed != null ? () => onLongPressed!(item) : null,
            extraOption: extraOption,
          );
  }
}
