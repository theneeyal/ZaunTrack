import 'package:flutter/material.dart';
import 'load_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScanScreen extends StatefulWidget {
  final String jobNumber;
  final bool isCompleted;
  final List<Map<String, dynamic>> scannedItems;
  final List<Map<String, dynamic>> loadedItems;
  final bool isLoaded;
  final bool isStorePickComplete;
  final bool isYardPickComplete;
  final bool hasStockItems;
  final bool isStockPickComplete;

  const ScanScreen({
    super.key,
    required this.jobNumber,
    this.isCompleted = false,
    required this.scannedItems,
    required this.loadedItems,
    required this.isLoaded,
    this.isStorePickComplete = false,
    this.isYardPickComplete = false,
    this.hasStockItems = false,
    this.isStockPickComplete = false,
  });

  @override
  ScanScreenState createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
  final TextEditingController barcodeController = TextEditingController();
  final FocusNode barcodeFocusNode = FocusNode();
  String? selectedCategory;
  late List<Map<String, dynamic>> scannedItems;
  late List<Map<String, dynamic>> loadedItems;
  bool isScanningCompleted = false;
  bool isStorePickComplete = false;
  bool isYardPickComplete = false;
  bool isLoaded = false;
  bool hasStockItems = false;
  bool isStockPickComplete = false;

  @override
  void initState() {
    super.initState();
    isStorePickComplete = widget.isStorePickComplete;
    isYardPickComplete = widget.isYardPickComplete;
    isLoaded = widget.isLoaded;
    isScanningCompleted = widget.isCompleted;
    hasStockItems = widget.hasStockItems;
    isStockPickComplete = widget.isStockPickComplete;
    scannedItems = List.from(widget.scannedItems);
    loadedItems = List.from(widget.loadedItems);
    _checkLoadingConditions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    barcodeController.dispose();
    barcodeFocusNode.dispose();
    super.dispose();
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
        'isStorePickComplete': isStorePickComplete,
        'isYardPickComplete': isYardPickComplete,
        'isCompleted': isScanningCompleted,
        'hasStockItems': hasStockItems,
        'isStockPickComplete': isStockPickComplete,
        'scannedItems': scannedItems,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update job in Firebase: $e')),
        );
      }
    }
  }

  Future<void> _openLoadScreen() async {
    var result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoadScreen(
          jobNumber: widget.jobNumber,
          scannedItems: scannedItems,
          loadedItems: loadedItems,
          isLoaded: isLoaded,
          isScanningCompleted: isScanningCompleted,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        loadedItems = List<Map<String, dynamic>>.from(result['loadedItems']);
        isLoaded = result['isLoaded'] ?? isLoaded;
      });
      _updateFirebase();
    }
  }

  void _toggleStockItems(bool? value) {
    setState(() {
      hasStockItems = value ?? false;
      _updateScanningCompletedStatus();
    });
    _updateFirebase();
  }

  void _selectCategory(String category) {
    if (isStorePickComplete && isYardPickComplete && (!hasStockItems || isStockPickComplete)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot add items when all toggles are complete.')),
        );
      }
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
        _checkLoadingConditions();
        _updateFirebase();
      });
      barcodeFocusNode.requestFocus();
    } else if (alreadyScanned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item with barcode $barcode has already been scanned.')),
      );
      barcodeFocusNode.requestFocus();
    }
  }

  void _deleteScannedItem(String barcode) {
    setState(() {
      scannedItems.removeWhere((item) => item['barcode'] == barcode);
      loadedItems.removeWhere((item) => item['barcode'] == barcode);
    });
    _updateFirebase();
    _checkLoadingConditions();
    barcodeFocusNode.requestFocus();
  }

  void _toggleStorePickStatus(bool value) {
    setState(() {
      isStorePickComplete = value;
      _updateScanningCompletedStatus();
      _updateFirebase();
    });
  }

  void _toggleYardPickStatus(bool value) {
    setState(() {
      isYardPickComplete = value;
      _updateScanningCompletedStatus();
      _updateFirebase();
    });
  }

  void _toggleStockPickStatus(bool value) {
    setState(() {
      isStockPickComplete = value;
      _updateScanningCompletedStatus();
      _updateFirebase();
    });
  }

  void _updateScanningCompletedStatus() {
    setState(() {
      isScanningCompleted = isStorePickComplete && isYardPickComplete && (!hasStockItems || isStockPickComplete);
      _checkLoadingConditions();
    });
  }

  bool _allItemsSent() {
    return loadedItems.every((item) => item['isSent'] == true);
  }

  void _checkLoadingConditions() {
    setState(() {
      if (!isScanningCompleted || !_allItemsSent()) {
        isLoaded = false;
      }
    });
  }

  Future<void> _navigateBack() async {
    await _updateFirebase();
    await Future.delayed(const Duration(milliseconds: 500)); 
    if (mounted) {
      Navigator.pop(context, {
        'isCompleted': isScanningCompleted,
        'scannedItems': scannedItems,
        'loadedItems': loadedItems,
        'isLoaded': isLoaded,
        'isStorePickComplete': isStorePickComplete,
        'isYardPickComplete': isYardPickComplete,
        'hasStockItems': hasStockItems,
        'isStockPickComplete': isStockPickComplete,
      });
    }
  }

  String _formatBarcode(String barcode) {
    if (barcode.length <= 3) return barcode;
    return barcode.substring(0, 4) + '*' * (barcode.length - 4);
  }

  @override
  Widget build(BuildContext context) {
    bool isInputDisabled = isStorePickComplete && isYardPickComplete && (!hasStockItems || isStockPickComplete);

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Items for Job ${widget.jobNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                title: const Text(
                  'Does this job have stock items?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                value: hasStockItems,
                onChanged: _toggleStockItems,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: barcodeController,
                focusNode: barcodeFocusNode,
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
                onChanged: _toggleStorePickStatus,
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
                onChanged: _toggleYardPickStatus,
                activeColor: Colors.green,
                inactiveThumbColor: Colors.redAccent,
                inactiveTrackColor: Colors.red[200],
              ),
              if (hasStockItems)
                SwitchListTile(
                  title: const Text(
                    'Stock Pick Complete',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  value: isStockPickComplete,
                  onChanged: _toggleStockPickStatus,
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scannedItems.length,
                itemBuilder: (context, index) {
                  final item = scannedItems[index];
                  final barcode = item['barcode']!;
                  final maskedBarcode = _formatBarcode(barcode);
                  final category = item['category'];
                  return ListTile(
                    title: Text(
                      '$maskedBarcode                 Category: $category',
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteScannedItem(barcode),
                    ),
                  );
                },
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
}
