import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scan_screen.dart';
import 'load_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';

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
  JobScreenState createState() => JobScreenState();
}

class JobScreenState extends State<JobScreen> {
  final TextEditingController addJobController = TextEditingController();
  final CollectionReference jobsCollection = FirebaseFirestore.instance.collection('jobs');
  
  // Stream for live job data
  Stream<QuerySnapshot> _jobStream = FirebaseFirestore.instance
      .collection('jobs')
      .orderBy('createdAt', descending: true)
      .snapshots();

  @override
  void dispose() {
    addJobController.dispose();
    super.dispose();
  }

  // Add new job function
  Future<void> _addJob() async {
    String jobNumber = addJobController.text.trim().toUpperCase();

    if (jobNumber.isNotEmpty) {
      final query = await jobsCollection.where('jobNumber', isEqualTo: jobNumber).get();

      if (query.docs.isNotEmpty) {
        _showJobExistsDialog(jobNumber, query.docs.first);
      } else {
        await _createNewJob(jobNumber);
      }
      addJobController.clear();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a job number to add.')),
        );
      }
    }
  }

  // Show dialog if job exists
  void _showJobExistsDialog(String jobNumber, DocumentSnapshot existingJobDoc) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Job Already Exists'),
            content: Text('Job $jobNumber already exists. Do you want to go to the scan screen?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openJobScreen(existingJobDoc, isEdit: true);
                },
                child: Text('Go to Scan Screen'),
              ),
            ],
          );
        },
      );
    }
  }

  // Create a new job in Firebase
  Future<void> _createNewJob(String jobNumber) async {
    try {
      await jobsCollection.doc(jobNumber).set({
        'jobNumber': jobNumber,
        'isCompleted': false,
        'isLoaded': false,
        'isDespatched': false,
        'isStorePickComplete': false,
        'isYardPickComplete': false,
        'hasStockItems': false,
        'isStockPickComplete': false,
        'locked': false,
        'loadedItems': [],
        'scannedItems': [],
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'lastModified': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created new Job: $jobNumber')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding job: $e')),
        );
      }
    }
  }

  // Open a job for scanning/loading
// Open a job for scanning/loading
  Future<void> _openJobScreen(DocumentSnapshot job, {bool isEdit = false}) async {
    final jobData = job.data() as Map<String, dynamic>;
    final jobNumber = jobData['jobNumber'] ?? '';
    bool isCompleted = jobData['isCompleted'] == true;
    bool isLoaded = jobData['isLoaded'] == true;

    List<Map<String, dynamic>> scannedItems = (jobData['scannedItems'] ?? [])
        .map<Map<String, dynamic>>((item) => {
              'barcode': (item['barcode'] ?? '').toString(),
              'category': (item['category'] ?? '').toString(),
            })
        .toList();

    List<Map<String, dynamic>> loadedItems = (jobData['loadedItems'] ?? [])
        .map<Map<String, dynamic>>((item) => {
              'barcode': (item['barcode'] ?? '').toString(),
              'category': (item['category'] ?? '').toString(),
              'isSent': item['isSent'] == true,
            })
        .toList();

    bool isLocked = jobData.containsKey('locked') ? jobData['locked'] == true : false;

    if (isLocked && !isEdit) {
      // Prevent accessing the job if it's locked and not in edit mode
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This job is currently being accessed by another user.')),
        );
      }
      return; // Prevent access if job is locked and not editing
    }

    // If we're opening the job for editing, unlock it immediately
    if (isEdit) {
      await jobsCollection.doc(job.id).update({
        'locked': false, // Reset lock to false when editing
      });
    }

    // Lock the job when accessed for scanning/loading
    await jobsCollection.doc(job.id).update({
      'locked': true,
    });

    try {
      var result;
      if (isEdit || !isCompleted) {
        result = await Navigator.push(
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
              hasStockItems: jobData['hasStockItems'] == true,
              isStockPickComplete: jobData['isStockPickComplete'] == true,
            ),
          ),
        );
      } else {
        result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoadScreen(
              jobNumber: jobNumber,
              scannedItems: scannedItems,
              loadedItems: loadedItems,
              isLoaded: isLoaded,
              isScanningCompleted: isCompleted,
            ),
          ),
        );
      }

      if (mounted && result != null) {
        _updateFirebaseJob(job.id, {
          'isCompleted': result['isCompleted'] ?? jobData['isCompleted'],
          'scannedItems': result['scannedItems'],
          'loadedItems': result['loadedItems'],
          'isLoaded': result['isLoaded'] ?? jobData['isLoaded'],
          'isStorePickComplete': result['isStorePickComplete'] ?? jobData['isStorePickComplete'],
          'isYardPickComplete': result['isYardPickComplete'] ?? jobData['isYardPickComplete'],
          'hasStockItems': result['hasStockItems'] ?? jobData['hasStockItems'],
          'isStockPickComplete': result['isStockPickComplete'] ?? jobData['isStockPickComplete'],
        });
      }
    } finally {
      // Unlock the job when leaving the screen
      if (mounted) {
        await jobsCollection.doc(job.id).update({
          'locked': false,
        });
      }
    }
  }

  // Update job in Firestore
  Future<void> _updateFirebaseJob(String jobId, Map<String, dynamic> data) async {
    try {
      // Ensure 'locked' field exists and is set to 'false' by default if not present
      if (!data.containsKey('locked')) {
        data['locked'] = false;
      }

      data['lastModified'] = FieldValue.serverTimestamp();
      await jobsCollection.doc(jobId).update(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update job in Firebase: $e')),
        );
      }
    }
  }

  // Live search for jobs
  void _liveSearchJob(String query) {
    setState(() {
      query = query.toUpperCase();
      if (query.isEmpty) {
        _jobStream = jobsCollection
            .orderBy('createdAt', descending: true)
            .snapshots();
      } else {
        _jobStream = jobsCollection
            .where('jobNumber', isGreaterThanOrEqualTo: query)
            .where('jobNumber', isLessThan: '${query}Z')
            .snapshots();
      }
    });
  }

  // Delete job with confirmation
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job deleted successfully.')),
        );
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
                  if (jobs.isEmpty) {
                    return const Center(child: Text('No jobs available.'));
                  }

                  String? lastDate;
                  List<Widget> jobList = [];
                  for (var job in jobs) {
                    final jobData = job.data() as Map<String, dynamic>;
                    final createdAtTimestamp = jobData['createdAt'] as Timestamp?;
                    final createdAtDate = createdAtTimestamp?.toDate();
                    final formattedDate = createdAtDate != null
                        ? DateFormat.yMMMd().format(createdAtDate)
                        : '';

                    if (lastDate != formattedDate) {
                      lastDate = formattedDate;
                      jobList.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      );
                    }

                    Color scanningStatusColor = jobData['isCompleted'] ? Colors.green : Color.fromARGB(255, 90, 90, 90);
                    Color loadingStatusColor = jobData['isLoaded'] ? Colors.green : Color.fromARGB(255, 90, 90, 90);

                    jobList.add(Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 2.0),
                      elevation: 1.0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
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
                    ));
                  }

                  return ListView(
                    children: jobList,
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
