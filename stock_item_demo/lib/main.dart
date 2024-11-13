import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Item Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const JobStockScreen(),
    );
  }
}

class JobStockScreen extends StatefulWidget {
  const JobStockScreen({super.key});

  @override
  State<JobStockScreen> createState() => _JobStockScreenState();
}

class _JobStockScreenState extends State<JobStockScreen> {
  bool hasStockItems = false;

  // Lists to hold entries for each category
  List<Map<String, dynamic>> meshItems = [];
  List<Map<String, dynamic>> postItems = [];
  List<Map<String, dynamic>> clampBarItems = [];

  // Dropdown options for fixed specific widths
  final List<String> meshWidths = ['1000mm', '1500mm', '2000mm'];
  final List<String> postHeights = ['1200mm', '1800mm', '2400mm'];
  final List<String> clampBarSizes = ['500mm', '750mm', '1000mm'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Items for Job"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Does this job have stock items?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      hasStockItems = false;
                      meshItems.clear();
                      postItems.clear();
                      clampBarItems.clear();
                    });
                  },
                  child: const Text("NO"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      hasStockItems = true;
                      if (meshItems.isEmpty) meshItems.add(_createNewItem());
                      if (postItems.isEmpty) postItems.add(_createNewItem());
                      if (clampBarItems.isEmpty) clampBarItems.add(_createNewItem());
                    });
                  },
                  child: const Text("YES"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (hasStockItems) ...[
              _buildCategorySection("Mesh", meshItems, meshWidths, (index) => _addMeshItem(index)),
              const SizedBox(height: 20),
              _buildCategorySection("Posts", postItems, postHeights, (index) => _addPostItem(index)),
              const SizedBox(height: 20),
              _buildCategorySection("Clamp Bars", clampBarItems, clampBarSizes, (index) => _addClampBarItem(index)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Handle submit or save logic here
                  print("Mesh Items: $meshItems");
                  print("Post Items: $postItems");
                  print("Clamp Bar Items: $clampBarItems");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Stock items saved!")),
                  );
                },
                child: const Text("Save Stock Items"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _createNewItem() {
    return {"width": null, "quantity": null};
  }

  void _addMeshItem(int index) {
    setState(() {
      meshItems.add(_createNewItem());
    });
  }

  void _addPostItem(int index) {
    setState(() {
      postItems.add(_createNewItem());
    });
  }

  void _addClampBarItem(int index) {
    setState(() {
      clampBarItems.add(_createNewItem());
    });
  }

  Widget _buildCategorySection(
      String title, List<Map<String, dynamic>> items, List<String> dropdownOptions, Function(int) onAddMore) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildItemRow(items, index, dropdownOptions);
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => onAddMore(items.length),
            icon: const Icon(Icons.add),
            label: Text("Add More $title"),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(List<Map<String, dynamic>> items, int index, List<String> dropdownOptions) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: "Width",
              border: OutlineInputBorder(),
            ),
            value: items[index]["width"],
            items: dropdownOptions
                .map((width) => DropdownMenuItem(value: width, child: Text(width)))
                .toList(),
            onChanged: (value) {
              setState(() {
                items[index]["width"] = value;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: TextFormField(
            decoration: const InputDecoration(
              labelText: "Quantity",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                items[index]["quantity"] = int.tryParse(value);
              });
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() {
              items.removeAt(index);
            });
          },
        ),
      ],
    );
  }
}
