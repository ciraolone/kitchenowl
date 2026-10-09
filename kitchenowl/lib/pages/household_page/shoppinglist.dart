import 'dart:async';

import 'package:animations/animations.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/cubits/settings_cubit.dart';
import 'package:kitchenowl/cubits/shoppinglist_cubit.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/pages/household_page/add_item_shortcut_focus.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/widgets/choice_scroll.dart';
import 'package:kitchenowl/widgets/shopping_list/shopping_list_choice_chip.dart';
import 'package:kitchenowl/widgets/shopping_list/shopping_list_search_actions.dart';
import 'package:kitchenowl/widgets/shopping_list/sliver_shopinglist_item_view.dart';
import 'package:kitchenowl/services/transaction_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ShoppinglistPage extends StatefulWidget {
  const ShoppinglistPage({super.key});

  @override
  _ShoppinglistPageState createState() => _ShoppinglistPageState();
}

class _ShoppinglistPageState extends State<ShoppinglistPage>
    with AddItemShortcutFocus {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  StreamSubscription<List<String>>? _supersededSubscription;

  @override
  void initState() {
    super.initState();
    _supersededSubscription = TransactionHandler.getInstance()
        .supersededItems
        .listen(_showSupersededNotice);
    searchController.text = BlocProvider.of<ShoppinglistCubit>(context).query;
    if (BlocProvider.of<SettingsCubit>(context).state.shoppingListKeepAwake) {
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _supersededSubscription?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    focusOnAddItemShortcut(searchFocusNode);
  }

  // Modifiche fatte sul telefono che il server ha scartato perché ne aveva
  // una più recente (feature 001-local-first): la lista è già riallineata,
  // qui si dice solo ad Andrea quali articoli
  void _showSupersededNotice(List<String> itemNames) {
    if (!mounted) return;
    showSnackbar(
      context: context,
      width: null,
      duration: const Duration(seconds: 5),
      content: Text(AppLocalizations.of(context)!
          .shoppingListChangeSuperseded(itemNames.join(', '))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = BlocProvider.of<ShoppinglistCubit>(context);

    return SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 70,
            child: Padding(
              // A destra 8 e non 16: i pulsanti hanno già il loro margine
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child:
                        BlocListener<ShoppinglistCubit, ShoppinglistCubitState>(
                      bloc: cubit,
                      listener: (context, state) {
                        if (state is! SearchShoppinglistCubitState &&
                            state is! LoadingShoppinglistCubitState) {
                          if (searchController.text.isNotEmpty) {
                            searchController.clear();
                          }
                        }
                      },
                      child: SearchTextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onSearch: (s) => cubit.search(s),
                        onSubmitted: () =>
                            cubit.addFromSearch(searchController.text),
                      ),
                    ),
                  ),
                  const ShoppingListSearchActions(),
                ],
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<ShoppinglistCubit, ShoppinglistCubitState>(
              bloc: cubit,
              builder: (context, state) {
                final header = (state.shoppinglists.length < 2)
                    ? const SizedBox()
                    : ChoiceScroll(
                        children: state.shoppinglists.values
                            .sorted((a, b) =>
                                b.items.length.compareTo(a.items.length))
                            .map(
                              (shoppinglist) => ShoppingListChoiceChip(
                                shoppingList: shoppinglist,
                                selected: shoppinglist.id ==
                                    state.selectedShoppinglistId,
                                onSelected: (bool selected) {
                                  if (selected) {
                                    cubit.setShoppingList(
                                      shoppinglist,
                                    );
                                  }
                                },
                              ),
                            )
                            .toList(),
                      );

                if (state is! SearchShoppinglistCubitState &&
                    state is! LoadingShoppinglistCubitState &&
                    (state.selectedShoppinglist?.items.isEmpty ?? true) &&
                    ((state.selectedShoppinglist?.recentItems.isEmpty ??
                            true) ||
                        (App.settings.recentItemsCount == 0))) {
                  return Column(
                    children: [
                      header,
                      const Spacer(),
                      const Icon(Icons.remove_shopping_cart_rounded),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.shoppingListEmpty,
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                    ],
                  );
                }
                return BlocBuilder<SettingsCubit, SettingsState>(
                  buildWhen: (previous, current) =>
                      previous.shoppingListListView !=
                          current.shoppingListListView ||
                      previous.listStyle != current.listStyle ||
                      previous.gridSize != current.gridSize,
                  builder: (context, settingsState) => PageTransitionSwitcher(
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                      Animation<double> secondaryAnimation,
                    ) {
                      return SharedAxisTransition(
                        animation: animation,
                        secondaryAnimation: secondaryAnimation,
                        transitionType: SharedAxisTransitionType.vertical,
                        child: child,
                      );
                    },
                    child: (state is SearchShoppinglistCubitState)
                        ? RefreshIndicator(
                            onRefresh: cubit.refresh,
                            child: CustomScrollView(
                              primary: true,
                              slivers: [
                                SliverItemGridList(
                                  shoppingListStyle: ShoppingListStyle(
                                    listStyle: settingsState.listStyle,
                                    isList: settingsState.shoppingListListView,
                                    gridSize: settingsState.gridSize,
                                  ),
                                  items: state.result,
                                  categories: state.categories,
                                  shoppingList: state.selectedShoppinglist,
                                  onRefresh: () => cubit.refresh(),
                                  selected: (item) =>
                                      item is ShoppinglistItem &&
                                      (App.settings.shoppingListTapToRemove ||
                                          !state.selectedListItems
                                              .contains(item)),
                                  isLoading:
                                      state is LoadingShoppinglistCubitState,
                                  // Il tocco spunta/aggiunge; la pressione
                                  // lunga resta libera e apre la scheda
                                  // (default di SliverItemGridList).
                                  onPressed: Nullable((Item item) {
                                    if (item is ShoppinglistItem) {
                                      if (App
                                          .settings.shoppingListTapToRemove) {
                                        cubit.remove(item);
                                      } else {
                                        cubit.selectItem(item);
                                      }
                                    } else {
                                      cubit.add(item);
                                    }
                                  }),
                                ),
                              ],
                            ),
                          )
                        : NestedScrollView(
                            headerSliverBuilder:
                                (context, innerBoxIsScrolled) => [
                              SliverToBoxAdapter(child: header),
                            ],
                            body: RefreshIndicator(
                              onRefresh: cubit.refresh,
                              displacement: 0,
                              child: PageTransitionSwitcher(
                                transitionBuilder: (
                                  Widget child,
                                  Animation<double> animation,
                                  Animation<double> secondaryAnimation,
                                ) {
                                  return SharedAxisTransition(
                                    animation: animation,
                                    secondaryAnimation: secondaryAnimation,
                                    transitionType:
                                        SharedAxisTransitionType.vertical,
                                    child: child,
                                  );
                                },
                                child: CustomScrollView(
                                  key: PageStorageKey<int?>(
                                      state.selectedShoppinglistId),
                                  slivers: [
                                    SliverShopinglistItemView(
                                      shoppingListStyle: ShoppingListStyle(
                                        listStyle: settingsState.listStyle,
                                        isList:
                                            settingsState.shoppingListListView,
                                        gridSize: settingsState.gridSize,
                                      ),
                                      categories: state.categories,
                                      isLoading: state
                                          is LoadingShoppinglistCubitState,
                                      selectedListItems:
                                          state.selectedListItems,
                                      sorting: state.sorting,
                                      shoppingList: state.selectedShoppinglist,
                                      // Il tocco spunta o seleziona; la
                                      // pressione lunga apre la scheda
                                      // (default di SliverItemGridList).
                                      onPressed:
                                          Nullable((ShoppinglistItem item) {
                                        if (App
                                            .settings.shoppingListTapToRemove) {
                                          cubit.remove(item);
                                        } else {
                                          cubit.selectItem(item);
                                        }
                                      }),
                                      onRecentPressed: Nullable(cubit.add),
                                      onRefresh: cubit.refresh,
                                      onArrange: cubit.arrangeItem,
                                      onMoveToCategory:
                                          cubit.moveItemToCategory,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
