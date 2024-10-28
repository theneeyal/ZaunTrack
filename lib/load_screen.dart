import 'package:flutter/material.dart';

class LoadScreen extends StatefulWidget {
  final String jobNumber;
  final List<Map<String, String>> scannedItems;
  final List<String> loadedItems;
  final bool isLoaded;

  const LoadScreen({
    super.key,
    required this.jobNumber,
    required this.scannedItems,
    required this.loadedItems,
    this.isLoaded = false, // Default to false if not specified
  });

  @override
  _LoadScreenState createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  final TextEditingController loadController = TextEditingController();
  late List<String> loadedItems;
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();
    loadedItems = List.from(widget.loadedItems);
    isLoaded = widget.isLoaded; // Initialize with the value passed from the previous screen
  }

  void _addLoadItem() {
    String barcode = loadController.text.trim();
    if (barcode.isNotEmpty) {
      bool isScanned = widget.scannedItems.any((item) => item['barcode'] == barcode);

      if (isScanned) {
        if (!loadedItems.contains(barcode)) {
          setState(() {
            loadedItems.add(barcode);
            loadController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item $barcode added to loaded items')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Item $barcode is already loaded')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Barcode $barcode not found in scanned items')),
        );
      }
    }
  }

  void _toggleIsLoaded(bool value) {
    setState(() {
      isLoaded = value; // Only changes when manually toggled
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Load Items for Job ${widget.jobNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Return isLoaded and loadedItems to previous screen
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addLoadItem,
              child: const Text('Add Load Item'),
            ),
            const SizedBox(height: 20),
            // Only show the toggle if all items are loaded
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
              'Loaded Items:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: loadedItems.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('Barcode: ${loadedItems[index]}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
