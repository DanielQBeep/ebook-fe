// import 'dart:developer';

// ignore_for_file: avoid_debugPrint

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dio/dio.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'dart:io' show File, Platform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  // Variables to store the shared preference data
  // String _username = '';
  // bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Method to load the shared preference data
  void _loadPreferences() async {
    // final prefs = await SharedPreferences.getInstance();
    // setState(() {
    //   _username = prefs.getString('username') ?? '';
    //   _rememberMe = prefs.getBool('rememberMe') ?? false;
    // });
  }

  Future<String> _getFileFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String file = '';
    setState(() {
      file = prefs.getString('secureFilename') ?? '';
    });
    // debugPrint('File: $file');
    return file;
  }

  Future<Uint8List?> retrieveSecurePdfData(String filename) async {
    debugPrint(filename);
    const storage = FlutterSecureStorage();
    debugPrint('Retrieving PDF data from secure storage...');
    final prefs = await SharedPreferences.getInstance();
    final file = prefs.getString(filename) ?? '';
    debugPrint('File retrieved');
    if (file == '') {
      return null;
    }

    final encodedData = await storage.read(key: file);
    if (encodedData != null) {
      return base64Decode(encodedData);
    }
    return null;
  }

  Future<void> downloadAndSavePdf() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check storage permission
    debugPrint('Checking storage permission...');
    final storageStatus = await Permission.manageExternalStorage.request();
    if (storageStatus != PermissionStatus.granted) {
      // Handle permission denial here (e.g., show a dialog)
      return;
    }

    debugPrint('Storage permission granted: $storageStatus');
    // 2. Create a Dio instance
    final dio = Dio();

    // 3. Download the PDF
    try {
      final response = await dio.get(
        'http://10.0.2.2:3000/api/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      debugPrint("Status code: ${response.statusCode}");
      // 4. Get local storage directory path (adjust based on platform)
      // final directory = Platform.isAndroid
      //     ? await getExternalStorageDirectory() // For Android
      //     : await getApplicationDocumentsDirectory(); // For iOS/Web

      const storage = FlutterSecureStorage();

      // debugPrint("Platform: ${Platform.isAndroid}");
      // debugPrint("Directory:$directory");

      // if (directory == null) {
      //   throw Exception('Failed to get storage directory');
      // }

      // 5. Create a unique filename
      // final filename = '${DateTime.now().millisecondsSinceEpoch}.pdf';
      // final filePath = '${directory.path}/$filename';

      // 6. Write downloaded data to file
      // await File(filePath).writeAsBytes(response.data);

      // 7. Show success message (optional)
      // debugPrint('PDF downloaded and saved to: $filePath');
      final secureFilename = '${DateTime.now().millisecondsSinceEpoch}.pdf';
      prefs.setString('secureFilename', secureFilename);
      // debugPrint(storage.readAll().toString());
      await storage.write(

          // ..
          key: secureFilename,
          value: base64.encode(response.data));
      debugPrint('PDF data stored securely: $secureFilename');
    } on DioException catch (error) {
      debugPrint('Download error: $error');
    } catch (error) {
      debugPrint('Error: $error');
    }
  }

  String filename = '';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Shared Preferences Demo'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              // TextField(
              //   decoration: const InputDecoration(
              //     labelText: 'Username',
              //     hintText: 'Enter your username',
              //   ),
              //   onChanged: (value) {
              //     setState(() {
              //       _username = value;
              //     });
              //   },
              // ),
              // CheckboxListTile(
              //   title: const Text('Remember me!'),
              //   value: _rememberMe,
              //   onChanged: (value) {
              //     setState(() {
              //       if (value != null) _rememberMe = value;
              //     });
              //   },
              // ),
              // ElevatedButton(
              //   child: const Text('Save'),
              //   onPressed: () async {
              //     final prefs = await SharedPreferences.getInstance();
              //     prefs.setString('username', _username);
              //     prefs.setBool('rememberMe', _rememberMe);
              //   },
              // ),
              ElevatedButton(
                onPressed: downloadAndSavePdf,
                child: const Text('Download PDF'),
              ),
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    final filename = await _getFileFromPrefs();
                    final pdfData = await retrieveSecurePdfData(filename);
                    if (pdfData != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Preview PDF'),
                            ),
                            body: const PDFView(
                              filePath: '',
                              pageSnap: true,
                              fitPolicy: FitPolicy.BOTH,
                              // controller: PDFViewController(),
                              // document: pdfData != null
                              // ? PdfDocument.openData(pdfData)
                              // : null,
                              // bytes: pdfData, // Pass the retrieved Uint8List data
                            ),
                          ),
                        ),
                      );
                    } else {
                      debugPrint(
                          'Failed to retrieve PDF data from secure storage');
                    }
                  },
                  child: const Text('Preview PDF'),
                ),
              ),

              FutureBuilder<String>(
                future: _getFileFromPrefs(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    // When the username is available, display it
                    return Text(snapshot.data ?? '');
                  } else {
                    // If there's a loading state or error, display a placeholder
                    return const Text('Loading username...');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
