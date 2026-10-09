import 'dart:async';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/enums/shoppinglist_sorting.dart';
import 'package:kitchenowl/models/category.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/models/item.dart';
import 'package:kitchenowl/models/nullable.dart';
import 'package:kitchenowl/models/shoppinglist.dart';
import 'package:kitchenowl/services/api/api_service.dart';
import 'package:kitchenowl/services/local_first/category_order.dart';
import 'package:kitchenowl/services/local_first/item_catalog.dart';
import 'package:kitchenowl/services/local_first/item_route.dart';
import 'package:kitchenowl/services/local_first/shoppinglist_search.dart';
import 'package:kitchenowl/services/storage/storage.dart';
import 'package:kitchenowl/services/transactions/category.dart';
import 'package:kitchenowl/services/transactions/shoppinglist.dart';
import 'package:kitchenowl/services/transactions/shoppinglist_arrange.dart';
import 'package:kitchenowl/services/transaction_handler.dart';

class ShoppinglistCubit extends Cubit<ShoppinglistCubitState> {
  final Household household;
  Future<void>? _refreshThread;
  String _latestSearchQuery = '';
  Timer? _periodicRefreshTimer;
  Connection? _lastConnectionState;
  StreamSubscription<List<String>>? _supersededSubscription;

  String get query => (state is SearchShoppinglistCubitState)
      ? (state as SearchShoppinglistCubitState).query
      : "";

  ShoppinglistCubit(this.household)
      : super(const LoadingShoppinglistCubitState()) {
    PreferenceStorage.getInstance().readInt(key: 'itemSorting').then((i) {
      if (i != null && state.sorting.index != i) {
        setSorting(
          ShoppinglistSorting.values[i % ShoppinglistSorting.values.length],
          false,
        );
      }
    });
    _initialLoad();
    refresh();
    ItemCatalog.getInstance().refreshFromServer(household);
    // Una modifica fatta sul telefono è stata superata da una più recente sul
    // server: si riallinea la lista (l'avviso lo mostra la pagina)
    _supersededSubscription = TransactionHandler.getInstance()
        .supersededItems
        .listen((_) => refresh());
    ApiService.getInstance().onShoppinglistAdd(onShoppinglistAdd);
    ApiService.getInstance().onShoppinglistDelete(onShoppinglistDelete);
    ApiService.getInstance().onShoppinglistItemAdd(onShoppinglistItemAdd);
    ApiService.getInstance().onShoppinglistItemRemove(onShoppinglistItemRemove);

    // Refresh data when connection state transitions to authenticated
    _lastConnectionState = ApiService.getInstance().connectionStatus;
    ApiService.getInstance().addListener(_onConnectionChange);

    // Periodic refresh as fallback for missed WebSocket events
    _periodicRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (ApiService.getInstance().isAuthenticated()) {
          refresh();
        }
      },
    );
  }

  void _onConnectionChange() {
    final current = ApiService.getInstance().connectionStatus;
    if (current == Connection.authenticated &&
        _lastConnectionState != Connection.authenticated) {
      refresh();
      ItemCatalog.getInstance().refreshFromServer(household);
    }
    _lastConnectionState = current;
  }

  @override
  Future<void> close() async {
    _periodicRefreshTimer?.cancel();
    _supersededSubscription?.cancel();
    ApiService.getInstance().removeListener(_onConnectionChange);
    ApiService.getInstance().offShoppinglistAdd(onShoppinglistAdd);
    ApiService.getInstance().offShoppinglistDelete(onShoppinglistDelete);
    ApiService.getInstance().offShoppinglistItemAdd(onShoppinglistItemAdd);
    ApiService.getInstance()
        .offShoppinglistItemRemove(onShoppinglistItemRemove);
    super.close();
  }

  void onShoppinglistAdd(dynamic data) {
    refresh();
  }

  void onShoppinglistDelete(dynamic data) {
    refresh();
  }

  void onShoppinglistItemAdd(dynamic data) {
    final item = ShoppinglistItem.fromJson(data["item"]);
    ItemCatalog.getInstance()
        .remember(household, Map<String, dynamic>.from(data["item"]));
    TransactionHandler.getInstance().runTransaction(
      TransactionShoppingListAddItem(
        household: household,
        shoppinglist: ShoppingList.fromJson(data["shoppinglist"]),
        item: item,
      ),
      forceOffline: true,
      saveTransaction: false,
    );
    addLocally(
      ShoppinglistItem.fromJson(data["item"]),
      data["shoppinglist"]["id"],
    );
  }

  void onShoppinglistItemRemove(dynamic data) {
    final item = ShoppinglistItem.fromJson(data["item"]);
    TransactionHandler.getInstance().runTransaction(
      TransactionShoppingListRemoveItem(
        household: household,
        shoppinglist: ShoppingList.fromJson(data["shoppinglist"]),
        item: item,
      ),
      forceOffline: true,
      saveTransaction: false,
    );
    removeLocally(item, data["shoppinglist"]["id"]);
  }

  /// Ricerca tutta sul telefono, nessuna richiesta di rete (feature
  /// 001-local-first). Se nel frattempo è partita una ricerca più nuova, il
  /// risultato di questa si scarta.
  Future<void> search(String query) async {
    _latestSearchQuery = query;
    if (query.trim().isEmpty) {
      _leaveSearch();
      return;
    }
    final result = await searchShoppinglistLocally(
      household,
      query,
      state.selectedShoppinglist,
    );
    if (query != _latestSearchQuery) return;
    emit(SearchShoppinglistCubitState(
      shoppinglists: state.shoppinglists,
      selectedShoppinglistId: state.selectedShoppinglistId,
      categories: state.categories,
      sorting: state.sorting,
      selectedListItems: state.selectedListItems,
      query: query,
      result: result,
    ));
  }

  void _leaveSearch() {
    _latestSearchQuery = '';
    if (state is! SearchShoppinglistCubitState) return;
    emit(ShoppinglistCubitState(
      shoppinglists: state.shoppinglists,
      selectedShoppinglistId: state.selectedShoppinglistId,
      categories: state.categories,
      sorting: state.sorting,
      selectedListItems: state.selectedListItems,
    ));
  }

  /// Invio nel campo di ricerca (scelta dell'articolo in itemToAddOnSubmit).
  /// I risultati si ricalcolano qui invece di leggerli dallo stato, che può
  /// essere ancora quello di un testo precedente (la ricerca parte 200 ms
  /// dopo l'ultima lettera) o già svuotato dal campo di ricerca.
  Future<void> addFromSearch(String query) async {
    if (query.trim().isEmpty) return;
    final results = await searchShoppinglistLocally(
      household,
      query,
      state.selectedShoppinglist,
    );
    final item = itemToAddOnSubmit(results, query);
    if (item != null) await add(item);
  }

  Future<void> add(Item item) async {
    final _state = state;
    addLocally(ShoppinglistItem.fromItem(item: item));
    if (_state.selectedShoppinglist == null) return;
    await TransactionHandler.getInstance()
        .runTransaction(TransactionShoppingListAddItem(
      household: household,
      shoppinglist: _state.selectedShoppinglist!,
      item: item,
    ));
    _leaveSearch();
  }

  void addLocally(ShoppinglistItem item, [int? shoppinglistId]) {
    final _state = state;
    shoppinglistId ??= _state.selectedShoppinglist?.id;
    if (shoppinglistId == null) return;
    final shoppinglist = _state.shoppinglists[shoppinglistId];
    if (shoppinglist == null) return;

    final l = List.of(shoppinglist.items);
    l.removeWhere((e) => e.id == item.id || e.name == item.name);
    l.add(item);
    ShoppinglistSorting.sortShoppinglistItems(l, state.sorting);
    final recent = List.of(shoppinglist.recentItems);
    recent.removeWhere((e) => e.name == item.name);
    if (_state is SearchShoppinglistCubitState) {
      final result = List.of(_state.result);
      final index = result.indexWhere((e) => e.id == item.id);
      if (index >= 0) {
        result.removeAt(index);
        result.insert(
          index,
          item,
        );
      }
      emit(_state.copyWith(
        shoppinglists: _replaceAndUpdateShoppingLists(_state.shoppinglists,
            shoppinglist.copyWith(items: l, recentItems: recent)),
        result: result,
      ));
    } else {
      emit(state.copyWith(
        shoppinglists: _replaceAndUpdateShoppingLists(_state.shoppinglists,
            shoppinglist.copyWith(items: l, recentItems: recent)),
      ));
    }
  }

  Future<void> remove(ShoppinglistItem item) async {
    final _state = state;
    removeLocally(item);
    if (!await TransactionHandler.getInstance()
        .runTransaction(TransactionShoppingListRemoveItem(
      household: household,
      shoppinglist: _state.selectedShoppinglist!,
      item: item,
    ))) {
      await refresh();
    }
  }

  void removeLocally(ShoppinglistItem item, [int? shoppinglistId]) {
    final _state = state;
    shoppinglistId ??= _state.selectedShoppinglist?.id;
    if (shoppinglistId == null) return;
    final shoppinglist = _state.shoppinglists[shoppinglistId];
    if (shoppinglist == null) return;

    final l = List.of(shoppinglist.items);
    l.removeWhere((e) => e.name == item.name);
    final recent = List.of(shoppinglist.recentItems);
    recent.removeWhere((e) => e.name == item.name);
    recent.insert(0, ItemWithDescription.fromItem(item: item));
    if (_state is SearchShoppinglistCubitState) {
      final result = List.of(_state.result);
      final index = result.indexOf(item);
      if (index >= 0) {
        result.removeAt(index);
        result.insert(
          index,
          ItemWithDescription.fromItem(
            item: item,
            description: item.description,
          ),
        );
      }
      emit(_state.copyWith(
          shoppinglists: _replaceAndUpdateShoppingLists(_state.shoppinglists,
              shoppinglist.copyWith(items: l, recentItems: recent)),
          result: result));
    } else {
      emit(state.copyWith(
        shoppinglists: _replaceAndUpdateShoppingLists(_state.shoppinglists,
            shoppinglist.copyWith(items: l, recentItems: recent)),
      ));
    }
  }

  void selectItem(ShoppinglistItem item) {
    final l = List.of(state.selectedListItems);
    if (l.contains(item)) {
      l.remove(item);
    } else {
      l.insert(0, item);
    }
    emit(state.copyWith(selectedListItems: l));
  }

  Future<void> confirmRemove() async {
    final _state = state;
    if (_state.selectedShoppinglist == null ||
        _state.selectedListItems.isEmpty) {
      return;
    }
    final selectedItems = _state.selectedListItems
        .sorted((a, b) => a.id?.compareTo(b.id ?? 0) ?? -1);
    final l = List.of(_state.selectedShoppinglist!.items);
    l.removeWhere(selectedItems.contains);
    final recent = List.of(_state.selectedShoppinglist!.recentItems);
    recent.insertAll(
      0,
      selectedItems.map((e) => ItemWithDescription.fromItem(item: e)),
    );

    if (_state is SearchShoppinglistCubitState) {
      final result = List.of(_state.result);
      for (final item in selectedItems) {
        final index = result.indexOf(item);
        if (index >= 0) {
          result.removeAt(index);
          result.insert(
            index,
            ItemWithDescription.fromItem(item: item),
          );
        }
      }
      emit(_state.copyWith(
        shoppinglists: _replaceAndUpdateShoppingLists(
            _state.shoppinglists,
            _state.selectedShoppinglist!
                .copyWith(items: l, recentItems: recent)),
        result: result,
        selectedListItems: [],
      ));
    } else {
      emit(_state.copyWith(
          shoppinglists: _replaceAndUpdateShoppingLists(
              _state.shoppinglists,
              _state.selectedShoppinglist!
                  .copyWith(items: l, recentItems: recent)),
          selectedListItems: []));
    }
    if (!await TransactionHandler.getInstance()
        .runTransaction(TransactionShoppingListRemoveItems(
      household: household,
      shoppinglist: _state.selectedShoppinglist!,
      items: selectedItems,
    ))) {
      await refresh();
    }
  }

  /// Trascinamento su un altro articolo (feature 004-riordino-trascinamento):
  /// se l'articolo scendeva finisce subito dopo target, se saliva subito
  /// prima. Il gruppo che il server ricorda per l'analisi notturna è tutta la
  /// lista, o solo il reparto di target nell'ordinamento per reparti.
  Future<void> arrangeItem(
    ShoppinglistItem moved,
    ShoppinglistItem target,
  ) async {
    final shoppinglist = state.selectedShoppinglist;
    if (shoppinglist == null || moved.name == target.name) return;
    final isByCategory = state.sorting == ShoppinglistSorting.category;
    final group = shoppinglist.items
        .where((e) => !isByCategory || isSameCategory(e.category, target.category))
        .sorted(compareByRoute);
    final isMovingDown = group.indexWhere((e) => e.name == moved.name) <
        group.indexWhere((e) => e.name == target.name);
    final after = isMovingDown ? target : null;
    final before = isMovingDown ? null : target;
    await _arrange(TransactionShoppingListArrangeItem(
      household: household,
      shoppinglist: shoppinglist,
      item: moved,
      after: after,
      before: before,
      route: placeInRoute(
        group,
        movedName: moved.name,
        afterName: after?.name,
        beforeName: before?.name,
      ),
    ));
  }

  /// Trascinamento sulla riga di un reparto (feature 004): il cambio di
  /// reparto è dell'articolo, quindi vale per sempre e non solo in questa
  /// lista. category null vuol dire "Uncategorized".
  Future<void> moveItemToCategory(
    ShoppinglistItem moved,
    Category? category,
  ) async {
    final shoppinglist = state.selectedShoppinglist;
    if (shoppinglist == null || isSameCategory(moved.category, category)) {
      return;
    }
    await _arrange(TransactionShoppingListArrangeItem(
      household: household,
      shoppinglist: shoppinglist,
      item: moved,
      category: Nullable(category),
    ));
  }

  /// Trascinamento di un reparto su un altro (feature 005-reparti-dalla-lista):
  /// prende la sua posizione, quindi finisce subito dopo se scendeva e subito
  /// prima se saliva. Vale per tutta la casa, come dalle impostazioni.
  Future<void> arrangeCategory(Category moved, Category target) async {
    final index =
        state.categories.indexWhere((e) => isSameCategory(e, target));
    if (index < 0 || isSameCategory(moved, target)) return;
    emit(state.copyWith(
      categories: moveCategory(state.categories, moved: moved, index: index),
    ));
    await TransactionHandler.getInstance().runTransaction(
      TransactionCategoryArrange(
        household: household,
        category: moved,
        index: index,
      ),
    );
  }

  /// Reparto nuovo dal pannello del pulsante casa (feature 005): va in fondo.
  Future<void> addCategory(String name) async {
    emit(state.copyWith(
      categories: addCategoryNamed(state.categories, name),
    ));
    await TransactionHandler.getInstance().runTransaction(
      TransactionCategoryAdd(household: household, name: name.trim()),
    );
  }

  Future<void> _arrange(TransactionShoppingListArrangeItem transaction) async {
    final items = arrangeItems(
      transaction.shoppinglist.items,
      movedName: transaction.item.name,
      afterName: transaction.after?.name,
      beforeName: transaction.before?.name,
      category: transaction.category,
    );
    ShoppinglistSorting.sortShoppinglistItems(items, state.sorting);
    emit(state.copyWith(
      shoppinglists: _replaceAndUpdateShoppingLists(
        state.shoppinglists,
        transaction.shoppinglist.copyWith(items: items),
      ),
      // La selezione confronta gli articoli per valore: si riprendono quelli
      // nuovi, altrimenti un articolo selezionato e rinumerato si deseleziona
      selectedListItems: state.selectedListItems
          .map((e) => items.firstWhereOrNull((item) => item.name == e.name))
          .nonNulls
          .toList(),
    ));
    await TransactionHandler.getInstance().runTransaction(transaction);
  }

  void incrementSorting() {
    setSorting(ShoppinglistSorting
        .values[(state.sorting.index + 1) % ShoppinglistSorting.values.length]);
  }

  void setSorting(ShoppinglistSorting sorting, [bool savePreference = true]) {
    if (state is! SearchShoppinglistCubitState &&
        state.selectedShoppinglist != null &&
        state.selectedShoppinglist?.items != const []) {
      state.shoppinglists.forEach((_, l) =>
          ShoppinglistSorting.sortShoppinglistItems(l.items, sorting));
    }
    if (savePreference) {
      PreferenceStorage.getInstance()
          .writeInt(key: 'itemSorting', value: sorting.index);
    }
    emit(state.copyWith(sorting: sorting));
  }

  void setShoppingList(ShoppingList shoppingList) {
    if (shoppingList.id != null) {
      PreferenceStorage.getInstance().writeInt(
        key: 'selectedShoppinglist',
        value: shoppingList.id!,
      );
    }
    emit(state.copyWith(
      selectedListItems:
          shoppingList.id != state.selectedShoppinglistId ? [] : null,
      selectedShoppinglistId: shoppingList.id,
    ));
  }

  /// Allinea la copia sul telefono al server, in sottofondo: lo schermo
  /// mostra già la copia locale e non aspetta mai questa chiamata. Prima si
  /// consegnano le azioni in coda, poi si scarica la lista dal server e ci si
  /// riapplicano sopra le azioni ancora non consegnate. Con query == '' si
  /// esce anche dalla ricerca. Più chiamate ravvicinate condividono la stessa
  /// sincronizzazione.
  Future<void> refresh({String? query}) {
    if (query != null && query.isEmpty) _leaveSearch();
    return _refreshThread ??=
        _refresh().whenComplete(() => _refreshThread = null);
  }

  Future<Map<int, ShoppingList>> fetchShoppingLists(
      [bool forceOffline = false]) async {
    final shoppingLists = await TransactionHandler.getInstance()
        .runTransaction(
          TransactionShoppingListGet(household: household),
          forceOffline: forceOffline,
        )
        .then((lists) => Map.fromEntries(lists
            .map((e) => e.id != null ? MapEntry(e.id!, e) : null)
            .nonNulls));

    shoppingLists.forEach((_, l) =>
        ShoppinglistSorting.sortShoppinglistItems(l.items, state.sorting));

    return shoppingLists;
  }

  Future<List<Category>> fetchCategories([bool forceOffline = false]) {
    return TransactionHandler.getInstance().runTransaction(
      TransactionCategoriesGet(household: household),
      forceOffline: forceOffline,
    );
  }

  Future<void> _initialLoad() async {
    final shoppingLists = await fetchShoppingLists(true);

    ShoppingList? shoppingList = state.selectedShoppinglist;
    if (await PreferenceStorage.getInstance()
            .readBool(key: "restoreLastShoppingList") ??
        false) {
      int? id = await PreferenceStorage.getInstance()
          .readInt(key: "selectedShoppinglist");
      if (id != null) {
        shoppingList ??=
            shoppingLists.values.firstWhereOrNull((s) => s.id == id);
      }
    }
    shoppingList ??= shoppingLists.values.firstOrNull;

    if (shoppingList == null) return;

    Future<List<Category>> categories = fetchCategories(true);

    // La copia locale è già la lista vera (feature 001-local-first): si
    // mostra come pronta, senza segnaposto di caricamento
    final resState = ShoppinglistCubitState(
      shoppinglists: shoppingLists,
      selectedShoppinglistId: shoppingList.id,
      categories: await categories,
      sorting: state.sorting,
      selectedListItems: state.selectedListItems
          .map((e) =>
              shoppingList!.items.firstWhereOrNull((item) => item.id == e.id))
          .nonNulls
          .toList(),
    );

    if (state is LoadingShoppinglistCubitState) {
      emit(resState);
    }
  }

  Future<void> _refresh() async {
    if (state.selectedShoppinglistId == null &&
        state is! LoadingShoppinglistCubitState) {
      emit(LoadingShoppinglistCubitState(
        sorting: state.sorting,
        categories: state.categories,
      ));
    }

    await TransactionHandler.getInstance().runOpenTransactions();
    // Anche le azioni sui reparti ancora in coda (features/005) vanno
    // riapplicate sopra i reparti freschi: si aspettano prima del replay
    final freshCategories = fetchCategories();
    await fetchShoppingLists();
    await freshCategories;
    await TransactionHandler.getInstance().replayPending(household);
    final shoppingLists = await fetchShoppingLists(true);
    final categories = fetchCategories(true);

    int? selectedShoppinglistId = state.selectedShoppinglistId;
    if (selectedShoppinglistId != null &&
        !shoppingLists.containsKey(selectedShoppinglistId)) {
      selectedShoppinglistId = null;
    }
    selectedShoppinglistId ??= shoppingLists.values.firstOrNull?.id;
    if (selectedShoppinglistId == null) return;
    final shoppinglist = shoppingLists[selectedShoppinglistId];

    final selectedListItems = state.selectedListItems
        .map((e) =>
            shoppinglist?.items.firstWhereOrNull((item) => item.id == e.id))
        .nonNulls
        .toList();
    final current = state;
    // Durante una ricerca si resta in ricerca: uno stato normale farebbe
    // svuotare la casella di ricerca alla pagina mentre Andrea scrive
    if (current is SearchShoppinglistCubitState) {
      emit(SearchShoppinglistCubitState(
        shoppinglists: shoppingLists,
        selectedShoppinglistId: selectedShoppinglistId,
        categories: await categories,
        sorting: current.sorting,
        selectedListItems: selectedListItems,
        query: current.query,
        result: current.result,
      ));
      await search(current.query);
      return;
    }
    emit(ShoppinglistCubitState(
      shoppinglists: shoppingLists,
      selectedShoppinglistId: selectedShoppinglistId,
      categories: await categories,
      sorting: current.sorting,
      selectedListItems: selectedListItems,
    ));
  }

  Map<int, ShoppingList> _replaceAndUpdateShoppingLists(
      Map<int, ShoppingList> shoppinglists, ShoppingList shoppingList) {
    if (shoppingList.id == null) return shoppinglists;

    final res = Map.of(shoppinglists);
    res[shoppingList.id!] = shoppingList;
    return res;
  }
}

class ShoppinglistCubitState extends Equatable {
  final Map<int, ShoppingList> shoppinglists;
  final int? selectedShoppinglistId;
  final List<Category> categories;
  final ShoppinglistSorting sorting;
  final List<ShoppinglistItem> selectedListItems;
  final ShoppingList? _selectedShoppinglist;

  const ShoppinglistCubitState._({
    this.shoppinglists = const {},
    this.categories = const [],
    this.sorting = ShoppinglistSorting.alphabetical,
    this.selectedListItems = const [],
    this.selectedShoppinglistId = null,
  }) : this._selectedShoppinglist = null;

  ShoppinglistCubitState({
    this.shoppinglists = const {},
    required this.selectedShoppinglistId,
    this.categories = const [],
    this.sorting = ShoppinglistSorting.alphabetical,
    this.selectedListItems = const [],
  }) : _selectedShoppinglist = shoppinglists[selectedShoppinglistId];

  ShoppingList? get selectedShoppinglist => _selectedShoppinglist;

  ShoppinglistCubitState copyWith({
    Map<int, ShoppingList>? shoppinglists,
    int? selectedShoppinglistId,
    List<Category>? categories,
    ShoppinglistSorting? sorting,
    List<ShoppinglistItem>? selectedListItems,
  }) =>
      ShoppinglistCubitState(
        shoppinglists: shoppinglists ?? this.shoppinglists,
        selectedShoppinglistId:
            selectedShoppinglistId ?? this.selectedShoppinglistId,
        categories: categories ?? this.categories,
        sorting: sorting ?? this.sorting,
        selectedListItems: selectedListItems ?? this.selectedListItems,
      );

  @override
  List<Object?> get props => [
        shoppinglists,
        selectedShoppinglistId,
        categories,
        sorting,
        selectedListItems,
      ];
}

class LoadingShoppinglistCubitState extends ShoppinglistCubitState {
  const LoadingShoppinglistCubitState({
    super.sorting,
    super.selectedShoppinglistId,
    super.shoppinglists,
    super.categories,
    super.selectedListItems,
  }) : super._();

  @override
  ShoppinglistCubitState copyWith({
    Map<int, ShoppingList>? shoppinglists,
    int? selectedShoppinglistId,
    List<ShoppinglistItem>? listItems,
    List<ItemWithDescription>? recentItems,
    List<Category>? categories,
    ShoppinglistSorting? sorting,
    List<ShoppinglistItem>? selectedListItems,
  }) =>
      LoadingShoppinglistCubitState(
        sorting: sorting ?? this.sorting,
        shoppinglists: shoppinglists ?? this.shoppinglists,
        selectedShoppinglistId:
            selectedShoppinglistId ?? this.selectedShoppinglistId,
        categories: categories ?? this.categories,
        selectedListItems: selectedListItems ?? this.selectedListItems,
      );
}

class SearchShoppinglistCubitState extends ShoppinglistCubitState {
  final String query;
  final List<Item> result;

  SearchShoppinglistCubitState({
    super.shoppinglists = const {},
    required super.selectedShoppinglistId,
    super.categories = const [],
    super.sorting = ShoppinglistSorting.alphabetical,
    this.query = "",
    this.result = const [],
    super.selectedListItems,
  });

  @override
  ShoppinglistCubitState copyWith({
    Map<int, ShoppingList>? shoppinglists,
    int? selectedShoppinglistId,
    List<Category>? categories,
    ShoppinglistSorting? sorting,
    List<Item>? result,
    List<ShoppinglistItem>? selectedListItems,
  }) =>
      SearchShoppinglistCubitState(
        shoppinglists: shoppinglists ?? this.shoppinglists,
        selectedShoppinglistId:
            selectedShoppinglistId ?? this.selectedShoppinglistId,
        sorting: sorting ?? this.sorting,
        categories: categories ?? this.categories,
        query: query,
        result: result ?? this.result,
        selectedListItems: selectedListItems ?? this.selectedListItems,
      );

  @override
  List<Object?> get props => super.props + [result, query];
}
