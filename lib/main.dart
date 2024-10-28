import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final CollectionReference jobsCollection = FirebaseFirestore.instance.collection('jobs');

  Stream<QuerySnapshot> _jobStream = FirebaseFirestore.instance
      .collection('jobs')
      .orderBy('jobNumber')
      .snapshots();

  @override
  void dispose() {
    addJobController.dispose();
    searchJobController.dispose();
    super.dispose();
  }

  Future<void> _addJob() async {
    String jobNumber = addJobController.text.trim();
    if (jobNumber.isNotEmpty) {
      final query = await jobsCollection
          .where('jobNumber', isEqualTo: jobNumber)
          .get();

      if (query.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job $jobNumber already exists.')),
        );
      } else {
        await jobsCollection.add({
          'jobNumber': jobNumber,
          'isCompleted': false,
          'isLoaded': false,
          'isDespatched': false,
          'loadedItems': [],
          'scannedItems': [],
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
      if (query.isEmpty) {
        _jobStream = jobsCollection.orderBy('jobNumber').snapshots();
      } else {
        _jobStream = jobsCollection
            .where('jobNumber', isGreaterThanOrEqualTo: query)
            .where('jobNumber', isLessThan: query + 'z')
            .snapshots();
      }
    });
  }

  Future<void> _deleteJob(String jobId) async {
    await jobsCollection.doc(jobId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Job deleted successfully.')),
    );
  }

  void _openJobScreen(DocumentSnapshot job, {bool isEdit = false}) async {
    final jobData = job.data() as Map<String, dynamic>;
    final jobNumber = jobData['jobNumber'];
    bool isCompleted = jobData['isCompleted'] ?? false;

    List<Map<String, String>> scannedItems = (jobData['scannedItems'] as List)
        .map((item) => Map<String, String>.from(item as Map))
        .toList();

    // Directly navigate to ScanScreen or LoadScreen based on user action
    if (isEdit || !isCompleted) {
      // Open ScanScreen for editing or when job is not completed
      var result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScanScreen(
            jobNumber: jobNumber,
            isCompleted: jobData['isCompleted'],
            scannedItems: scannedItems,
            loadedItems: List<String>.from(jobData['loadedItems']),
            isLoaded: jobData['isLoaded'] ?? false,
          ),
        ),
      );

      // Update job status after returning from ScanScreen
      if (result != null) {
        bool updatedIsCompleted = result['isCompleted'] ?? jobData['isCompleted'];
        
        jobsCollection.doc(job.id).update({
          'isCompleted': updatedIsCompleted,
          'scannedItems': result['scannedItems'],
          'loadedItems': result['loadedItems'],
          'isLoaded': result['isLoaded'] ?? jobData['isLoaded'],
        });
      }
    } else {
      // If not in edit mode and job is completed, open LoadScreen directly
      var result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoadScreen(
            jobNumber: jobNumber,
            scannedItems: scannedItems,
            loadedItems: List<String>.from(jobData['loadedItems']),
            isLoaded: jobData['isLoaded'] ?? false,
          ),
        ),
      );

      if (result != null) {
        jobsCollection.doc(job.id).update({
          'loadedItems': result['loadedItems'],
          'isLoaded': result['isLoaded'] ?? jobData['isLoaded'],
        });
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
              child: StreamBuilder<QuerySnapshot>(
                stream: _jobStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final jobs = snapshot.data!.docs;
                  return jobs.isEmpty
                      ? const Center(child: Text('No jobs available.'))
                      : ListView.builder(
                          itemCount: jobs.length,
                          itemBuilder: (context, index) {
                            final job = jobs[index];
                            final jobData = job.data() as Map<String, dynamic>;

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              elevation: 4.0,
                              child: ListTile(
                                title: Text('Job: ${jobData['jobNumber']}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Scanning Status: ${jobData['isCompleted'] == true ? "Completed" : "Active"}'),
                                    Text('Loading Status: ${jobData['isLoaded'] == true ? "Completed" : "Not Loaded"}'),
                                  ],
                                ),
                                onTap: () => _openJobScreen(job),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _openJobScreen(job, isEdit: true),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteJob(job.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
