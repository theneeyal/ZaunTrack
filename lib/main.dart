import 'package:flutter/material.dart';
import 'scan_screen.dart';
import 'load_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZaunTrack',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const JobScreen(),
    );
  }
}

class JobScreen extends StatefulWidget {
  const JobScreen({super.key});

  @override
  _JobScreenState createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  final TextEditingController addJobController = TextEditingController();
  final TextEditingController searchJobController = TextEditingController();
  List<Map<String, dynamic>> jobList = [];
  List<Map<String, dynamic>> filteredJobList = [];

  @override
  void initState() {
    super.initState();
    filteredJobList = jobList;
  }

  @override
  void dispose() {
    addJobController.dispose();
    searchJobController.dispose();
    super.dispose();
  }

  void _addJob() {
    String jobNumber = addJobController.text.trim();
    if (jobNumber.isNotEmpty) {
      bool jobExists = jobList.any((job) => job['jobNumber'] == jobNumber);

      if (jobExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job $jobNumber already exists.')),
        );
      } else {
        Map<String, dynamic> newJob = {
          'jobNumber': jobNumber,
          'isCompleted': false,
          'isLoaded': false,
          'isDespatched': false,
          'loadedItems': <String>[],
          'scannedItems': <Map<String, String>>[],
        };
        setState(() {
          jobList.add(newJob);
          filteredJobList = jobList;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created new Job: $jobNumber')),
        );
      }
      addJobController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a job number to add.')),
      );
    }
  }

  void _liveSearchJob(String query) {
    setState(() {
      filteredJobList = jobList
          .where((job) =>
              job['jobNumber'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _deleteJob(int index) {
    setState(() {
      jobList.removeAt(index);
      filteredJobList = jobList;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Job deleted successfully.')),
    );
  }

  // Updated _openJobScreen method with edit parameter
  void _openJobScreen(String jobNumber, {bool isEdit = false}) async {
    int jobIndex = jobList.indexWhere((job) => job['jobNumber'] == jobNumber);
    if (jobIndex == -1) return;

    bool isCompleted = jobList[jobIndex]['isCompleted'] ?? false;

    if (isCompleted && !isEdit) {
      // Navigate directly to LoadScreen if isCompleted is true and it's not an edit action
      var result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoadScreen(
            jobNumber: jobNumber,
            scannedItems: List<Map<String, String>>.from(jobList[jobIndex]['scannedItems']),
            loadedItems: List<String>.from(jobList[jobIndex]['loadedItems']),
            isLoaded: jobList[jobIndex]['isLoaded'] ?? false,
          ),
        ),
      );

      // Update job with changes from LoadScreen
      if (result != null) {
        setState(() {
          jobList[jobIndex]['loadedItems'] = List<String>.from(result['loadedItems']);
          jobList[jobIndex]['isLoaded'] = result['isLoaded'] ?? jobList[jobIndex]['isLoaded'];
        });
      }
    } else {
      // Navigate to ScanScreen (ignoring isCompleted if it's an edit action)
      var result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScanScreen(
            jobNumber: jobNumber,
            isCompleted: jobList[jobIndex]['isCompleted'],
            scannedItems: List<Map<String, String>>.from(jobList[jobIndex]['scannedItems']),
            loadedItems: List<String>.from(jobList[jobIndex]['loadedItems']),
            isLoaded: jobList[jobIndex]['isLoaded'] ?? false,
          ),
        ),
      );

      // Update job with changes from ScanScreen
      if (result != null) {
        setState(() {
          jobList[jobIndex]['isCompleted'] = result['isCompleted'] ?? false;
          jobList[jobIndex]['scannedItems'] = List<Map<String, String>>.from(result['scannedItems']);
          jobList[jobIndex]['loadedItems'] = List<String>.from(result['loadedItems']);
          jobList[jobIndex]['isLoaded'] = result['isLoaded'] ?? false;
        });

        // If job is now completed, directly open LoadScreen
        if (jobList[jobIndex]['isCompleted'] == true && !isEdit) {
          _openJobScreen(jobNumber); // This will navigate directly to LoadScreen
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZaunTrack Job Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/app_icon.png',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ZaunTrack',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: addJobController,
              decoration: InputDecoration(
                labelText: 'Enter Job Number to Add',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                filled: true,
                fillColor: Colors.blue[50],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _addJob,
              child: const Text('Add Job'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: searchJobController,
              decoration: InputDecoration(
                labelText: 'Search Job Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                filled: true,
                fillColor: Colors.blue[50],
              ),
              onChanged: _liveSearchJob,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: filteredJobList.isEmpty
                  ? const Center(
                      child: Text('No jobs available.'),
                    )
                  : ListView.builder(
                      itemCount: filteredJobList.length,
                      itemBuilder: (context, index) {
                        final job = filteredJobList[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 4.0,
                          child: ListTile(
                            title: Text('Job: ${job['jobNumber']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scanning Status: ${job['isCompleted'] == true ? "Completed" : "Active"}'),
                                Text('Loading Status: ${job['isLoaded'] == true ? "Completed" : "Not Loaded"}'),
                              ],
                            ),
                            onTap: () => _openJobScreen(job['jobNumber']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _openJobScreen(job['jobNumber'], isEdit: true), // Open ScanScreen for editing
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteJob(index),
                                ),
                              ],
                            ),
                          ),
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
