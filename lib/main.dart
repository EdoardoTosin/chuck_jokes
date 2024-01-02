import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemTheme.accentColor.load();
  SystemTheme.onChange.listen((color) {
    debugPrint('Accent color changed to ${color.accent}');
  });
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
  ));
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: SystemThemeBuilder(builder: (context, accent) {
        return MaterialApp(
          title: 'Chuck Norris Jokes',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: accent.accent),
          ),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.system,
          home: MyHomePage(),
        );
      }),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String? joke;
  var favorites = <String>[];

  Future<void> fetchJoke() async {
    var client = http.Client();
    var response =
        await client.get(Uri.parse('https://api.chucknorris.io/jokes/random'));
    if (response.body.isNotEmpty) {
      try {
        var data = jsonDecode(response.body);
        joke = data['value'] ?? '';
      } catch (e) {
        print('Failed to decode JSON: $e');
      }
    } else {
      print('Empty or invalid response body');
    }
    notifyListeners();
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFavorites = prefs.getStringList('favorites') ?? [];
    favorites = savedFavorites.toList();
    notifyListeners();
  }

  void toggleFavorite() {
    if ((joke?.isNotEmpty ?? false) && favorites.contains(joke ?? '')) {
      favorites.remove(joke ?? '');
    } else if ((joke?.isNotEmpty ?? false) && !favorites.contains(joke ?? '')) {
      favorites.add(joke ?? '');
    }
    saveFavorites();
  }

  void removeFromFavorites(String joke) {
    favorites.remove(joke);
    saveFavorites();
  }

  Future<void> saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', favorites);
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  late MyAppState appState;

  @override
  void initState() {
    super.initState();
    appState = Provider.of<MyAppState>(context, listen: false);
    appState.loadFavorites();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ));
    appState.fetchJoke();
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    page = switch (selectedIndex) {
      0 => GeneratorPage(),
      1 => FavoritesPage(),
      _ => throw UnimplementedError('no widget for $selectedIndex')
    };

    return Scaffold(
      body: Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: page,
      ),
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.favorite),
            icon: Icon(Icons.favorite_outline),
            label: 'Favorites',
          ),
        ],
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var joke = appState.joke ?? '';

    IconData icon;
    if (appState.favorites.contains(joke)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (joke.isNotEmpty) ...[
            BigCard(joke: joke),
            SizedBox(height: 10),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.fetchJoke();
                },
                child: Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    super.key,
    required this.joke,
  });

  final String joke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displayMedium!
        .copyWith(color: theme.colorScheme.onPrimary, fontSize: 20);

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          joke,
          style: style,
          semanticsLabel: joke,
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
        child: Text('No favorites yet.',
            style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }

    String favoritesText =
        appState.favorites.length == 1 ? 'favorite' : 'favorites';

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have ${appState.favorites.length} $favoritesText:',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        for (var joke in appState.favorites)
          ListTile(
            title: Text(joke),
            trailing: PopupMenuButton<int>(
              onSelected: (result) {
                if (result == 0) {
                  Share.share(joke);
                } else if (result == 1) {
                  context.read<MyAppState>().removeFromFavorites(joke);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  child: Text("Share"),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Text("Delete"),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
