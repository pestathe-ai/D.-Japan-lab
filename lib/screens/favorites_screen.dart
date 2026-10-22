import 'package:flutter/material.dart';

import '../services/store.dart';

/// Elenco delle pagine salvate. Tocca per aprire, scorri per eliminare.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferiti')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.favorites.items;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nessun preferito.\nApri un articolo e tocca la ☆ in alto per salvarlo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final f = items[i];
              return Dismissible(
                key: ValueKey(f.url),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => store.setFavorites(store.favorites.remove(f.url)),
                child: ListTile(
                  leading: const Icon(Icons.star),
                  title: Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(f.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, f.url),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
