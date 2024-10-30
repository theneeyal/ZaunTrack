import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoadScreen extends StatefulWidget {
  final String jobNumber;
  final List<Map<String, String>> scannedItems;
  final List<Map<String, String>> loadedItems;
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
  late List<Map<String, String>> loadedItems;
  late Map<String, int> scannedCategoryCount;
  late Map<String, int> loadedCategoryCount;
  bool isLoaded = false;
  String? currentCategory;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    loadedItems = List<Map<String, String>>.from(widget.loadedItems);
    isLoaded = widget.isLoaded;
    _initializeCategoryCounts();
    loadController.addListener(_onBarcodeChanged); // Set up listener for input debounce
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Cancel the debounce timer if active
    loadController.removeListener(_onBarcodeChanged); // Remove listener to prevent memory leaks
    loadController.dispose();
    super.dispose();
  }

  void _initializeCategoryCounts() {
    scannedCategoryCount = {};
    for (var item in widget.scannedItems) {
      scannedCategoryCount[item['category']!] =
          (scannedCategoryCount[item['category']!] ?? 0) + 1;
    }

    loadedCategoryCount = {};
    for (var item in loadedItems) {
      String category = item['category']!;
      loadedCategoryCount[category] = (loadedCategoryCount[category] ?? 0) + 1;
    }
  }

  Future<void> _updateFirebase() async {
    final jobDoc = FirebaseFirestore.instance.collection('jobs').doc(widget.jobNumber);

    List<Map<String, String>> loadedItemsForFirebase = loadedItems.map((item) {
      return {
        'barcode': item['barcode'] ?? '',
        'category': item['category'] ?? '',
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
    // Debounce to wait for user to finish typing
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (loadController.text.trim().isNotEmpty) {
        _addLoadItem(); // Call the barcode check only after 500ms of inactivity
      }
    });
  }

  void _addLoadItem() {
    String barcode = loadController.text.trim();

    if (barcode.isNotEmpty) {
      // Find the scanned item by barcode
      var scannedItem = widget.scannedItems.firstWhere(
          (item) => item['barcode'] == barcode, orElse: () => {});

      // Ensure the scanned item is found and not already loaded
      if (scannedItem.isNotEmpty && !loadedItems.any((item) => item['barcode'] == barcode)) {
        setState(() {
          String category = scannedItem['category']!;
          loadedItems.add({'barcode': barcode, 'category': category});
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

  void _toggleIsLoaded(bool value) {
    setState(() {
      isLoaded = value;
    });
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
                onChanged: _toggleIsLoaded,
                activeColor: Colors.green,
                inactiveThumbColor: Colors.redAccent,
                inactiveTrackColor: Colors.red[200],
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Loading Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: scannedCategoryCount.keys.map((category) {
                  int loadedCount = loadedCategoryCount[category] ?? 0;
                  int totalCount = scannedCategoryCount[category]!;
                  return ListTile(
                    title: Text(
                      '$loadedCount/$totalCount $category Loaded',
                      style: const TextStyle(fontSize: 16),
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
