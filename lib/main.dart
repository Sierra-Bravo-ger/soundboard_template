import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => FavoritesProvider(),
      child: const SoundboardApp(),
    ),
  );
}

class SoundboardApp extends StatefulWidget {
  const SoundboardApp({super.key});

  @override
  State<SoundboardApp> createState() => _SoundboardAppState();
}

class _SoundboardAppState extends State<SoundboardApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleThemeMode() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.light;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightColorScheme =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF2196F3), // Blue as primary
              primary: const Color(0xFF2196F3),
              secondary: const Color(0xFF4CAF50), // Green as secondary
              tertiary: const Color(0xFFFF9800), // Orange as tertiary
              brightness: Brightness.light,
            );

        final darkColorScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF1976D2), // Darker blue for dark mode
              primary: const Color(0xFF1976D2),
              secondary: const Color(0xFF388E3C), // Darker green
              tertiary: const Color(0xFFF57C00), // Darker orange
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Soundboard',
          theme: ThemeData(colorScheme: lightColorScheme, useMaterial3: true),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
          ),
          themeMode: _themeMode,
          home: SoundboardHome(
            toggleTheme: _toggleThemeMode,
            currentThemeMode: _themeMode,
          ),
        );
      },
    );
  }
}

class SoundboardHome extends StatefulWidget {
  final Function toggleTheme;
  final ThemeMode currentThemeMode;

  const SoundboardHome({
    super.key,
    required this.toggleTheme,
    required this.currentThemeMode,
  });

  @override
  State<SoundboardHome> createState() => _SoundboardHomeState();
}

class _SoundboardHomeState extends State<SoundboardHome>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late TabController _tabController;
  bool _isPlaying = false;
  String _currentlyPlaying = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String _currentSoundName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen for playback completion
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _currentlyPlaying = '';
        _position = Duration.zero;
      });
    });
    
    // Listen for duration changes
    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });
    
    // Listen for position changes
    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _position = newPosition;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _playSound(String category, String soundName) async {
    final String path = 'assets/sounds/$category/$soundName.mp3';
    
    if (_isPlaying) {
      await _audioPlayer.stop();
    }
    
    await _audioPlayer.play(AssetSource(path.replaceFirst('assets/', '')));
    
    setState(() {
      _isPlaying = true;
      _currentlyPlaying = '$category/$soundName';
      _currentSoundName = _formatSoundName(soundName);
      _position = Duration.zero;
    });
  }
  
  String _formatSoundName(String name) {
    // Replace underscores with spaces
    String formatted = name.replaceAll('_', ' ');
    
    // Add spaces before capital letters (except the first one)
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (match) => ' ',
    );
    
    return formatted;
  }

  Future<void> _stopSound() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      
      setState(() {
        _isPlaying = false;
        _currentlyPlaying = '';
        _position = Duration.zero;
      });
    }
  }
  
  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    setState(() {
      _position = position;
    });
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Image.asset(
                'assets/images/SoundboardTogetherSmall.png',
                height: 32,
              ),
            ),
            const Text('Soundboard'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              widget.currentThemeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : widget.currentThemeMode == ThemeMode.dark
                  ? Icons.brightness_auto
                  : Icons.light_mode,
            ),
            onPressed: () => widget.toggleTheme(),
            tooltip:
                widget.currentThemeMode == ThemeMode.light
                    ? 'Dunkles Design'
                    : widget.currentThemeMode == ThemeMode.dark
                    ? 'Systemeinstellung'
                    : 'Helles Design',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Alle Sounds'),
            Tab(text: 'Favoriten'),
            Tab(text: 'Kategorien'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All Sounds Tab
          AllSoundsGrid(
            onPlaySound: _playSound,
            currentlyPlaying: _currentlyPlaying,
          ),

          // Favorites Tab
          FavoritesGrid(
            onPlaySound: _playSound,
            currentlyPlaying: _currentlyPlaying,
          ),

          // Categories Tab
          CategoriesView(
            onPlaySound: _playSound,
            currentlyPlaying: _currentlyPlaying,
          ),
        ],
      ),
      bottomNavigationBar: _isPlaying
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            _currentSoundName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FloatingActionButton.small(
                        onPressed: _stopSound,
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        tooltip: 'Sound stoppen',
                        child: const Icon(Icons.stop_rounded, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                          ),
                          child: Slider(
                            min: 0,
                            max: _duration.inMilliseconds.toDouble() > 0 
                                ? _duration.inMilliseconds.toDouble() 
                                : 1.0,
                            value: _position.inMilliseconds.toDouble().clamp(
                              0, 
                              _duration.inMilliseconds.toDouble() > 0 
                                  ? _duration.inMilliseconds.toDouble() 
                                  : 1.0,
                            ),
                            onChanged: (value) {
                              _seekTo(Duration(milliseconds: value.toInt()));
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class AllSoundsGrid extends StatelessWidget {
  final Function(String, String) onPlaySound;
  final String currentlyPlaying;

  const AllSoundsGrid({
    super.key,
    required this.onPlaySound,
    required this.currentlyPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<String>> soundCategories = {
      'drawnTogether': [
        'AUA',
        'AlrightyThen',
        'ArschZucker',
        'Genickzwirbler',
        'Gottlos',
        'Hebräer',
        'IchBinGott',
        'IchKannFliegen',
        'JudeImGarten',
        'PostIstDa',
        'SaufenLaufen',
        'Telefon',
        'Walross',
        'WasIstDennHierLos',
        'WürdMirStinken',
      ],
      'spongeBob': [
        'BenjaminBluemchen',
        'BösesImBusch',
        'KoennteSchlimmerSein',
        'Miau',
        'Miau_Song',
        'NeinHierIstPatrick',
        'NurNahrungsmittel',
        'Schokolade',
        'SchwammAnStern',
        'SeiVorsichtig',
        'SquareDance',
        'Wambo',
      ],
      'Deutsche Memes': [
        'Alarm',
        'BlasMirDochEin',
        'DerGerät',
        'Glatteis',
        'Habicht',
        'Kranplätze',
        'NeinDoch',
        'WasMachenSachen',
        'WoranHatsgelegen',
        'Zero',
        'Zückerli',
      ],
    };

    // Flatten the categories into a single list of sounds
    final List<SoundItem> allSounds = [];
    soundCategories.forEach((category, sounds) {
      for (final sound in sounds) {
        allSounds.add(SoundItem(category: category, name: sound));
      }
    });

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine if we're in portrait or landscape mode
          final isPortrait = constraints.maxWidth < constraints.maxHeight;
          final crossAxisCount = isPortrait ? 2 : 3;
          final childAspectRatio = isPortrait ? 1.5 : 2.0;
          
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: allSounds.length,
            itemBuilder: (context, index) {
              final sound = allSounds[index];
              return SoundButton(
                category: sound.category,
                soundName: sound.name,
                onPlaySound: onPlaySound,
                isPlaying: currentlyPlaying == '${sound.category}/${sound.name}',
              );
            },
          );
        },
      ),
    );
  }
}

class FavoritesGrid extends StatelessWidget {
  final Function(String, String) onPlaySound;
  final String currentlyPlaying;

  const FavoritesGrid({
    super.key,
    required this.onPlaySound,
    required this.currentlyPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final favorites = favoritesProvider.favorites;

    if (favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Keine Favoriten',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Füge Sounds zu deinen Favoriten hinzu,\nindem du auf den Stern klickst',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine if we're in portrait or landscape mode
          final isPortrait = constraints.maxWidth < constraints.maxHeight;
          final crossAxisCount = isPortrait ? 2 : 3;
          final childAspectRatio = isPortrait ? 1.5 : 2.0;
          
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final sound = favorites[index];
              return SoundButton(
                category: sound.category,
                soundName: sound.name,
                onPlaySound: onPlaySound,
                isPlaying: currentlyPlaying == '${sound.category}/${sound.name}',
              );
            },
          );
        },
      ),
    );
  }
}

class CategoriesView extends StatelessWidget {
  final Function(String, String) onPlaySound;
  final String currentlyPlaying;

  const CategoriesView({
    super.key,
    required this.onPlaySound,
    required this.currentlyPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, String> categoryNames = {
      'drawnTogether': 'Drawn Together',
      'spongeBob': 'SpongeBob',
      'Deutsche Memes': 'Deutsche Memes',
    };

    return ListView.builder(
      itemCount: categoryNames.length,
      itemBuilder: (context, index) {
        final category = categoryNames.keys.elementAt(index);
        final categoryName = categoryNames[category]!;

        return ExpansionTile(
          title: Text(categoryName),
          children: [
            CategorySoundsGrid(
              category: category,
              onPlaySound: onPlaySound,
              currentlyPlaying: currentlyPlaying,
            ),
          ],
        );
      },
    );
  }
}

class CategorySoundsGrid extends StatelessWidget {
  final String category;
  final Function(String, String) onPlaySound;
  final String currentlyPlaying;

  const CategorySoundsGrid({
    super.key,
    required this.category,
    required this.onPlaySound,
    required this.currentlyPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<String>> soundCategories = {
      'drawnTogether': [
        'AUA',
        'AlrightyThen',
        'ArschZucker',
        'Genickzwirbler',
        'Gottlos',
        'Hebräer',
        'IchBinGott',
        'IchKannFliegen',
        'JudeImGarten',
        'PostIstDa',
        'SaufenLaufen',
        'Telefon',
        'Walross',
        'WasIstDennHierLos',
        'WürdMirStinken',
      ],
      'spongeBob': [
        'BenjaminBluemchen',
        'BösesImBusch',
        'KoennteSchlimmerSein',
        'Miau',
        'Miau_Song',
        'NeinHierIstPatrick',
        'NurNahrungsmittel',
        'Schokolade',
        'SchwammAnStern',
        'SeiVorsichtig',
        'SquareDance',
        'Wambo',
      ],
      'Deutsche Memes': [
        'Alarm',
        'BlasMirDochEin',
        'DerGerät',
        'Glatteis',
        'Habicht',
        'Kranplätze',
        'NeinDoch',
        'WasMachenSachen',
        'WoranHatsgelegen',
        'Zero',
        'Zückerli',
      ],
    };

    final sounds = soundCategories[category] ?? [];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine if we're in portrait or landscape mode
          final isPortrait = constraints.maxWidth < constraints.maxHeight;
          final crossAxisCount = isPortrait ? 2 : 3;
          final childAspectRatio = isPortrait ? 1.5 : 2.0;
          
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: sounds.length,
            itemBuilder: (context, index) {
              final soundName = sounds[index];
              return SoundButton(
                category: category,
                soundName: soundName,
                onPlaySound: onPlaySound,
                isPlaying: currentlyPlaying == '$category/$soundName',
              );
            },
          );
        },
      ),
    );
  }
}

class SoundButton extends StatelessWidget {
  final String category;
  final String soundName;
  final Function(String, String) onPlaySound;
  final bool isPlaying;

  const SoundButton({
    super.key,
    required this.category,
    required this.soundName,
    required this.onPlaySound,
    required this.isPlaying,
  });
  
  // Share the sound file
  Future<void> _shareSound(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bereite Sound zum Teilen vor...')),
      );
      
      // Get the sound file path
      final String assetPath = 'assets/sounds/$category/$soundName.mp3';
      
      // Load the asset as bytes
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Get temporary directory to save the file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$soundName.mp3');
      await tempFile.writeAsBytes(bytes);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Check out this sound: $soundName',
        subject: 'Soundboard Sound',
      );
      
      // Clear the loading message
      ScaffoldMessenger.of(context).clearSnackBars();
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Teilen: $e')),
      );
    }
  }
  
  // Get a color based on the category and sound name
  Color _getCategoryColor(BuildContext context) {
    switch (category) {
      case 'drawnTogether':
        return const Color(0xFFE91E63); // Pink
      case 'spongeBob':
        return const Color(0xFFFFEB3B); // Yellow
      case 'Deutsche Memes':
        return const Color(0xFF4CAF50); // Green
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
  
  // Get a text color that contrasts with the background
  Color _getTextColor(Color backgroundColor) {
    // Check if the background color is light or dark
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.light ? Colors.black : Colors.white;
  }

  String _formatSoundName(String name) {
    // Replace underscores with spaces
    String formatted = name.replaceAll('_', ' ');
    
    // Add spaces before capital letters (except the first one)
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (match) => ' ',
    );
    
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final isFavorite = favoritesProvider.isFavorite(category, soundName);

    final buttonColor = isPlaying
        ? Theme.of(context).colorScheme.primaryContainer
        : _getCategoryColor(context);
    final textColor = isPlaying
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : _getTextColor(buttonColor);
    
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 50),
      ),
      onPressed: () => onPlaySound(category, soundName),
      onLongPress: () => _shareSound(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
                Text(
                  _formatSoundName(soundName),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color:
                  isFavorite
                      ? Colors.amber
                      : isPlaying
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
            onPressed: () {
              if (isFavorite) {
                favoritesProvider.removeFavorite(category, soundName);
              } else {
                favoritesProvider.addFavorite(category, soundName);
              }
            },
          ),
        ],
      ),
    );
  }
}

class SoundItem {
  final String category;
  final String name;

  SoundItem({required this.category, required this.name});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SoundItem &&
        other.category == category &&
        other.name == name;
  }

  @override
  int get hashCode => category.hashCode ^ name.hashCode;
}

class FavoritesProvider extends ChangeNotifier {
  List<SoundItem> _favorites = [];

  List<SoundItem> get favorites => _favorites;

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorites') ?? [];

    _favorites =
        favList.map((fav) {
          final parts = fav.split('/');
          return SoundItem(category: parts[0], name: parts[1]);
        }).toList();

    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList =
        _favorites.map((fav) => '${fav.category}/${fav.name}').toList();
    await prefs.setStringList('favorites', favList);
  }

  bool isFavorite(String category, String name) {
    return _favorites.contains(SoundItem(category: category, name: name));
  }

  void addFavorite(String category, String name) {
    final sound = SoundItem(category: category, name: name);
    if (!_favorites.contains(sound)) {
      _favorites.add(sound);
      _saveFavorites();
      notifyListeners();
    }
  }

  void removeFavorite(String category, String name) {
    _favorites.removeWhere(
      (fav) => fav.category == category && fav.name == name,
    );
    _saveFavorites();
    notifyListeners();
  }
}
