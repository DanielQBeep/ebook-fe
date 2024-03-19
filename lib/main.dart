import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final _storage = const FlutterSecureStorage();
  String? _secureFilename;
  bool _isLoading = false;
  List<String> downloadedPdfFilenames = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void enableLoading() {
    setState(() {
      _isLoading = true;
    });
  }

  void disableLoading() {
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _secureFilename = prefs.getString('secureFilename');
  }

  Future<Uint8List?> _retrieveSecurePdfData(String filename) async {
    if (_secureFilename == null) return null;
    // final encodedData = await _storage.read(key: _secureFilename!);
    final encodedData = await _storage.read(key: filename);
    if (encodedData != null) {
      // return base64Decode(encodedData);
      return base64Decode(encodedData);
    }
    return null;
  }

  Future<void> _downloadAndSavePdf() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('secureFilename');
    enableLoading();

  debugPrint('test');

    final storageStatus = await Permission.manageExternalStorage.request();
    final storageStatuss = await Permission.mediaLibrary.request();
    final storageStatusss = await Permission.storage.request();
    if (!storageStatusss.isGranted) {
      disableLoading();
      debugPrint('externalstorage$storageStatus');
      debugPrint('media$storageStatuss');
      debugPrint('storage$storageStatusss');
  debugPrint('perm !allow');
  openAppSettings();

      return;
    }

    final dio = Dio();

    try {
      final response = await dio.get(
        // 'http://10.0.2.2:3000/api/pdf',
        'https://ebook-api-git-main-danielqbeeps-projects.vercel.app/api/pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      final secureFilename = '${DateTime.now().millisecondsSinceEpoch}.pdf';
      prefs.setString('secureFilename', secureFilename);
      _addDownloadedPdfFilename(secureFilename);

  debugPrint('file downloaded');


      await _storage.write(
        key: secureFilename,
        value: base64.encode(response.data),
        // value: response.data,
      );

      setState(() {
        _secureFilename = secureFilename;
        disableLoading();
  debugPrint('success');

      });
    } on DioException catch (error) {
      debugPrint('Download error: $error');
      disableLoading();
    } catch (error) {
      debugPrint('Error: $error');
      disableLoading();
    }
  }

  Future<void> _addDownloadedPdfFilename(String filename) async {
    setState(() {
      downloadedPdfFilenames.insert(0, filename); // Add to the top of the list
      _saveDownloadedPdfFilenames();
    });
  }

  Future<void> _saveDownloadedPdfFilenames() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('downloadedPdfFilenames', downloadedPdfFilenames);
  }

  Future<void> _removeAllPdfs() async {
    setState(() {
      downloadedPdfFilenames.clear();
      _saveDownloadedPdfFilenames();
      _secureFilename = ''; // Clear the currently displayed PDF
      _storage.deleteAll(); // Delete all PDF data from secure storage
    });
  }

  Future<void> _removePdf(String filename) async {
    setState(() {
      downloadedPdfFilenames.removeWhere((f) => f == filename);
      _saveDownloadedPdfFilenames();
    });
  }

  Future<void> _loadAndPreviewPdf(String filename, BuildContext context) async {
    final pdfData = await _retrieveSecurePdfData(filename);
    if (pdfData != null) {
      File? tempFile;
      try {
        final tempDirPath = await getTemporaryDirectory();
        tempFile = File('${tempDirPath.path}/$filename');
        await tempFile.writeAsBytes(pdfData);
      } catch (error) {
        debugPrint('Error: $error');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text('Preview PDF: $filename'),
            ),
            body: PDFView(
              filePath: tempFile?.path ?? '',
              pageSnap: true,
              fitPolicy: FitPolicy.WIDTH,
            ),
          ),
        ),
      );
    } else {
      debugPrint('Failed to retrieve PDF data for: $filename');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Shared Preferences Demo'),
            ),
            body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: <Widget>[
                  ElevatedButton(
                    onPressed: () {
                      _isLoading ? null : _downloadAndSavePdf();
                    },
                    // onPressed: _downloadAndSavePdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLoading ? Colors.red : null,
                      foregroundColor: _isLoading ? Colors.white : null,
                    ),
                    child: const Text('Download PDF'),
                  ),
                  Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () async {
                        final pdfData =
                            await _retrieveSecurePdfData(_secureFilename!);
                        if (pdfData != null) {
                          // final base64EncodedData = base64Encode(pdfData);

                          File? tempFile;
                          try {
                            final tempDirPath = await getTemporaryDirectory();
                            tempFile = File(
                                '${tempDirPath.path}/${DateTime.now().millisecondsSinceEpoch}.pdf');
                            await tempFile
                                // .writeAsBytes(base64Decode(base64EncodedData));
                                .writeAsBytes(pdfData);
                          } catch (error) {
                            debugPrint('Error: $error');
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(
                                  title: const Text('Preview PDF'),
                                ),
                                body: PDFView(
                                  filePath: tempFile?.path ?? '',
                                  pageSnap: true,
                                  fitPolicy: FitPolicy.WIDTH,
                                ),
                              ),
                            ),
                          );
                        } else {
                          debugPrint(
                            'Failed to retrieve PDF data from secure storage',
                          );
                        }
                      },
                      child: const Text('Preview PDF'),
                    ),
                  ),
                  FutureBuilder<String>(
                    future: _loadPreferences()
                        .then((_) => Future.value(_secureFilename)),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(snapshot.data ?? '');
                      } else {
                        return const Text('Loading...');
                      }
                    },
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: downloadedPdfFilenames.length,
                      itemBuilder: (context, index) {
                        final filename = downloadedPdfFilenames[index];
                        return ListTile(
                          title: Text(filename),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => _removePdf(filename),
                              ),
                              // ... (other trailing buttons)
                            ],
                          ),
                          onTap: () => _loadAndPreviewPdf(
                              filename, context), // Pass context
                        );
                      },
                    ),
                  ),
                ])),
            floatingActionButton: FloatingActionButton(
              onPressed: _removeAllPdfs,
              child: const Text('Remove All PDFs'),
            )));
  }
}
