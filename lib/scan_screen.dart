import 'package:flutter/material.dart';
import 'load_screen.dart';

class ScanScreen extends StatefulWidget {
  final String jobNumber;
  final bool isCompleted;
  final List<Map<String, String>> scannedItems;
  final List<Map<String, String>> loadedItems;
  final bool isLoaded;

  const ScanScreen({
    super.key,
    required this.jobNumber,
    this.isCompleted = false,
    required this.scannedItems,
    required this.loadedItems,
    required this.isLoaded,
  });

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final TextEditingController barcodeController = TextEditingController();
  String? selectedCategory;
  late List<Map<String, String>> scannedItems;
  late List<Map<String, String>> loadedItems;
  bool isScanningCompleted = false;
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();
    isScanningCompleted = widget.isCompleted;
    isLoaded = widget.isLoaded;
    scannedItems = List.from(widget.scannedItems);
    loadedItems = List.from(widget.loadedItems);
    _updateIsLoadedStatus(); // Initial check to update isLoaded based on items and isCompleted
  }

void _selectCategory(String category) {
  String barcode = barcodeController.text.trim();
  bool alreadyScanned = scannedItems.any((item) => item['barcode'] == barcode);

  if (barcode.isNotEmpty && !alreadyScanned) {
    setState(() {
      selectedCategory = category; // Select category
      scannedItems.add({
        'barcode': barcode,
        'category': category,
      });
      barcodeController.clear(); // Clear barcode input
      selectedCategory = null; // Reset category selection
      _updateIsLoadedStatus();
    });
  } else if (alreadyScanned) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item with barcode $barcode has already been scanned.')),
    );
  }
}

  void _toggleScanningStatus(bool value) {
    setState(() {
      isScanningCompleted = value;
      _updateIsLoadedStatus();
    });
  }

  void _updateIsLoadedStatus() {
    setState(() {
      isLoaded = isScanningCompleted &&
          scannedItems.every((scannedItem) => loadedItems.any((loadedItem) => loadedItem['barcode'] == scannedItem['barcode']));
    });
  }

  // Helper function to count occurrences of each category
  Map<String, int> _getScannedCategoryCounts() {
    Map<String, int> categoryCounts = {};
    for (var item in scannedItems) {
      categoryCounts[item['category']!] = (categoryCounts[item['category']!] ?? 0) + 1;
    }
    return categoryCounts;
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
        loadedItems = List<Map<String, String>>.from(result['loadedItems']);
        isLoaded = result['isLoaded'] ?? isLoaded;
        _updateIsLoadedStatus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              enabled: !isScanningCompleted,
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
              title: Text(
                isScanningCompleted ? 'Scanning Completed.' : 'Scanning in Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isScanningCompleted ? Colors.green : Colors.red,
                ),
              ),
              value: isScanningCompleted,
              onChanged: (value) {
                _toggleScanningStatus(value);
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
                children: _getScannedCategoryCounts().entries.map((entry) {
                  return ListTile(
                    title: Text(
                      '${entry.value} x ${entry.key}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isScanningCompleted ? _openLoadScreen : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isScanningCompleted ? Colors.blue : Colors.grey,
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
      onPressed: isScanningCompleted ? null : () => _selectCategory(category),
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
}

