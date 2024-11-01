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
  final CollectionReference jobsCollection = FirebaseFirestore.instance.collection('jobs');

  Stream<QuerySnapshot> _jobStream = FirebaseFirestore.instance
      .collection('jobs')
      .orderBy('lastModified', descending: true)
      .snapshots();

  @override
  void dispose() {
    addJobController.dispose();
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
        await jobsCollection.doc(jobNumber).set({
          'jobNumber': jobNumber,
          'isCompleted': false,
          'isLoaded': false,
          'isDespatched': false,
          'isStorePickComplete': false,
          'isYardPickComplete': false,
          'loadedItems': [],
          'scannedItems': [],
          'lastModified': FieldValue.serverTimestamp(),
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

  Future<void> _updateFirebaseJob(String jobId, Map<String, dynamic> data) async {
    try {
      data['lastModified'] = FieldValue.serverTimestamp();
      await jobsCollection.doc(jobId).update(data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update job in Firebase: $e')),
      );
    }
  }

  void _liveSearchJob(String query) {
    setState(() {
      if (query.isEmpty) {
        _jobStream = jobsCollection
            .orderBy('lastModified', descending: true)
            .snapshots();
      } else {
        _jobStream = jobsCollection
            .where('jobNumber', isGreaterThanOrEqualTo: query)
            .where('jobNumber', isLessThan: '${query}z')
            .snapshots();
      }
    });
  }

  Future<void> _deleteJob(String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this job? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await jobsCollection.doc(jobId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job deleted successfully.')),
      );
    }
  }

  Future<void> _openJobScreen(DocumentSnapshot job, {bool isEdit = false}) async {
    final jobData = job.data() as Map<String, dynamic>;
    final jobNumber = jobData['jobNumber'] ?? '';
    bool isCompleted = jobData['isCompleted'] == true;
    bool isLoaded = jobData['isLoaded'] == true;

    // Convert scannedItems to List<Map<String, dynamic>> to handle all types
    List<Map<String, dynamic>> scannedItems = (jobData['scannedItems'] ?? [])
        .map<Map<String, dynamic>>((item) => {
              'barcode': (item['barcode'] ?? '').toString(),
              'category': (item['category'] ?? '').toString(),
            })
        .toList();

    // Convert loadedItems to List<Map<String, dynamic>>, ensuring isSent is bool
    List<Map<String, dynamic>> loadedItems = (jobData['loadedItems'] ?? [])
        .map<Map<String, dynamic>>((item) => {
              'barcode': (item['barcode'] ?? '').toString(),
              'category': (item['category'] ?? '').toString(),
              'isSent': item['isSent'] == true, // Ensure isSent is a bool
            })
        .toList();

    if (isEdit || !isCompleted) {
      var result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScanScreen(
            jobNumber: jobNumber,
            isCompleted: isCompleted,
            scannedItems: scannedItems,
            loadedItems: loadedItems,
            isLoaded: isLoaded,
            isStorePickComplete: jobData['isStorePickComplete'] == true,
            isYardPickComplete: jobData['isYardPickComplete'] == true,
          ),
        ),
      );

      if (result != null) {
        _updateFirebaseJob(job.id, {
          'isCompleted': result['isCompleted'] ?? jobData['isCompleted'],
          'scannedItems': result['scannedItems'],
          'loadedItems': result['loadedItems'],
          'isLoaded': result['isLoaded'] ?? jobData['isLoaded'],
          'isStorePickComplete': result['isStorePickComplete'] ?? jobData['isStorePickComplete'],
          'isYardPickComplete': result['isYardPickComplete'] ?? jobData['isYardPickComplete'],
        });
      }
    } else {
      var result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoadScreen(
            jobNumber: jobNumber,
            scannedItems: scannedItems,
            loadedItems: loadedItems,
            isLoaded: isLoaded,
          ),
        ),
      );

      if (result != null) {
        loadedItems = result['loadedItems'];
        isLoaded = result['isLoaded'] ?? isLoaded;

        // Update Firebase with the returned loadedItems and isLoaded status
        _updateFirebaseJob(job.id, {
          'loadedItems': loadedItems,
          'isLoaded': isLoaded,
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
                    width: 150,
                    height: 150,
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: addJobController,
                    decoration: InputDecoration(
                      labelText: 'Scan or Add a Job Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: Colors.blue[50],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addJob,
                  child: const Text('Add Job'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: _liveSearchJob,
              decoration: InputDecoration(
                labelText: 'Search Job Number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                filled: true,
                fillColor: Colors.blue[50],
              ),
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

                            Color scanningStatusColor = jobData['isCompleted'] ? Colors.green : Color.fromARGB(255, 90, 90, 90);
                            Color loadingStatusColor = jobData['isLoaded'] ? Colors.green : Color.fromARGB(255, 90, 90, 90);

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              elevation: 2.0,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Job: ${jobData['jobNumber']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 4,
                                            backgroundColor: scanningStatusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Scanning: ${jobData['isCompleted'] ? "Completed" : "Active"}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: scanningStatusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 4,
                                            backgroundColor: loadingStatusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Loading: ${jobData['isLoaded'] ? "Completed" : "Active"}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: loadingStatusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () => _openJobScreen(job),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        iconSize: 20,
                                        icon: const Icon(Icons.edit, color: Colors.black),
                                        onPressed: () => _openJobScreen(job, isEdit: true),
                                      ),
                                      IconButton(
                                        iconSize: 20,
                                        icon: const Icon(Icons.delete, color: Colors.black),
                                        onPressed: () => _deleteJob(job.id),
                                      ),
                                    ],
                                  ),
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
