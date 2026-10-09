import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/household_cubit.dart';
import 'package:kitchenowl/enums/update_enum.dart';
import 'package:kitchenowl/helpers/build_context_extension.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/models/update_value.dart';
import 'package:kitchenowl/pages/item_page.dart';
import 'package:kitchenowl/widgets/shopping_item.dart';
import 'package:kitchenowl/widgets/shopping_list/arrangeable_item.dart';

/// A Sliver Grid or List depending on the shopping list style
class SliverItemGridList<T extends Item> extends StatelessWidget {
  final void Function()? onRefresh;
  final Nullable<void Function(T)>? onPressed;
  final Nullable<void Function(T)>? onLongPressed;
  final List<T> items;
  final List<Category>? categories; // forwarded to item page on long press
  final ShoppingList? shoppingList; // forwarded to item page on long press
  final bool Function(T)? selected;
  final bool isLoading;
  final Widget Function(T)? extraOption;
  final ShoppingListStyle shoppingListStyle;

  /// Se c'è, le caselle si possono trascinare (features/004): la pressione
  /// lunga la gestisce ArrangeableItem, che apre la scheda se il dito non si
  /// è mosso.
  final ItemArrangement<T>? arrangement;

  const SliverItemGridList({
    super.key,
    this.onRefresh,
    this.onPressed,
    this.onLongPressed,
    this.items = const [],
    this.categories,
    this.shoppingList,
    this.selected,
    this.isLoading = false,
    this.extraOption,
    this.shoppingListStyle = const ShoppingListStyle(),
    this.arrangement,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && items.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox(height: 0));
    }

    final delegate = SliverChildBuilderDelegate(
      childCount: items.length + (isLoading ? 1 : 0),
      (context, i) => i >= items.length
          ? ShimmerShoppingItemWidget(
              key: ValueKey(i),
              gridStyle: !shoppingListStyle.isList,
            )
          : _buildTile(context, items[i]),
    );

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: !shoppingListStyle.isList
          ? SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: DynamicStyling.itemCrossAxisCount(
                    constraints.crossAxisExtent,
                    shoppingListStyle.gridSize,
                  ),
                  childAspectRatio: 1,
                ),
                delegate: delegate,
              ),
            )
          : SliverList(delegate: delegate),
    );
  }

  Widget _buildTile(BuildContext context, T item) {
    final arrangement = this.arrangement;
    final tile = ShoppingItemWidget<T>(
      key: ObjectKey(item),
      item: item,
      selected: selected?.call(item) ?? false,
      gridStyle: !shoppingListStyle.isList,
      listStyle: shoppingListStyle.listStyle,
      onPressed:
          (onPressed ?? Nullable((item) => openMenu(context, item))).value,
      raised: shoppingListStyle.allRaised,
      onLongPressed: arrangement != null
          ? null
          : (onLongPressed ?? Nullable((item) => openMenu(context, item)))
              .value,
      extraOption: extraOption?.call(item),
    );
    if (arrangement == null) return tile;

    // Chiave per nome e non per oggetto: un aggiornamento della lista durante
    // il trascinamento non deve ricreare la casella trascinata
    return ArrangeableItem<T>(
      key: ValueKey(item.name),
      item: item,
      arrangement: arrangement,
      onOpen: () => openMenu(context, item),
      child: tile,
    );
  }

  Future<void> openMenu(BuildContext context, Item item) async {
    final res = await Navigator.of(context, rootNavigator: true)
        .push<UpdateValue<Item>>(
      MaterialPageRoute(builder: (ctx) {
        Widget page = ItemPage(
          item: item,
          shoppingList: shoppingList,
          categories: categories ?? const [],
          advancedView: shoppingListStyle.advancedItemView,
        );
        final householdCubit = context.readOrNull<HouseholdCubit>();
        if (householdCubit != null)
          page = BlocProvider.value(
            value: householdCubit,
            child: page,
          );

        return page;
      }),
    );
    if (onRefresh != null &&
        res != null &&
        (res.state == UpdateEnum.deleted || res.state == UpdateEnum.updated)) {
      onRefresh!();
    }
  }
}
