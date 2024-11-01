import 'dart:async';
import 'package:flutter/material.dart';
import 'load_screen.dart';

class ScanScreen extends StatefulWidget {
  final String jobNumber;
  final bool isCompleted;
  final List<Map<String, dynamic>> scannedItems;
  final List<Map<String, dynamic>> loadedItems;
  final bool isLoaded;
  final bool isStorePickComplete;
  final bool isYardPickComplete;

  const ScanScreen({
    super.key,
    required this.jobNumber,
    this.isCompleted = false,
    required this.scannedItems,
    required this.loadedItems,
    required this.isLoaded,
    this.isStorePickComplete = false,
    this.isYardPickComplete = false,
  });

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final TextEditingController barcodeController = TextEditingController();
  String? selectedCategory;
  late List<Map<String, dynamic>> scannedItems;
  late List<Map<String, dynamic>> loadedItems;
  bool isScanningCompleted = false;
  bool isStorePickComplete = false;
  bool isYardPickComplete = false;
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();
    isStorePickComplete = widget.isStorePickComplete;
    isYardPickComplete = widget.isYardPickComplete;
    isLoaded = widget.isLoaded;
    scannedItems = List.from(widget.scannedItems);
    loadedItems = List.from(widget.loadedItems);
    _updateIsLoadedStatus();
  }

  void _selectCategory(String category) {
    if (isStorePickComplete && isYardPickComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add items when both toggles are complete.')),
      );
      return;
    }

    String barcode = barcodeController.text.trim();
    bool alreadyScanned = scannedItems.any((item) => item['barcode'] == barcode);

    if (barcode.isNotEmpty && !alreadyScanned) {
      setState(() {
        selectedCategory = category;
        scannedItems.add({
          'barcode': barcode,
          'category': category,
        });
        barcodeController.clear();
        selectedCategory = null;
        _updateIsLoadedStatus();
      });
    } else if (alreadyScanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item with barcode $barcode has already been scanned.')),
      );
    }
  }

  void _toggleStorePickStatus(bool value) {
    setState(() {
      isStorePickComplete = value;
      _updateScanningCompletedStatus();
    });
  }

  void _toggleYardPickStatus(bool value) {
    setState(() {
      isYardPickComplete = value;
      _updateScanningCompletedStatus();
    });
  }

  void _updateScanningCompletedStatus() {
    setState(() {
      isScanningCompleted = isStorePickComplete && isYardPickComplete;
      _updateIsLoadedStatus();
    });
  }

  bool _allItemsSent() {
    return loadedItems.every((item) => item['isSent'] == true);
  }

  void _updateIsLoadedStatus() {
    // Only set `isLoaded` to true if scanning is complete AND all items are marked as sent
    setState(() {
      isLoaded = isScanningCompleted && _allItemsSent();
    });
  }

  void _openLoadScreen() async {
    var result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoadScreen(
          jobNumber: widget.jobNumber,
          scannedItems: scannedItems,
          loadedItems: loadedItems,
          isLoaded: isLoaded,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        loadedItems = List<Map<String, dynamic>>.from(result['loadedItems']);
        isLoaded = result['isLoaded'] ?? isLoaded;
        _updateIsLoadedStatus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isInputDisabled = isStorePickComplete && isYardPickComplete;

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Items for Job ${widget.jobNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, {
              'isCompleted': isScanningCompleted,
              'scannedItems': scannedItems,
              'loadedItems': loadedItems,
              'isLoaded': isLoaded,
              'isStorePickComplete': isStorePickComplete,
              'isYardPickComplete': isYardPickComplete,
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
              controller: barcodeController,
              decoration: InputDecoration(
                labelText: 'Enter or Scan Barcode',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              enabled: !isInputDisabled,
            ),
            const SizedBox(height: 16),
            const Text(
              "Please choose the type of item to be scanned:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                _buildCategoryButton('Mesh'),
                _buildCategoryButton('Posts'),
                _buildCategoryButton('Gates'),
                _buildCategoryButton('Clamp-bars'),
                _buildCategoryButton('Railings'),
                _buildCategoryButton('Fixings'),
                _buildCategoryButton('Other'),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text(
                'Store Pick Complete',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              value: isStorePickComplete,
              onChanged: (value) {
                _toggleStorePickStatus(value);
              },
              activeColor: Colors.green,
              inactiveThumbColor: Colors.redAccent,
              inactiveTrackColor: Colors.red[200],
            ),
            SwitchListTile(
              title: const Text(
                'Yard Pick Complete',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              value: isYardPickComplete,
              onChanged: (value) {
                _toggleYardPickStatus(value);
              },
              activeColor: Colors.green,
              inactiveThumbColor: Colors.redAccent,
              inactiveTrackColor: Colors.red[200],
            ),
            const SizedBox(height: 24),
            Text(
              '${scannedItems.length} Items Scanned:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: scannedItems.map((item) {
                  final barcode = item['barcode']!;
                  final maskedBarcode = _formatBarcode(barcode);
                  final category = item['category'];
                  return ListTile(
                    title: Text(
                      '$maskedBarcode                 Category: $category',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openLoadScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Loading',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String category) {
    return ElevatedButton(
      onPressed: !isScanningCompleted && !(isStorePickComplete && isYardPickComplete)
          ? () => _selectCategory(category)
          : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        backgroundColor: selectedCategory == category ? Colors.blue : Colors.grey[300],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: selectedCategory == category ? Colors.white : Colors.black,
          fontSize: 14,
        ),
      ),
    );
  }

  String _formatBarcode(String barcode) {
    if (barcode.length <= 3) return barcode;
    return barcode.substring(0, 4) + '*' * (barcode.length - 4);
  }
}
