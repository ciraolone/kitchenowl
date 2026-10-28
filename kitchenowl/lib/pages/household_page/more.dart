import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:kitchenowl/app.dart';
import 'package:kitchenowl/cubits/auth_cubit.dart';
import 'package:kitchenowl/cubits/household_cubit.dart';
import 'package:kitchenowl/cubits/household_list_cubit.dart';
import 'package:kitchenowl/cubits/shoppinglist_cubit.dart';
import 'package:kitchenowl/enums/update_enum.dart';
import 'package:kitchenowl/enums/views_enum.dart';
import 'package:kitchenowl/kitchenowl.dart';
import 'package:kitchenowl/models/household.dart';
import 'package:kitchenowl/pages/household_update_page.dart';
import 'package:kitchenowl/widgets/household_image.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  /// Pannello del pulsante negozio: elenco dei negozi per passare dall'uno
  /// all'altro con un tocco (feature 007), profilo, impostazioni e reparto
  /// nuovo (features/005, per questo serve ShoppinglistCubit). Lo
  /// aprono la barra laterale e il pulsante accanto alla ricerca della lista.
  static void show(
    BuildContext context,
    HouseholdCubit householdCubit,
    ShoppinglistCubit shoppinglistCubit,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: householdCubit),
          BlocProvider.value(value: shoppinglistCubit),
        ],
        child: const MorePage(),
      ),
    );
  }

  static Future<void> _addCategory(BuildContext context) async {
    final shoppinglistCubit = BlocProvider.of<ShoppinglistCubit>(context);
    // Il dialogo si apre sopra il pannello e il pannello si chiude dopo:
    // chiudendolo prima, il suo context non servirebbe più ad aprire nulla
    final name = await showDialog<String>(
      context: context,
      builder: (context) => TextDialog(
        title: AppLocalizations.of(context)!.addCategory,
        doneText: AppLocalizations.of(context)!.add,
        hintText: AppLocalizations.of(context)!.name,
        isInputValid: (s) => s.trim().isNotEmpty,
      ),
    );
    if (context.mounted) context.pop();
    if (name != null) await shoppinglistCubit.addCategory(name);
  }

  @override
  Widget build(BuildContext context) {
    final householdCubit = BlocProvider.of<HouseholdCubit>(context);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _StoreList(openStore: householdCubit.state.household),
          const Divider(),
          BlocBuilder<HouseholdCubit, HouseholdState>(
            bloc: householdCubit,
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.household.image != null)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: !App.isOffline &&
                                context.read<AuthCubit>().getUser() != null &&
                                state.household.hasAdminRights(
                                    context.read<AuthCubit>().getUser()!)
                            ? 6
                            : 16),
                    child: HouseholdImage(household: state.household),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      state.household.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (!App.isOffline &&
                        context.read<AuthCubit>().getUser() != null &&
                        state.household.hasAdminRights(
                            context.read<AuthCubit>().getUser()!))
                      IconButton(
                        icon: Icon(Icons.edit_rounded),
                        onPressed: () {
                          context.pop();
                          Navigator.of(context).push<UpdateEnum>(
                            MaterialPageRoute(
                              builder: (ctx) => HouseholdUpdatePage(
                                household: state.household,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          BlocBuilder<HouseholdCubit, HouseholdState>(
            bloc: householdCubit,
            buildWhen: (previous, current) =>
                previous.household.viewOrdering
                    ?.equals(current.household.viewOrdering ?? const []) ??
                true,
            builder: (context, state) {
              List<ViewsEnum> pages =
                  (state.household.viewOrdering ?? ViewsEnum.values)
                      .where((e) => e.isViewActive(state.household))
                      .skip(5)
                      .toList();
              if (pages.isEmpty) return const SizedBox();
              return Column(
                children: pages
                        .map((e) => Card(
                              child: ListTile(
                                title: Text(
                                  e.toLocalizedString(context),
                                ),
                                leading: e.toIconWidget(context) ??
                                    Icon(e.toIcon(context)),
                                minLeadingWidth: 16,
                                onTap: () => context.go("/household"),
                              ),
                            ) as Widget)
                        .toList() +
                    [
                      const Divider(),
                    ],
              );
            },
          ),
          Card(
            child: ListTile(
              title: Text(AppLocalizations.of(context)!.addCategory),
              leading: const Icon(Icons.create_new_folder_rounded),
              minLeadingWidth: 16,
              onTap: () => _addCategory(context),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(
                AppLocalizations.of(context)!.householdSwitch,
              ),
              leading: const Icon(Icons.swap_horiz_rounded),
              minLeadingWidth: 16,
              onTap: () => context.go("/household"),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(
                AppLocalizations.of(context)!.profile,
              ),
              leading: const Icon(Icons.person_rounded),
              minLeadingWidth: 16,
              onTap: () {
                context.pop();
                context.push("/settings/account").then((res) {
                  if (res == UpdateEnum.updated) {
                    context.read<AuthCubit>().refreshUser();
                  }
                });
              },
            ),
          ),
          Card(
            child: ListTile(
              title: Text(
                AppLocalizations.of(context)!.settings,
              ),
              leading: const Icon(Icons.settings),
              minLeadingWidth: 16,
              onTap: () {
                context.pop();
                context.push(
                  "/settings",
                  extra: householdCubit.state.household,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// I negozi dell'utente, dal server o, senza rete, dalla copia sul telefono.
/// Il tocco apre il negozio passando dalla stessa rotta dell'elenco completo,
/// che ricorda anche l'ultimo negozio usato per la riapertura dell'app e per
/// la scorciatoia "Add item".
class _StoreList extends StatelessWidget {
  final Household openStore;

  const _StoreList({required this.openStore});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HouseholdListCubit(),
      child: BlocBuilder<HouseholdListCubit, HouseholdListState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final store in state.households)
              Card(
                child: ListTile(
                  title: Text(store.name),
                  leading: const Icon(Icons.storefront_rounded),
                  minLeadingWidth: 16,
                  selected: store.id == openStore.id,
                  trailing: store.id == openStore.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => _open(context, store),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Household store) {
    context.pop();
    if (store.id == openStore.id) return;
    context.go(
      '/household/${store.id}/${store.viewOrdering?.firstOrNull.toString()}',
      extra: store,
    );
  }
}
