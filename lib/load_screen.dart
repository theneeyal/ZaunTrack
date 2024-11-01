import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoadScreen extends StatefulWidget {
  final String jobNumber;
  final List<Map<String, dynamic>> scannedItems;
  final List<Map<String, dynamic>> loadedItems;
  final bool isLoaded;

  const LoadScreen({
    super.key,
    required this.jobNumber,
    required this.scannedItems,
    required this.loadedItems,
    this.isLoaded = false,
  });

  @override
  _LoadScreenState createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  final TextEditingController loadController = TextEditingController();
  late List<Map<String, dynamic>> loadedItems;
  late Map<String, int> scannedCategoryCount;
  late Map<String, int> loadedCategoryCount;
  bool isLoaded = false;
  String? currentCategory;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // Initialize loadedItems and ensure each item has 'isSent' as a boolean
    loadedItems = widget.loadedItems.map((item) {
      return {
        'barcode': item['barcode'] ?? '',
        'category': item['category'] ?? '',
        'isSent': item['isSent'] == true, // Ensure isSent is a bool
      };
    }).toList();

    isLoaded = widget.isLoaded;
    _initializeCategoryCounts();
    loadController.addListener(_onBarcodeChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    loadController.removeListener(_onBarcodeChanged);
    loadController.dispose();
    super.dispose();
  }

  void _initializeCategoryCounts() {
    scannedCategoryCount = {};
    for (var item in widget.scannedItems) {
      scannedCategoryCount[item['category'] as String] =
          (scannedCategoryCount[item['category'] as String] ?? 0) + 1;
    }

    loadedCategoryCount = {};
    for (var item in loadedItems) {
      String category = item['category'] as String;
      loadedCategoryCount[category] = (loadedCategoryCount[category] ?? 0) + 1;
    }
  }

  Future<void> _updateFirebase() async {
    final jobDoc = FirebaseFirestore.instance.collection('jobs').doc(widget.jobNumber);

    List<Map<String, dynamic>> loadedItemsForFirebase = loadedItems.map((item) {
      return {
        'barcode': item['barcode'],
        'category': item['category'],
        'isSent': item['isSent'],
      };
    }).toList();

    try {
      var docSnapshot = await jobDoc.get();
      if (docSnapshot.exists) {
        await jobDoc.update({
          'loadedItems': loadedItemsForFirebase,
          'isLoaded': isLoaded,
        });
        print("Firebase update successful.");
      } else {
        print("Document with jobNumber ${widget.jobNumber} does not exist.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job with number ${widget.jobNumber} not found in Firebase.')),
        );
      }
    } catch (e) {
      print("Error updating Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update job in Firebase: $e')),
      );
    }
  }

  void _onBarcodeChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (loadController.text.trim().isNotEmpty) {
        _addLoadItem();
      }
    });
  }

  void _addLoadItem() {
    String barcode = loadController.text.trim();

    if (barcode.isNotEmpty) {
      var scannedItem = widget.scannedItems.firstWhere(
        (item) => item['barcode'] == barcode,
        orElse: () => <String, dynamic>{}, // Return an empty map if not found
      );

      if (scannedItem.isNotEmpty && !loadedItems.any((item) => item['barcode'] == barcode)) {
        setState(() {
          String category = scannedItem['category'] ?? 'Unknown';
          loadedItems.add({'barcode': barcode, 'category': category, 'isSent': false});
          loadedCategoryCount[category] = (loadedCategoryCount[category] ?? 0) + 1;
          loadController.clear();
          currentCategory = category;
        });
        _updateFirebase(); // Update Firebase after adding item
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item $barcode added to loaded items')),
        );
      } else if (scannedItem.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barcode $barcode not found in scanned items')),
        );
        currentCategory = null;
      }
    }
  }

  bool _allItemsSent() {
    // Check if all items in loadedItems have isSent as true
    return loadedItems.every((item) => item['isSent'] == true);
  }

  void _toggleIsLoaded(bool value) {
    // Only allow setting isLoaded to true if all items are marked as sent
    if (value && !_allItemsSent()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All items must be marked as sent before completing loading.')),
      );
      return;
    }

    setState(() {
      isLoaded = value;
    });
    _updateFirebase();
  }

  void _toggleItemSentStatus(String barcode, bool isSent) {
    setState(() {
      loadedItems = loadedItems.map((item) {
        if (item['barcode'] == barcode) {
          return {...item, 'isSent': isSent};
        }
        return item;
      }).toList();
    });

    // If any item is marked as unsent, ensure that `isLoaded` is set to false
    if (!isSent) {
      setState(() {
        isLoaded = false;
      });
    }

    _updateFirebase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Load Items for Job ${widget.jobNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, {
              'loadedItems': loadedItems,
              'isLoaded': isLoaded,
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: loadController,
              decoration: InputDecoration(
                labelText: 'Enter or Scan Load Item Barcode',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 8),
            if (currentCategory != null)
              Text(
                'Category: $currentCategory',
                style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (loadController.text.trim().isNotEmpty) {
                  _addLoadItem();
                }
              },
              child: const Text('Add Load Item'),
            ),
            const SizedBox(height: 20),
            if (loadedItems.length == widget.scannedItems.length) ...[
              const Text(
                'All items are loaded!',
                style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: Text(
                  isLoaded ? 'Loading Completed' : 'Mark Loading as Completed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isLoaded ? Colors.green : Colors.red,
                  ),
                ),
                value: isLoaded,
                onChanged: _allItemsSent() ? _toggleIsLoaded : null, // Only allow if all items are sent
                activeColor: Colors.green,
                inactiveThumbColor: Colors.redAccent,
                inactiveTrackColor: Colors.red[200],
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Loaded Items:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: loadedItems.map((item) {
                  return ListTile(
                    title: Text(
                      'Barcode: ${item['barcode']} (${item['category']})',
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: Switch(
                      value: item['isSent'] as bool,
                      onChanged: (value) => _toggleItemSentStatus(item['barcode'] as String, value),
                      activeColor: Colors.blue,
                      inactiveThumbColor: Colors.grey,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
