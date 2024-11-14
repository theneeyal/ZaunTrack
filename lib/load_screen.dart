import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoadScreen extends StatefulWidget {
  final String jobNumber;
  final List<Map<String, dynamic>> scannedItems;
  final List<Map<String, dynamic>> loadedItems;
  final bool isLoaded;
  final bool isScanningCompleted;

  const LoadScreen({
    super.key,
    required this.jobNumber,
    required this.scannedItems,
    required this.loadedItems,
    this.isLoaded = false,
    this.isScanningCompleted = false,
  });

  @override
  LoadScreenState createState() => LoadScreenState();
}

class LoadScreenState extends State<LoadScreen> {
  final TextEditingController loadController = TextEditingController();
  final FocusNode loadFocusNode = FocusNode();
  late List<Map<String, dynamic>> loadedItems;
  bool isLoaded = false;
  bool isScanningCompleted = false;
  String? currentCategory;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeLoadedItems();

    loadController.addListener(_onBarcodeChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    loadController.removeListener(_onBarcodeChanged);
    loadController.dispose();
    loadFocusNode.dispose();
    super.dispose();
  }

  void _initializeLoadedItems() {
    loadedItems = List.from(widget.loadedItems);
    isLoaded = widget.isLoaded;
    isScanningCompleted = widget.isScanningCompleted;
    _fetchLoadedItemsFromFirebase();
  }

  Future<void> _fetchLoadedItemsFromFirebase() async {
    final jobDoc = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobNumber)
        .get();

    if (jobDoc.exists && mounted) {
      setState(() {
        loadedItems = List<Map<String, dynamic>>.from(jobDoc.data()?['loadedItems'] ?? []);
        isLoaded = jobDoc.data()?['isLoaded'] ?? false;
      });
    }
  }

  Map<String, String> _getCategoryCounts() {
    Map<String, int> scannedCounts = {};
    Map<String, int> loadedCounts = {};

    for (var item in widget.scannedItems) {
      String category = item['category'] ?? 'Unknown';
      scannedCounts[category] = (scannedCounts[category] ?? 0) + 1;
    }

    for (var item in loadedItems) {
      String category = item['category'] ?? 'Unknown';
      loadedCounts[category] = (loadedCounts[category] ?? 0) + 1;
    }

    return scannedCounts.map((category, totalCount) {
      int loadedCount = loadedCounts[category] ?? 0;
      return MapEntry(category, '$loadedCount/$totalCount');
    });
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
      await jobDoc.update({
        'loadedItems': loadedItemsForFirebase,
        'isLoaded': isLoaded,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update job in Firebase: $e')),
        );
      }
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
        orElse: () => <String, dynamic>{},
      );

      if (scannedItem.isNotEmpty && !loadedItems.any((item) => item['barcode'] == barcode)) {
        setState(() {
          String category = scannedItem['category'] ?? 'Unknown';
          loadedItems.add({'barcode': barcode, 'category': category, 'isSent': false});
          loadController.clear();
          currentCategory = category;
        });
        _updateFirebase();
        loadFocusNode.requestFocus();
      } else if (scannedItem.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barcode $barcode not found in scanned items')),
        );
        currentCategory = null;
        loadFocusNode.requestFocus();
      }
    }
    _checkIsLoadedCondition();
  }

  void _deleteLoadedItem(String barcode) {
    setState(() {
      loadedItems.removeWhere((item) => item['barcode'] == barcode);
    });
    _updateFirebase();
    _checkIsLoadedCondition();
    loadFocusNode.requestFocus();
  }

  bool _allItemsSent() {
    return loadedItems.every((item) => item['isSent'] == true);
  }

  bool _allScannedItemsLoaded() {
    return widget.scannedItems.every((scannedItem) =>
        loadedItems.any((loadedItem) => loadedItem['barcode'] == scannedItem['barcode']));
  }

  bool _canToggleIsLoaded() {
    return _allItemsSent() && _allScannedItemsLoaded() && isScanningCompleted;
  }

  void _checkIsLoadedCondition() {
    if (!isLoaded || !_canToggleIsLoaded()) {
      setState(() {
        isLoaded = false;
      });
    }
  }

  Future<void> _navigateBack() async {
    await _updateFirebase();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pop(context, {
        'loadedItems': loadedItems,
        'isLoaded': isLoaded,
      });
    }
  }

  void _toggleIsLoaded(bool value) {
    if (value && !_canToggleIsLoaded()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All conditions must be met to mark loading as completed.')),
        );
      }
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

    _updateFirebase();
    _checkIsLoadedCondition();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, String> categoryCounts = _getCategoryCounts();

    return Scaffold(
      appBar: AppBar(
        title: Text('Load Items for Job ${widget.jobNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: loadController,
              focusNode: loadFocusNode,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: categoryCounts.entries.map((entry) {
                return Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 16));
              }).toList(),
            ),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: item['isSent'] as bool,
                          onChanged: (value) => _toggleItemSentStatus(item['barcode'] as String, value),
                          activeColor: Colors.blue,
                          inactiveThumbColor: Colors.grey,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.black),
                          onPressed: () => _deleteLoadedItem(item['barcode'] as String),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
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
              onChanged: _canToggleIsLoaded() ? _toggleIsLoaded : null,
              activeColor: Colors.green,
              inactiveThumbColor: Colors.redAccent,
              inactiveTrackColor: Colors.red[200],
            ),
          ],
        ),
      ),
    );
  }
}
