import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const StorageHomePage(),
    );
  }
}

class StorageLocation {
  String id;
  String name;
  List<Item> items;

  StorageLocation({required this.name, required this.items, String? id}) : id = id ?? const Uuid().v4();

  factory StorageLocation.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<Item> items = itemsList.map((i) => Item.fromJson(i)).toList();
    return StorageLocation(
      id: json['id'],
      name: json['name'],
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class Item {
  String id;
  String name;
  bool isAvailable;
  File? image;
  String? imagePath;

  Item({required this.name, this.isAvailable = true, this.image, this.imagePath, String? id}) : id = id ?? const Uuid().v4();

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      isAvailable: json['isAvailable'],
      imagePath: json['imagePath'],
      image: json['imagePath'] != null ? File(json['imagePath']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isAvailable': isAvailable,
      'imagePath': image?.path,
    };
  }
}

class StorageHomePage extends StatefulWidget {
  const StorageHomePage({super.key});

  @override
  _StorageHomePageState createState() => _StorageHomePageState();
}

class _StorageHomePageState extends State<StorageHomePage> {
  List<StorageLocation> _storageLocations = [];
  late List<StorageLocation> _filteredLocations;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredLocations = _storageLocations;
    _searchController.addListener(_filterLocations);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_storageLocations.map((e) => e.toJson()).toList());
    await prefs.setString('storage_data', encodedData);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('storage_data');
    if (encodedData != null) {
      final List<dynamic> decodedData = jsonDecode(encodedData);
      setState(() {
        _storageLocations = decodedData.map((item) => StorageLocation.fromJson(item)).toList();
        _filterLocations();
      });
    }
  }

  void _filterLocations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = _storageLocations;
      } else {
        _filteredLocations = _storageLocations.where((location) {
          final locationMatch = location.name.toLowerCase().contains(query);
          final itemMatch = location.items.any((item) => item.name.toLowerCase().contains(query));
          return locationMatch || itemMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Tracker'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items or locations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: Animate(
        effects: const [FadeEffect(), SlideEffect()],
        child: ListView.builder(
          itemCount: _filteredLocations.length,
          itemBuilder: (context, index) {
            final location = _filteredLocations[index];
            return Card(
              key: ValueKey(location.id),
              margin: const EdgeInsets.all(8.0),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                title: Text(location.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _showAddItemDialog(location),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showEditLocationDialog(location),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteLocation(location),
                    ),
                  ],
                ),
                children: location.items.map((item) {
                  return ListTile(
                    key: ValueKey(item.id),
                    leading: GestureDetector(
                      onTap: () => _pickImage(item),
                      child: Animate(
                        effects: const [ScaleEffect()],
                        child: item.image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.file(item.image!, width: 50, height: 50, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.image_outlined, size: 50),
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: Text(item.isAvailable ? 'Available' : 'Not Available'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Switch(
                          value: item.isAvailable,
                          onChanged: (value) {
                            setState(() {
                              item.isAvailable = value;
                            });
                            _saveData();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEditItemDialog(item, location),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteItem(item, location),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ).animate().fade(duration: 500.ms).slideX();
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLocationDialog(),
        child: const Icon(Icons.add_location_alt_outlined),
      ).animate().scale(),
    );
  }

  void _showAddLocationDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Location'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Location Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _storageLocations.add(StorageLocation(name: controller.text, items: []));
                    _filterLocations();
                  });
                  _saveData();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddItemDialog(StorageLocation location) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Item to ${location.name}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Item Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    location.items.add(Item(name: controller.text));
                    _filterLocations();
                  });
                  _saveData();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditLocationDialog(StorageLocation location) {
    final TextEditingController controller = TextEditingController(text: location.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Location'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Location Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    location.name = controller.text;
                    _filterLocations();
                  });
                  _saveData();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteLocation(StorageLocation location) {
    setState(() {
      _storageLocations.removeWhere((l) => l.id == location.id);
      _filterLocations();
    });
    _saveData();
  }

  void _showEditItemDialog(Item item, StorageLocation location) {
    final TextEditingController controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Item'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Item Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    item.name = controller.text;
                    _filterLocations();
                  });
                  _saveData();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteItem(Item item, StorageLocation location) {
    setState(() {
      location.items.removeWhere((i) => i.id == item.id);
      _filterLocations();
    });
    _saveData();
  }

  Future<void> _pickImage(Item item) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        item.image = File(pickedFile.path);
        item.imagePath = pickedFile.path;
      });
      _saveData();
    }
  }
}
