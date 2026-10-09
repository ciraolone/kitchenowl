/// I due pulsanti a destra del campo di ricerca della lista della spesa
/// (features/003-lista-essenziale): l'ordinamento, che a ogni tocco passa al
/// successivo e mostra un'icona diversa per ciascuno, e il pulsante casa, che
/// apre il pannello di MorePage. Sostituiscono il pulsante testuale
/// dell'ordinamento sopra la lista e la barra di navigazione in basso, tolta
/// sui telefoni. Leggono ShoppinglistCubit, HouseholdCubit e AuthCubit dal
/// contesto della pagina della casa.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kitchenowl/cubits/auth_cubit.dart';
import 'package:kitchenowl/cubits/household_cubit.dart';
import 'package:kitchenowl/cubits/shoppinglist_cubit.dart';
import 'package:kitchenowl/enums/views_enum.dart';
import 'package:kitchenowl/pages/household_page/more.dart';

class ShoppingListSearchActions extends StatelessWidget {
  const ShoppingListSearchActions({super.key});

  @override
  Widget build(BuildContext context) {
    final shoppinglistCubit = BlocProvider.of<ShoppinglistCubit>(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlocBuilder<ShoppinglistCubit, ShoppinglistCubitState>(
          bloc: shoppinglistCubit,
          buildWhen: (previous, current) => previous.sorting != current.sorting,
          builder: (context, state) => IconButton(
            onPressed: shoppinglistCubit.incrementSorting,
            tooltip: state.sorting.toLocalizedString(context),
            icon: Icon(state.sorting.toIcon()),
          ),
        ),
        // AuthCubit perché l'icona diventa la nuvola barrata senza rete
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) => IconButton(
            onPressed: () => MorePage.show(
              context,
              BlocProvider.of<HouseholdCubit>(context),
              shoppinglistCubit,
            ),
            tooltip: ViewsEnum.more.toLocalizedString(context),
            icon: ViewsEnum.more.toIconWidget(context) ??
                Icon(ViewsEnum.more.toIcon(context)),
          ),
        ),
      ],
    );
  }
}
