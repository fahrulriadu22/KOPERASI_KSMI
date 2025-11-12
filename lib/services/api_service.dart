import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
// ✅ TAMBAH IMPORT INI DI ATAS FILE api_service.dart
import 'dart:typed_data'; // ✅ UNTUK Uint8List

class ApiService {
  static const String baseUrl = 'http://demo.bsdeveloper.id/api';
  
  String _deviceId = '12341231313131';
  String _deviceToken = '1234232423424';

  final ImagePicker _imagePicker = ImagePicker();

  // ✅ GET AUTH HEADERS UNTUK REQUEST TANPA TOKEN
  Map<String, String> getAuthHeaders() {
    return {
      'DEVICE-ID': _deviceId,
      'DEVICE-TOKEN': _deviceToken,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
  }

  // ✅ GET PROTECTED HEADERS DENGAN TOKEN
  Future<Map<String, String>> getProtectedHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = prefs.getString('token');
      final sessionCookie = prefs.getString('ci_session');
      
      final headers = <String, String>{
        'DEVICE-ID': _deviceId,
        'DEVICE-TOKEN': _deviceToken,
        'Content-Type': 'application/x-www-form-urlencoded',
      };
      
      if (userKey != null && userKey.isNotEmpty) {
        headers['x-api-key'] = userKey;
      } else {
        print('⚠️ Token tidak ditemukan di SharedPreferences');
      }
      
      // Tambahkan cookie session jika ada
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = 'ci_session=$sessionCookie';
      }
      
      return headers;
    } catch (e) {
      print('❌ Error getProtectedHeaders: $e');
      return {
        'DEVICE-ID': _deviceId,
        'DEVICE-TOKEN': _deviceToken,
        'Content-Type': 'application/x-www-form-urlencoded',
      };
    }
  }

  // ✅ GET MULTIPART HEADERS UNTUK UPLOAD FILE
  Future<Map<String, String>> getMultipartHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = prefs.getString('token');
      final sessionCookie = prefs.getString('ci_session');
      
      final headers = <String, String>{
        'DEVICE-ID': _deviceId,
        'DEVICE-TOKEN': _deviceToken,
      };
      
      if (userKey != null && userKey.isNotEmpty) {
        headers['x-api-key'] = userKey;
      }
      
      // Tambahkan cookie session jika ada
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = 'ci_session=$sessionCookie';
      }
      
      return headers;
    } catch (e) {
      print('❌ Error getMultipartHeaders: $e');
      return {
        'DEVICE-ID': _deviceId,
        'DEVICE-TOKEN': _deviceToken,
      };
    }
  }
  // ✅ TAMBAH DI ApiService - METHOD UNTUK DOWNLOAD GAMBAR
Future<Uint8List?> downloadProfileImage(String filename) async {
  try {
    final headers = await getProtectedHeaders();
    
    print('📥 Downloading profile image: $filename');
    
    final response = await http.post(
      Uri.parse('$baseUrl/users/downloadImage'),
      headers: headers,
      body: 'filename=$filename',
    );

    if (response.statusCode == 200) {
      print('✅ Image downloaded successfully: ${response.bodyBytes.length} bytes');
      return response.bodyBytes;
    } else {
      print('❌ Failed to download image: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('❌ Error downloading image: $e');
    return null;
  }
}

// ✅ HEADERS KHUSUS UNTUK UPLOAD BUKTI TABUNGAN DENGAN USER_KEY
Future<Map<String, String>> _getBuktiTabunganHeaders() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userKey = prefs.getString('token'); // ✅ user_key dari login
    final sessionCookie = prefs.getString('ci_session');
    
    if (userKey == null || userKey.isEmpty) {
      throw Exception('User key tidak ditemukan');
    }
    
    // ✅ HEADERS DENGAN USER_KEY SEBAGAI x-api-key
    final headers = <String, String>{
      'DEVICE-ID': _deviceId,
      'x-api-key': userKey, // ✅ PAKAI USER_KEY DARI LOGIN
    };
    
    // ✅ TAMBAHKAN COOKIE SESSION JIKA ADA
    if (sessionCookie != null && sessionCookie.isNotEmpty) {
      headers['Cookie'] = 'ci_session=$sessionCookie';
      print('✅ Cookie session ditambahkan untuk bukti tabungan');
    } else {
      print('⚠️ Cookie session tidak ditemukan untuk bukti tabungan!');
    }
    
    return headers;
  } catch (e) {
    print('❌ Error getting bukti tabungan headers: $e');
    // Fallback ke protected headers
    return await getProtectedHeaders();
  }
}

  // ✅ METHOD UNTUK PILIH GAMBAR DARI GALLERY
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        print('📁 Image selected: ${image.path}');
        
        File file = File(image.path);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('📁 File size: $fileSize bytes');
          
          if (fileSize > 0) {
            return image.path;
          } else {
            print('❌ File kosong');
            return null;
          }
        } else {
          print('❌ File tidak ditemukan');
          return null;
        }
      } else {
        print('❌ User cancel pemilihan gambar');
        return null;
      }
    } catch (e) {
      print('❌ Error pick image: $e');
      return null;
    }
  }

  // ✅ METHOD UNTUK AMBIL FOTO DARI KAMERA
  Future<String?> takePhotoFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (photo != null) {
        print('📸 Photo taken: ${photo.path}');
        
        File file = File(photo.path);
        if (await file.exists()) {
          return photo.path;
        } else {
          print('❌ File tidak ditemukan');
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error take photo: $e');
      return null;
    }
  }

  // ✅ METHOD UNTUK MENDAPATKAN PATH FILE DUMMY (test.jpg)
  Future<String?> getDummyFilePath() async {
    try {
      // Coba beberapa lokasi yang mungkin untuk test.jpg
      final possiblePaths = [
        'test.jpg',
        './test.jpg',
        '../test.jpg',
        'assets/test.jpg',
        'images/test.jpg',
      ];

      for (var path in possiblePaths) {
        final file = File(path);
        if (await file.exists()) {
          print('✅ Dummy file found: $path');
          return path;
        }
      }

      print('❌ Dummy file (test.jpg) tidak ditemukan di project');
      return null;
    } catch (e) {
      print('❌ Error getting dummy file: $e');
      return null;
    }
  }

// ✅ METHOD UNTUK UPLOAD BUKTI FOTO KE API setBuktiPhoto DENGAN USER_KEY
Future<Map<String, dynamic>> setBuktiPhoto({
  required String filePath,
}) async {
  try {
    print('🚀 UPLOAD BUKTI PHOTO START (setBuktiPhoto API)');
    print('📁 File path: $filePath');

    // ✅ VALIDASI FILE
    final file = File(filePath);
    if (!await file.exists()) {
      return {
        'success': false,
        'message': 'File tidak ditemukan: $filePath'
      };
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      return {
        'success': false,
        'message': 'File kosong (0 bytes)'
      };
    }

    print('✅ File valid, size: $fileSize bytes');

    // ✅ DAPATKAN USER_KEY DARI SHAREDPREFERENCES
    final prefs = await SharedPreferences.getInstance();
    final userKey = prefs.getString('token'); // ✅ user_key biasanya disimpan sebagai 'token'
    final sessionCookie = prefs.getString('ci_session');

    if (userKey == null || userKey.isEmpty) {
      return {
        'success': false,
        'message': 'User tidak terautentikasi. Silakan login kembali.',
        'token_expired': true
      };
    }

    print('✅ User key found: ${userKey.substring(0, 10)}...');

    // ✅ HEADERS DENGAN USER_KEY SEBAGAI x-api-key
    final headers = {
      'DEVICE-ID': '12341231313131',
      'x-api-key': userKey, // ✅ PAKAI USER_KEY DARI LOGIN
    };

    // ✅ TAMBAHKAN COOKIE SESSION JIKA ADA
    if (sessionCookie != null && sessionCookie.isNotEmpty) {
      headers['Cookie'] = 'ci_session=$sessionCookie';
      print('✅ Cookie session ditambahkan: ${sessionCookie.substring(0, 20)}...');
    } else {
      print('⚠️ Cookie session tidak ditemukan!');
    }

    print('📤 Headers: ${headers.keys}');

    // ✅ BUAT MULTIPART REQUEST
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('http://demo.bsdeveloper.id/api/users/setBuktiPhoto')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN FILE DENGAN FIELD NAME "foto_bukti"
    try {
      request.files.add(await http.MultipartFile.fromPath(
        'foto_bukti',
        filePath,
        filename: 'bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ File berhasil ditambahkan dengan field: foto_bukti');
    } catch (e) {
      print('❌ Gagal menambahkan file: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke: http://demo.bsdeveloper.id/api/users/setBuktiPhoto');
    final response = await request.send().timeout(const Duration(seconds: 60));
    
    // ✅ BACA RESPONSE
    final responseBody = await response.stream.bytesToString();
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        print('✅ UPLOAD BUKTI PHOTO SUCCESS');
        return {
          'success': true,
          'message': data['message'] ?? 'Bukti photo berhasil diupload',
          'data': data
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        
        // ✅ CEK JIKA ADA ISSUE DENGAN AUTHENTIKASI
        if (data['message']?.toString().toLowerCase().contains('session') == true ||
            data['message']?.toString().toLowerCase().contains('login') == true ||
            data['message']?.toString().toLowerCase().contains('auth') == true ||
            data['message']?.toString().toLowerCase().contains('token') == true) {
          return {
            'success': false,
            'message': 'Sesi telah berakhir. Silakan login kembali.',
            'token_expired': true
          };
        }
        
        return {
          'success': false,
          'message': data['message'] ?? 'Upload bukti photo gagal',
          'data': data
        };
      }
    } else if (response.statusCode == 401) {
      print('❌ Unauthorized - kemungkinan token expired');
      return {
        'success': false,
        'message': 'Sesi telah berakhir. Silakan login kembali.',
        'token_expired': true
      };
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Upload gagal: ${response.statusCode} - $responseBody'
      };
    }
  } catch (e) {
    print('❌ UPLOAD BUKTI PHOTO ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

// ✅ METHOD UNTUK UPLOAD BUKTI TABUNGAN SESUAI CURL COMMAND
Future<Map<String, dynamic>> uploadBuktiTabungan({
  required String filePath,
}) async {
  try {
    print('🚀 UPLOAD BUKTI TABUNGAN START');
    print('📁 File path: $filePath');

    // ✅ VALIDASI FILE
    final file = File(filePath);
    if (!await file.exists()) {
      return {
        'success': false,
        'message': 'File tidak ditemukan: $filePath'
      };
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      return {
        'success': false,
        'message': 'File kosong (0 bytes)'
      };
    }

    print('✅ File valid, size: $fileSize bytes');

    // ✅ GET HEADERS SESUAI CURL COMMAND
    final headers = await _getBuktiTabunganHeaders();
    print('📤 Headers: ${headers.keys}');

    // ✅ BUAT MULTIPART REQUEST
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/users/setBuktiPhoto')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN FILE DENGAN FIELD NAME "foto_bukti"
    try {
      request.files.add(await http.MultipartFile.fromPath(
        'foto_bukti', // ✅ SESUAI CURL: --form 'foto_bukti=@"test.jpg"'
        filePath,
        filename: 'bukti_tabungan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ File berhasil ditambahkan dengan field: foto_bukti');
    } catch (e) {
      print('❌ Gagal menambahkan file: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke: $baseUrl/users/setBuktiPhoto');
    final response = await request.send().timeout(const Duration(seconds: 60));
    
    // ✅ BACA RESPONSE
    final responseBody = await response.stream.bytesToString();
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        print('✅ UPLOAD BUKTI TABUNGAN SUCCESS');
        return {
          'success': true,
          'message': data['message'] ?? 'Bukti tabungan berhasil diupload',
          'data': data
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Upload bukti tabungan gagal',
          'data': data
        };
      }
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Upload gagal: ${response.statusCode} - $responseBody'
      };
    }
  } catch (e) {
    print('❌ UPLOAD BUKTI TABUNGAN ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

  // ✅ CREATE DUMMY FILE JIKA TIDAK ADA
  Future<String?> createDummyFile() async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/test.jpg');
      
      // Buat file dummy dengan konten kosong
      await file.writeAsBytes(List.generate(100, (index) => 0));
      
      if (await file.exists()) {
        print('✅ Dummy file created: ${file.path}');
        return file.path;
      }
      
      return null;
    } catch (e) {
      print('❌ Error creating dummy file: $e');
      return null;
    }
  }

  // ✅ GET TEMPORARY DIRECTORY
  Future<Directory> getTemporaryDirectory() async {
    final directory = await getTemporaryDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  // ✅ TAMBAHKAN METHOD INI DI ApiService (api_service.dart)
Future<Map<String, dynamic>> uploadThreeRealOneDummy({
  required String fotoKtpPath,    // ASLI
  required String fotoKkPath,     // ASLI  
  required String fotoDiriPath,   // ASLI
  required String dummyFilePath,  // DUMMY (file ke-4)
}) async {
  try {
    print('🚀 UPLOAD 3 ASLI + 1 DUMMY START');
    print('📁 Real files:');
    print('   - KTP: $fotoKtpPath');
    print('   - KK: $fotoKkPath'); 
    print('   - Foto Diri: $fotoDiriPath');
    print('📁 Dummy file: $dummyFilePath');

    // ✅ DAPATKAN USER DATA
    final currentUser = await getCurrentUserForUpload();
    if (currentUser == null) {
      return {'success': false, 'message': 'User tidak ditemukan. Silakan login ulang.'};
    }

    final userId = currentUser['user_id']?.toString();
    final userKey = currentUser['user_key']?.toString();

    if (userId == null || userId.isEmpty || userKey == null || userKey.isEmpty) {
      return {'success': false, 'message': 'Data user tidak lengkap. user_id: $userId, user_key: $userKey'};
    }

    print('✅ User data valid - user_id: $userId');

    // ✅ VALIDASI SEMUA FILE
    final filesToValidate = {
      'KTP': fotoKtpPath,
      'KK': fotoKkPath,
      'Foto Diri': fotoDiriPath,
      'Dummy': dummyFilePath,
    };

    for (var entry in filesToValidate.entries) {
      final file = File(entry.value);
      if (!await file.exists()) {
        return {'success': false, 'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'};
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return {'success': false, 'message': 'File ${entry.key} kosong (0 bytes)'};
      }

      print('✅ File ${entry.key}: $fileSize bytes');
    }

    // ✅ GET HEADERS
    final headers = await getMultipartHeaders();
    print('📤 Headers: ${headers.keys}');

    // ✅ BUAT REQUEST
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/users/setPhoto')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN 4 FILE DENGAN FIELD NAME YANG BENAR
    try {
      // ✅ FILE 1: KTP (ASLI)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_ktp',
        fotoKtpPath,
        filename: 'ktp_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added KTP file');

      // ✅ FILE 2: KK (ASLI)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_kk',
        fotoKkPath,
        filename: 'kk_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added KK file');

      // ✅ FILE 3: FOTO DIRI (ASLI)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri',
        fotoDiriPath,
        filename: 'diri_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added Foto Diri file');

      // ✅ FILE 4: DUMMY BUKTI
      request.files.add(await http.MultipartFile.fromPath(
        'foto_bukti',
        dummyFilePath,
        filename: 'dummy_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added Dummy file');

    } catch (e) {
      print('❌ Error adding files: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    // ✅ TAMBAHKAN FORM FIELDS
    request.fields['type'] = 'complete_upload';
    request.fields['user_id'] = userId;
    request.fields['user_key'] = userKey;
    request.fields['upload_type'] = 'dokumen_lengkap';

    print('📤 Request fields: ${request.fields}');
    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke server...');
    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString();
    
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        print('🎉 UPLOAD 3 ASLI + 1 DUMMY SUKSES!');
        return {
          'success': true,
          'message': data['message'] ?? 'Semua dokumen berhasil diupload',
          'data': data
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Upload dokumen gagal',
          'data': data
        };
      }
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Server error ${response.statusCode}: $responseBody'
      };
    }
    
  } catch (e) {
    print('❌ UPLOAD 3+1 ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

  // ========== METHOD BARU UNTUK UPLOAD YANG BENAR ==========

  // ✅ UPLOAD DOKUMEN: 3 FILE ASLI + 1 DUMMY
  Future<Map<String, dynamic>> uploadDokumenLengkap({
    required String fotoKtpPath,    // ASLI
    required String fotoKkPath,     // ASLI  
    required String fotoDiriPath,   // ASLI
    required String dummyFilePath,  // DUMMY untuk bukti
  }) async {
    try {
      print('🚀 UPLOAD DOKUMEN: 3 ASLI + 1 DUMMY');
      print('📁 KTP: $fotoKtpPath');
      print('📁 KK: $fotoKkPath');
      print('📁 Foto Diri: $fotoDiriPath');
      print('📁 Dummy Bukti: $dummyFilePath');

      // Validasi semua file
      final filesToValidate = {
        'foto_ktp': fotoKtpPath,
        'foto_kk': fotoKkPath,
        'foto_diri': fotoDiriPath,
        'foto_bukti': dummyFilePath,
      };

      for (var entry in filesToValidate.entries) {
        final file = File(entry.value);
        if (!await file.exists()) {
          return {
            'success': false,
            'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'
          };
        }
      }

      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'User tidak ditemukan'};
      }

      final headers = await getMultipartHeaders();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/users/setPhoto'));
      request.headers.addAll(headers);

      // Tambahkan 4 file
      request.files.add(await http.MultipartFile.fromPath('foto_ktp', fotoKtpPath));
      request.files.add(await http.MultipartFile.fromPath('foto_kk', fotoKkPath));
      request.files.add(await http.MultipartFile.fromPath('foto_diri', fotoDiriPath));
      request.files.add(await http.MultipartFile.fromPath('foto_bukti', dummyFilePath));

      // Tambahkan form fields
      request.fields['type'] = 'foto_ktp';
      request.fields['user_id'] = currentUser['user_id']?.toString() ?? '';
      request.fields['user_key'] = currentUser['user_key']?.toString() ?? '';

      final response = await request.send().timeout(Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return {
          'success': data['status'] == true,
          'message': data['message'] ?? 'Upload dokumen berhasil',
          'data': data
        };
      } else {
        return {'success': false, 'message': 'Upload gagal: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  // ✅ TAMBAHKAN METHOD INI KE ApiService
Future<Map<String, dynamic>> uploadBuktiTabunganWithDummy({
  required String transaksiId,
  required String jenisTransaksi,
  required String buktiTransferPath,
  required String dummyFilePath,
}) async {
  try {
    print('🚀 UPLOAD BUKTI TABUNGAN WITH DUMMY START');
    print('📁 Transaksi ID: $transaksiId');
    print('📁 Jenis Transaksi: $jenisTransaksi');
    print('📁 Bukti Transfer Path: $buktiTransferPath');
    print('📁 Dummy File Path: $dummyFilePath');

    // ✅ VALIDASI FILE EXIST
    final buktiFile = File(buktiTransferPath);
    final dummyFile = File(dummyFilePath);
    
    if (!await buktiFile.exists()) {
      throw Exception('File bukti transfer tidak ditemukan');
    }
    
    if (!await dummyFile.exists()) {
      throw Exception('File dummy tidak ditemukan');
    }

    // ✅ GET HEADERS
    final headers = await getMultipartHeaders();
    
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/transaction/uploadBukti')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN 4 FILE - 1 ASLI + 3 DUMMY
    try {
      // ✅ FILE 1: bukti_transfer (FILE ASLI)
      request.files.add(await http.MultipartFile.fromPath(
        'bukti_transfer',
        buktiTransferPath,
        filename: 'bukti_${jenisTransaksi}_main_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added bukti_transfer (ASLI)');

      // ✅ FILE 2: foto_ktp (COPY DARI BUKTI TRANSFER)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_ktp',
        buktiTransferPath,
        filename: 'bukti_${jenisTransaksi}_ktp_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added foto_ktp (COPY)');

      // ✅ FILE 3: foto_kk (COPY DARI BUKTI TRANSFER)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_kk',
        buktiTransferPath,
        filename: 'bukti_${jenisTransaksi}_kk_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added foto_kk (COPY)');

      // ✅ FILE 4: foto_diri (COPY DARI BUKTI TRANSFER)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri',
        buktiTransferPath,
        filename: 'bukti_${jenisTransaksi}_diri_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added foto_diri (COPY)');

    } catch (e) {
      print('❌ Gagal menambahkan file: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    // ✅ TAMBAHKAN FORM FIELDS
    request.fields['transaksi_id'] = transaksiId;
    request.fields['jenis_transaksi'] = jenisTransaksi;
    request.fields['upload_type'] = 'with_dummy';
    
    // ✅ TAMBAHKAN USER DATA
    final currentUser = await getCurrentUser();
    if (currentUser != null && currentUser['user_id'] != null) {
      request.fields['user_id'] = currentUser['user_id'].toString();
    }

    print('📤 Request fields: ${request.fields}');
    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke server...');
    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString();
    
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        print('✅ UPLOAD BUKTI TABUNGAN WITH DUMMY SUCCESS');
        return {
          'success': true,
          'message': data['message'] ?? 'Bukti tabungan berhasil diupload',
          'data': data,
          'file_path': buktiTransferPath
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        
        // ✅ CEK TOKEN EXPIRED
        if (data['message']?.toString().toLowerCase().contains('token') == true ||
            data['message']?.toString().toLowerCase().contains('session') == true ||
            data['message']?.toString().toLowerCase().contains('login') == true) {
          return {
            'success': false,
            'message': data['message'] ?? 'Upload bukti tabungan gagal',
            'token_expired': true
          };
        }
        
        return {
          'success': false,
          'message': data['message'] ?? 'Upload bukti tabungan gagal'
        };
      }
    } else if (response.statusCode == 401) {
      print('❌ Token expired: 401 Unauthorized');
      await _clearToken();
      return {
        'success': false,
        'message': 'Sesi telah berakhir, silakan login kembali',
        'token_expired': true
      };
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Upload gagal: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ UPLOAD BUKTI TABUNGAN WITH DUMMY ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

// ✅ UPLOAD BUKTI TABUNGAN: 4 FILE SAMA DARI BUKTI TRANSFER
Future<Map<String, dynamic>> uploadBuktiTabunganFourFiles({
  required String transaksiId,
  required String jenisTransaksi,
  required String buktiTransferPath,
}) async {
  try {
    print('🚀 UPLOAD BUKTI TABUNGAN START (4 FILE SAMA)');
    print('📁 Transaksi ID: $transaksiId');
    print('📁 Jenis Transaksi: $jenisTransaksi');
    print('📁 Bukti Transfer: $buktiTransferPath');

    // ✅ VALIDASI FILE BUKTI TRANSFER
    final fileBukti = File(buktiTransferPath);
    if (!await fileBukti.exists()) {
      return {'success': false, 'message': 'File bukti transfer tidak ditemukan'};
    }

    final fileSize = await fileBukti.length();
    if (fileSize == 0) {
      return {'success': false, 'message': 'File bukti transfer kosong'};
    }

    print('✅ File bukti valid, size: $fileSize bytes');

    // ✅ GET HEADERS
    final headers = await getMultipartHeaders();
    
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/transaction/uploadBukti')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN 4 FILE SAMA DENGAN FIELD NAME YANG BERBEDA
    try {
      // ✅ FILE 1: bukti_transfer (FIELD UTAMA)
      request.files.add(await http.MultipartFile.fromPath(
        'bukti_transfer',
        buktiTransferPath,
        filename: 'bukti_${jenisTransaksi}_main_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // ✅ FILE 2: foto_ktp (COPY DARI BUKTI TRANSFER)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_ktp',
        buktiTransferPath,
        filename: 'bukti_${jenisTransaksi}_ktp_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // ✅ FILE 3: foto_kk (COPY DARI BUKTI TRANSFER)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_kk',
        buktiTransferPath,
        filename: 'bukti_${jenisTransaksi}_kk_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // ✅ FILE 4: foto_diri (COPY DARI BUKTI TRANSFER)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri',
        buktiTransferPath,
        filename: 'bukti_${jenisTransaksi}_diri_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      print('✅ 4 file berhasil ditambahkan (sama-sama dari bukti transfer)');
    } catch (e) {
      print('❌ Gagal menambahkan file: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    // ✅ TAMBAHKAN FORM FIELDS
    request.fields['transaksi_id'] = transaksiId;
    request.fields['jenis_transaksi'] = jenisTransaksi;
    
    // ✅ TAMBAHKAN USER DATA
    final currentUser = await getCurrentUser();
    if (currentUser != null && currentUser['user_id'] != null) {
      request.fields['user_id'] = currentUser['user_id'].toString();
    }

    print('📤 Request fields: ${request.fields}');
    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke server...');
    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString();
    
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        print('✅ UPLOAD BUKTI TABUNGAN SUCCESS (4 FILE SAMA)');
        return {
          'success': true,
          'message': data['message'] ?? 'Bukti tabungan berhasil diupload',
          'data': data
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Upload bukti tabungan gagal'
        };
      }
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Upload gagal: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ UPLOAD BUKTI TABUNGAN ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

  // ========== METHOD UNTUK TEMPORARY STORAGE SERVICE ==========

  // ✅ METHOD UTAMA: UPLOAD 4 DOKUMEN LENGKAP SEKALIGUS
Future<Map<String, dynamic>> uploadFourDocumentsComplete({
  required String fotoKtpPath,
  required String fotoKkPath,
  required String fotoDiriPath,
  required String fotoBuktiPath,
}) async {
  try {
    print('🚀 UPLOAD 4 DOKUMEN LENGKAP START');
    print('📁 Files to upload:');
    print('   - KTP: $fotoKtpPath');
    print('   - KK: $fotoKkPath');
    print('   - Foto Diri: $fotoDiriPath');
    print('   - Bukti Pembayaran: $fotoBuktiPath');

    // ✅ DAPATKAN USER DATA
    final currentUser = await getCurrentUserForUpload();
    if (currentUser == null) {
      return {'success': false, 'message': 'User tidak ditemukan. Silakan login ulang.'};
    }

    final userId = currentUser['user_id']?.toString();
    final userKey = currentUser['user_key']?.toString();

    if (userId == null || userId.isEmpty || userKey == null || userKey.isEmpty) {
      return {'success': false, 'message': 'Data user tidak lengkap. user_id: $userId, user_key: $userKey'};
    }

    print('✅ User data valid - user_id: $userId');

    // ✅ VALIDASI SEMUA FILE
    final filesToValidate = {
      'KTP': fotoKtpPath,
      'KK': fotoKkPath,
      'Foto Diri': fotoDiriPath,
      'Bukti Pembayaran': fotoBuktiPath,
    };

    for (var entry in filesToValidate.entries) {
      final file = File(entry.value);
      if (!await file.exists()) {
        return {'success': false, 'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'};
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return {'success': false, 'message': 'File ${entry.key} kosong (0 bytes)'};
      }

      print('✅ File ${entry.key}: $fileSize bytes');
    }

    // ✅ GET HEADERS
    final headers = await getMultipartHeaders();
    print('📤 Headers: ${headers.keys}');

    // ✅ BUAT REQUEST
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/users/setPhoto')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN 4 FILE DENGAN FIELD NAME YANG BENAR
    try {
      // ✅ FILE 1: KTP
      request.files.add(await http.MultipartFile.fromPath(
        'foto_ktp',
        fotoKtpPath,
        filename: 'ktp_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added KTP file');

      // ✅ FILE 2: KK
      request.files.add(await http.MultipartFile.fromPath(
        'foto_kk',
        fotoKkPath,
        filename: 'kk_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added KK file');

      // ✅ FILE 3: FOTO DIRI
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri',
        fotoDiriPath,
        filename: 'diri_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added Foto Diri file');

      // ✅ FILE 4: BUKTI PEMBAYARAN
      request.files.add(await http.MultipartFile.fromPath(
        'foto_bukti',
        fotoBuktiPath,
        filename: 'bukti_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added Bukti Pembayaran file');

    } catch (e) {
      print('❌ Error adding files: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    // ✅ TAMBAHKAN FORM FIELDS
    request.fields['type'] = 'complete_upload';
    request.fields['user_id'] = userId;
    request.fields['user_key'] = userKey;
    request.fields['upload_type'] = 'dokumen_lengkap';

    print('📤 Request fields: ${request.fields}');
    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke server...');
    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString();
    
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        print('🎉 UPLOAD 4 DOKUMEN SUKSES!');
        return {
          'success': true,
          'message': data['message'] ?? 'Semua dokumen berhasil diupload',
          'data': data
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        
        // ✅ CEK JIKA ADA ISSUE DENGAN AUTHENTIKASI
        if (data['message']?.toString().toLowerCase().contains('session') == true ||
            data['message']?.toString().toLowerCase().contains('login') == true ||
            data['message']?.toString().toLowerCase().contains('auth') == true ||
            data['message']?.toString().toLowerCase().contains('token') == true) {
          return {
            'success': false,
            'message': 'Sesi telah berakhir. Silakan login kembali.',
            'token_expired': true
          };
        }
        
        return {
          'success': false,
          'message': data['message'] ?? 'Upload dokumen gagal',
          'data': data
        };
      }
    } else if (response.statusCode == 401) {
      print('❌ Unauthorized - kemungkinan token expired');
      return {
        'success': false,
        'message': 'Sesi telah berakhir. Silakan login kembali.',
        'token_expired': true
      };
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Upload gagal: ${response.statusCode} - $responseBody'
      };
    }
  } catch (e) {
    print('❌ UPLOAD 4 DOKUMEN ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

// ✅ METHOD ALTERNATIF: UPLOAD 4 FILE DENGAN FIELD NAME BERBEDA
Future<Map<String, dynamic>> uploadFourDocumentsWithDifferentFields({
  required String fotoKtpPath,
  required String fotoKkPath,
  required String fotoDiriPath,
  required String fotoBuktiPath,
}) async {
  try {
    print('🚀 UPLOAD 4 DOKUMEN WITH DIFFERENT FIELDS START');

    // ✅ DAPATKAN USER DATA
    final currentUser = await getCurrentUserForUpload();
    if (currentUser == null) {
      return {'success': false, 'message': 'User tidak ditemukan. Silakan login ulang.'};
    }

    final userId = currentUser['user_id']?.toString();
    final userKey = currentUser['user_key']?.toString();

    if (userId == null || userId.isEmpty || userKey == null || userKey.isEmpty) {
      return {'success': false, 'message': 'Data user tidak lengkap'};
    }

    // ✅ VALIDASI FILE
    final filesToValidate = {
      'KTP': fotoKtpPath,
      'KK': fotoKkPath,
      'Foto Diri': fotoDiriPath,
      'Bukti Pembayaran': fotoBuktiPath,
    };

    for (var entry in filesToValidate.entries) {
      final file = File(entry.value);
      if (!await file.exists()) {
        return {'success': false, 'message': 'File ${entry.key} tidak ditemukan'};
      }
    }

    // ✅ GET HEADERS
    final headers = await getMultipartHeaders();
    
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/users/setPhoto')
    );
    request.headers.addAll(headers);

    // ✅ COBA BERBAGAI KOMBINASI FIELD NAME
    final fieldCombinations = [
      {'ktp': 'foto_ktp', 'kk': 'foto_kk', 'diri': 'foto_diri', 'bukti': 'foto_bukti'},
      {'ktp': 'ktp', 'kk': 'kk', 'diri': 'diri', 'bukti': 'bukti'},
      {'ktp': 'photo_ktp', 'kk': 'photo_kk', 'diri': 'photo_diri', 'bukti': 'photo_bukti'},
    ];

    for (var fields in fieldCombinations) {
      try {
        print('🔄 Trying field combination: $fields');
        
        request.files.clear();
        
        // ✅ TAMBAHKAN 4 FILE DENGAN FIELD NAME YANG BERBEDA
        request.files.add(await http.MultipartFile.fromPath(
          fields['ktp']!,
          fotoKtpPath,
          filename: 'ktp_$userId.jpg',
        ));

        request.files.add(await http.MultipartFile.fromPath(
          fields['kk']!,
          fotoKkPath,
          filename: 'kk_$userId.jpg',
        ));

        request.files.add(await http.MultipartFile.fromPath(
          fields['diri']!,
          fotoDiriPath,
          filename: 'diri_$userId.jpg',
        ));

        request.files.add(await http.MultipartFile.fromPath(
          fields['bukti']!,
          fotoBuktiPath,
          filename: 'bukti_$userId.jpg',
        ));

        // ✅ TAMBAHKAN FORM FIELDS
        request.fields['type'] = 'complete_upload';
        request.fields['user_id'] = userId;
        request.fields['user_key'] = userKey;

        print('📤 Request with fields: ${fields}');
        
        // ✅ KIRIM REQUEST
        final response = await request.send().timeout(const Duration(seconds: 60));
        final responseBody = await response.stream.bytesToString();
        
        print('📡 Response Status: ${response.statusCode}');
        print('📡 Response Body: $responseBody');

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          
          if (data['status'] == true) {
            print('🎉 UPLOAD 4 DOKUMEN SUKSES dengan fields: $fields');
            return {
              'success': true,
              'message': data['message'] ?? 'Semua dokumen berhasil diupload',
              'data': data,
              'fields_used': fields
            };
          }
        }
      } catch (e) {
        print('❌ Field combination $fields failed: $e');
        continue;
      }
    }

    return {
      'success': false,
      'message': 'Semua kombinasi field name gagal'
    };
    
  } catch (e) {
    print('❌ UPLOAD 4 DOKUMEN WITH DIFFERENT FIELDS ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

// ✅ METHOD BACKWARD COMPATIBILITY (untuk screen yang lama)
Future<Map<String, dynamic>> uploadFourDocuments({
  required String fotoKtpPath,
  required String fotoKkPath,
  required String fotoDiriPath,
  required String fotoBuktiPath,
}) async {
  // Panggil method utama
  return await uploadFourDocumentsComplete(
    fotoKtpPath: fotoKtpPath,
    fotoKkPath: fotoKkPath,
    fotoDiriPath: fotoDiriPath,
    fotoBuktiPath: fotoBuktiPath,
  );
}

// ✅ TAMBAHKAN METHOD INI DI ApiService
Future<Map<String, dynamic>> uploadFourPhotos({
  required String userId,
  required String userKey,
  required String fotoKtpPath,
  required String fotoKkPath,
  required String fotoDiriPath,
  required String fotoBuktiPath,
}) async {
  try {
    print('🚀 UPLOAD 4 FOTO START');
    print('👤 User ID: $userId');
    print('🔑 User Key: ${userKey.substring(0, 10)}...');
    print('📁 Files to upload:');
    print('   - foto_ktp: $fotoKtpPath');
    print('   - foto_kk: $fotoKkPath');
    print('   - foto_diri: $fotoDiriPath');
    print('   - foto_bukti: $fotoBuktiPath');

    // ✅ VALIDASI SEMUA FILE SEBELUM UPLOAD
    final filesToValidate = {
      'foto_ktp': fotoKtpPath,
      'foto_kk': fotoKkPath,
      'foto_diri': fotoDiriPath,
      'foto_bukti': fotoBuktiPath,
    };

    for (var entry in filesToValidate.entries) {
      final file = File(entry.value);
      if (!await file.exists()) {
        return {
          'success': false,
          'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'
        };
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return {
          'success': false,
          'message': 'File ${entry.key} kosong'
        };
      }
    }

    // ✅ GET HEADERS
    final headers = await getMultipartHeaders();
    
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/users/setPhoto')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN SEMUA FILE KE REQUEST
    try {
      // ✅ foto_ktp
      request.files.add(await http.MultipartFile.fromPath(
        'foto_ktp',
        fotoKtpPath,
        filename: 'foto_ktp_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // ✅ foto_kk
      request.files.add(await http.MultipartFile.fromPath(
        'foto_kk',
        fotoKkPath,
        filename: 'foto_kk_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // ✅ foto_diri
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri',
        fotoDiriPath,
        filename: 'foto_diri_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      // ✅ foto_bukti
      request.files.add(await http.MultipartFile.fromPath(
        'foto_bukti',
        fotoBuktiPath,
        filename: 'foto_bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      print('✅ Semua file berhasil ditambahkan');
    } catch (e) {
      print('❌ Gagal menambahkan file: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    // ✅ TAMBAHKAN FORM FIELDS
    request.fields['type'] = 'foto_ktp';
    request.fields['user_id'] = userId;
    request.fields['user_key'] = userKey;

    print('📤 Request fields: ${request.fields}');
    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString();
    
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Semua foto berhasil diupload',
          'data': data
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Upload foto gagal'
        };
      }
    } else {
      return {
        'success': false,
        'message': 'Server error ${response.statusCode}: $responseBody'
      };
    }
  } catch (e) {
    print('❌ UPLOAD 4 FOTO ERROR: $e');
    return {
      'success': false,
      'message': 'Upload foto error: $e'
    };
  }
}

// ✅ FIX: UPLOAD 4 FOTO DENGAN VALIDASI LENGKAP
Future<Map<String, dynamic>> uploadFourPhotosWithValidation({
  required String fotoKtpPath,
  required String fotoKkPath,
  required String fotoDiriPath,
  required String fotoBuktiPath,
}) async {
  try {
    print('🚀 UPLOAD 4 FOTO DENGAN VALIDASI START');
    
    // ✅ DEBUG USER DATA DULU
    await debugUserData();
    
    // ✅ DAPATKAN USER DATA YANG BENAR
    final currentUser = await getCurrentUserForUpload();
    if (currentUser == null) {
      return {
        'success': false, 
        'message': '❌ User data tidak ditemukan. Silakan login ulang.'
      };
    }
    
    final userId = currentUser['user_id']?.toString();
    final userKey = currentUser['user_key']?.toString();
    
    if (userId == null || userId.isEmpty) {
      return {
        'success': false,
        'message': '❌ User ID tidak valid. user_id: $userId'
      };
    }
    
    if (userKey == null || userKey.isEmpty) {
      return {
        'success': false,
        'message': '❌ User Key tidak valid. user_key: $userKey'
      };
    }
    
    print('✅ User data valid:');
    print('   - user_id: $userId');
    print('   - user_key: ${userKey.substring(0, 10)}...');
    
    // ✅ VALIDASI FILE
    final filesToValidate = {
      'KTP': fotoKtpPath,
      'KK': fotoKkPath, 
      'Foto Diri': fotoDiriPath,
      'Bukti': fotoBuktiPath,
    };
    
    for (var entry in filesToValidate.entries) {
      final file = File(entry.value);
      if (!await file.exists()) {
        return {
          'success': false,
          'message': '❌ File ${entry.key} tidak ditemukan: ${entry.value}'
        };
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        return {
          'success': false,
          'message': '❌ File ${entry.key} kosong (0 bytes)'
        };
      }
      
      print('✅ File ${entry.key}: $fileSize bytes');
    }
    
    // ✅ GET HEADERS
    final headers = await getMultipartHeaders();
    print('📤 Headers: ${headers.keys}');
    
    // ✅ BUAT REQUEST
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/users/setPhoto')
    );
    request.headers.addAll(headers);
    
    // ✅ TAMBAHKAN FILE DENGAN FIELD NAME YANG BERBEDA-BEDA
    try {
      // Coba berbagai kombinasi field name
      final fieldNames = [
        'foto_ktp', 'ktp', 'photo_ktp',
        'foto_kk', 'kk', 'photo_kk', 
        'foto_diri', 'diri', 'photo_diri',
        'foto_bukti', 'bukti', 'photo_bukti'
      ];
      
      // File 1: KTP
      request.files.add(await http.MultipartFile.fromPath(
        'foto_ktp', // Field name utama
        fotoKtpPath,
        filename: 'ktp_$userId.jpg',
      ));
      
      // File 2: KK  
      request.files.add(await http.MultipartFile.fromPath(
        'foto_kk', // Field name utama
        fotoKkPath,
        filename: 'kk_$userId.jpg',
      ));
      
      // File 3: Foto Diri
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri', // Field name utama
        fotoDiriPath,
        filename: 'diri_$userId.jpg',
      ));
      
      // File 4: Bukti
      request.files.add(await http.MultipartFile.fromPath(
        'foto_bukti', // Field name utama
        fotoBuktiPath,
        filename: 'bukti_$userId.jpg',
      ));
      
      print('✅ Semua file berhasil ditambahkan');
    } catch (e) {
      print('❌ Error adding files: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }
    
    // ✅ TAMBAHKAN FORM FIELDS
    request.fields['type'] = 'complete_upload'; // Coba type yang berbeda
    request.fields['user_id'] = userId;
    request.fields['user_key'] = userKey;
    request.fields['upload_type'] = 'dokumen_lengkap'; // Field tambahan
    
    print('📤 Request fields: ${request.fields}');
    print('📤 Total files: ${request.files.length}');
    
    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke server...');
    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString();
    
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        print('🎉 UPLOAD 4 FOTO SUKSES!');
        return {
          'success': true,
          'message': data['message'] ?? 'Semua dokumen berhasil diupload',
          'data': data
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Upload dokumen gagal',
          'data': data
        };
      }
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Server error ${response.statusCode}: $responseBody'
      };
    }
    
  } catch (e) {
    print('❌ UPLOAD ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

// ✅ HELPER: GET JENIS TRANSAKSI DARI DATA API
String _getJenisTransaksiFromApi(String? transaksiApi, bool isSetoran) {
  if (transaksiApi == null || transaksiApi.isEmpty) {
    return isSetoran ? 'Setoran' : 'Penarikan';
  }
  
  switch (transaksiApi.toUpperCase()) {
    case 'POKOK':
      return 'Setoran Pokok';
    case 'WAJIB':
      return 'Setoran Wajib';
    case 'SITABUNG':
      return 'Setoran SiTabung';
    case 'PENARIKAN_SITABUNG':
      return 'Penarikan SiTabung';
    case 'SUKARELA':
      return 'Setoran Sukarela';
    case 'SIUMNA':
      return 'Setoran Siumna';
    case 'SIQUNA':
      return 'Setoran Siquna';
    default:
      return transaksiApi;
  }
}

// ✅ TEST UPLOAD SEDERHANA (1 FILE DULU)
Future<Map<String, dynamic>> testSingleUpload(String filePath, String type) async {
  try {
    print('🧪 TEST UPLOAD: $type');
    
    await debugUserData();
    
    final currentUser = await getCurrentUserForUpload();
    if (currentUser == null) {
      return {'success': false, 'message': 'User tidak ditemukan'};
    }
    
    final file = File(filePath);
    if (!await file.exists()) {
      return {'success': false, 'message': 'File tidak ditemukan'};
    }
    
    final headers = await getMultipartHeaders();
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/users/setPhoto')
    );
    request.headers.addAll(headers);
    
    // Coba field name yang berbeda
    final fieldName = type == 'ktp' ? 'foto_ktp' : 
                     type == 'kk' ? 'foto_kk' :
                     type == 'diri' ? 'foto_diri' : 'foto';
    
    request.files.add(await http.MultipartFile.fromPath(
      fieldName,
      filePath,
      filename: 'test_$type.jpg',
    ));
    
    request.fields['type'] = type;
    request.fields['user_id'] = currentUser['user_id']?.toString() ?? '';
    request.fields['user_key'] = currentUser['user_key']?.toString() ?? '';
    
    print('📤 Test upload - Field: $fieldName, Type: $type');
    
    final response = await request.send().timeout(const Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();
    
    print('📡 Test Response: ${response.statusCode}');
    print('📡 Test Body: $responseBody');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? 'Test upload completed',
        'data': data
      };
    } else {
      return {
        'success': false,
        'message': 'Test upload failed: ${response.statusCode}'
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Test upload error: $e'
    };
  }
}

// ✅ PASTIKAN FIELD NAME SESUAI DENGAN BACKEND
Future<Map<String, dynamic>> uploadFourPhotosWithUser({
  required String fotoKtpPath,
  required String fotoKkPath,
  required String fotoDiriPath,
  required String fotoBuktiPath,
}) async {
  try {
    final currentUser = await getCurrentUserForUpload();
    if (currentUser == null) {
      return {'success': false, 'message': 'User tidak ditemukan'};
    }

    final userId = currentUser['user_id']?.toString();
    final userKey = currentUser['user_key']?.toString();

    if (userId == null || userKey == null) {
      return {'success': false, 'message': 'Data user tidak lengkap'};
    }

    return await uploadFourPhotos(
      userId: userId,
      userKey: userKey,
      fotoKtpPath: fotoKtpPath,
      fotoKkPath: fotoKkPath,
      fotoDiriPath: fotoDiriPath,
      fotoBuktiPath: fotoBuktiPath, // ✅ INI AKAN JADI FILE KE-4
    );
  } catch (e) {
    return {'success': false, 'message': 'Upload error: $e'};
  }
}

  Future<Map<String, dynamic>> uploadSinglePhotoWithUser({
    required String type,
    required String filePath,
  }) async {
    return await uploadFoto(type: type, filePath: filePath);
  }

  // ========== SEMUA METHOD LAMA DARI CODE AWAL ==========

  // ✅ PERBAIKAN BESAR: Upload 4 Foto Sekaligus sesuai curl command
  Future<Map<String, dynamic>> uploadFourPhotosOriginal({
    required String userId,
    required String userKey,
    required String fotoKtpPath,
    required String fotoKkPath,
    required String fotoDiriPath,
    required String fotoBuktiPath,
  }) async {
    try {
      print('🚀 UPLOAD 4 FOTO START');
      print('👤 User ID: $userId');
      print('🔑 User Key: ${userKey.substring(0, 10)}...');
      print('📁 Files to upload:');
      print('   - foto_ktp: $fotoKtpPath');
      print('   - foto_kk: $fotoKkPath');
      print('   - foto_diri: $fotoDiriPath');
      print('   - foto_bukti: $fotoBuktiPath');

      // ✅ VALIDASI SEMUA FILE SEBELUM UPLOAD
      final filesToValidate = {
        'foto_ktp': fotoKtpPath,
        'foto_kk': fotoKkPath,
        'foto_diri': fotoDiriPath,
        'foto_bukti': fotoBuktiPath,
      };

      for (var entry in filesToValidate.entries) {
        final file = File(entry.value);
        if (!await file.exists()) {
          return {
            'success': false,
            'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'
          };
        }

        final fileSize = await file.length();
        if (fileSize == 0) {
          return {
            'success': false,
            'message': 'File ${entry.key} kosong'
          };
        }

        // Validasi format file
        final fileExtension = entry.value.toLowerCase().split('.').last;
        final allowedExtensions = ['jpg', 'jpeg', 'png'];
        if (!allowedExtensions.contains(fileExtension)) {
          return {
            'success': false,
            'message': 'Format file .$fileExtension tidak didukung untuk ${entry.key}. Gunakan JPG, JPEG, atau PNG.'
          };
        }
      }

      // ✅ GET HEADERS
      final headers = await getMultipartHeaders();
      print('📤 Headers: ${headers.keys}');
      print('📤 x-api-key: ${headers['x-api-key']?.substring(0, 10)}...');

      // ✅ BUAT MULTIPART REQUEST
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/users/setPhoto')
      );
      request.headers.addAll(headers);

      // ✅ TAMBAHKAN SEMUA FILE KE REQUEST DENGAN FIELD NAME YANG BENAR
      try {
        // ✅ foto_ktp
        var multipartFileKtp = await http.MultipartFile.fromPath(
          'foto_ktp',
          fotoKtpPath,
          filename: 'foto_ktp_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(multipartFileKtp);
        print('✅ Added foto_ktp: $fotoKtpPath');

        // ✅ foto_kk
        var multipartFileKk = await http.MultipartFile.fromPath(
          'foto_kk',
          fotoKkPath,
          filename: 'foto_kk_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(multipartFileKk);
        print('✅ Added foto_kk: $fotoKkPath');

        // ✅ foto_diri
        var multipartFileDiri = await http.MultipartFile.fromPath(
          'foto_diri',
          fotoDiriPath,
          filename: 'foto_diri_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(multipartFileDiri);
        print('✅ Added foto_diri: $fotoDiriPath');

        // ✅ foto_bukti
        var multipartFileBukti = await http.MultipartFile.fromPath(
          'foto_bukti',
          fotoBuktiPath,
          filename: 'foto_bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(multipartFileBukti);
        print('✅ Added foto_bukti: $fotoBuktiPath');

      } catch (e) {
        print('❌ Gagal menambahkan file ke request: $e');
        return {
          'success': false, 
          'message': 'Gagal menambahkan file ke request: $e'
        };
      }

      // ✅ TAMBAHKAN FORM FIELDS SESUAI CURL COMMAND
      request.fields['type'] = 'foto_ktp'; // Sesuai curl command
      request.fields['user_id'] = userId;
      request.fields['user_key'] = userKey;

      print('📤 Request fields: ${request.fields}');
      print('📤 Total files: ${request.files.length}');

      // ✅ KIRIM REQUEST
      print('🔄 Mengirim request ke: $baseUrl/users/setPhoto');
      final response = await request.send().timeout(const Duration(seconds: 60));
      
      // ✅ BACA RESPONSE
      final responseBody = await response.stream.bytesToString();
      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        if (data['status'] == true) {
          print('✅ UPLOAD 4 FOTO SUCCESS');
          
          return {
            'success': true,
            'message': data['message'] ?? 'Semua foto berhasil diupload',
            'data': data
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Upload foto gagal'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server error ${response.statusCode}: $responseBody'
        };
      }
    } catch (e) {
      print('❌ UPLOAD 4 FOTO ERROR: $e');
      return {
        'success': false,
        'message': 'Upload foto error: $e'
      };
    }
  }

  // ✅ UPLOAD DOKUMEN LENGKAP: 3 ASLI + 1 DUMMY (test.jpg)
  Future<Map<String, dynamic>> uploadDokumenLengkapOriginal({
    required String userId,
    required String userKey,
    required String fotoKtpPath,    // ASLI
    required String fotoKkPath,     // ASLI  
    required String fotoDiriPath,   // ASLI
    required String dummyFilePath,  // DUMMY (test.jpg dari project)
  }) async {
    try {
      print('🚀 UPLOAD DOKUMEN LENGKAP START (3 ASLI + 1 DUMMY)');
      print('👤 User ID: $userId');
      print('📁 Files to upload:');
      print('   - foto_ktp (ASLI): $fotoKtpPath');
      print('   - foto_kk (ASLI): $fotoKkPath');
      print('   - foto_diri (ASLI): $fotoDiriPath');
      print('   - foto_bukti (DUMMY): $dummyFilePath');

      // ✅ VALIDASI FILE ASLI
      final filesToValidate = {
        'foto_ktp': fotoKtpPath,
        'foto_kk': fotoKkPath,
        'foto_diri': fotoDiriPath,
        'foto_bukti': dummyFilePath,
      };

      for (var entry in filesToValidate.entries) {
        final file = File(entry.value);
        if (!await file.exists()) {
          return {
            'success': false,
            'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'
          };
        }

        final fileSize = await file.length();
        if (fileSize == 0) {
          return {
            'success': false,
            'message': 'File ${entry.key} kosong'
          };
        }
      }

      // ✅ GET HEADERS
      final headers = await getMultipartHeaders();
      
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/users/setPhoto')
      );
      request.headers.addAll(headers);

      // ✅ TAMBAHKAN SEMUA FILE
      try {
        // ✅ foto_ktp (ASLI)
        request.files.add(await http.MultipartFile.fromPath(
          'foto_ktp',
          fotoKtpPath,
          filename: 'foto_ktp_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        // ✅ foto_kk (ASLI)
        request.files.add(await http.MultipartFile.fromPath(
          'foto_kk',
          fotoKkPath,
          filename: 'foto_kk_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        // ✅ foto_diri (ASLI)
        request.files.add(await http.MultipartFile.fromPath(
          'foto_diri',
          fotoDiriPath,
          filename: 'foto_diri_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        // ✅ foto_bukti (DUMMY)
        request.files.add(await http.MultipartFile.fromPath(
          'foto_bukti',
          dummyFilePath,
          filename: 'foto_bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        print('✅ Semua file berhasil ditambahkan');
      } catch (e) {
        print('❌ Gagal menambahkan file: $e');
        return {
          'success': false,
          'message': 'Gagal menambahkan file: $e'
        };
      }

      // ✅ TAMBAHKAN FORM FIELDS
      request.fields['type'] = 'foto_ktp';
      request.fields['user_id'] = userId;
      request.fields['user_key'] = userKey;

      print('📤 Request fields: ${request.fields}');
      print('📤 Total files: ${request.files.length}');

      // ✅ KIRIM REQUEST
      final response = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();
      
      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        if (data['status'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Dokumen lengkap berhasil diupload',
            'data': data
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Upload dokumen gagal'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Upload dokumen gagal: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ UPLOAD DOKUMEN LENGKAP ERROR: $e');
      return {
        'success': false,
        'message': 'Upload dokumen error: $e'
      };
    }
  }

  // ✅ METHOD BARU: GET IMAGE VIA UserImage API
Future<Uint8List?> getUserImage(String filename) async {
  try {
    final headers = await getProtectedHeaders();
    
    print('📥 Getting user image via API: $filename');
    
    final response = await http.post(
      Uri.parse('$baseUrl/users/UserImage'),
      headers: {
        ...headers,
        'Content-Type': 'application/json', // ✅ SESUAI TEST CURL
      },
      body: jsonEncode({'filename': filename}),
    );

    print('📡 UserImage API Response Status: ${response.statusCode}');
    print('📡 UserImage API Content-Type: ${response.headers['content-type']}');
    print('📡 UserImage API Content-Length: ${response.headers['content-length']}');

    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'];
      
      // ✅ CEK APAKAH RESPONSE ADALAH GAMBAR
      if (contentType?.startsWith('image/') == true) {
        print('✅ Image received successfully: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        print('❌ Response is not an image: $contentType');
        return null;
      }
    } else {
      print('❌ UserImage API failed: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('❌ Error getting user image: $e');
    return null;
  }
}
  
  // ✅ METHOD GET USER INFO - SESUAI DENGAN CURL COMMAND
Future<Map<String, dynamic>> getUserInfo() async {
  try {
    // ✅ GET HEADERS DENGAN x-api-key DARI USER_KEY
    final headers = await getProtectedHeaders();
    
    print('🚀 Getting user info from server...');
    print('📤 Headers: ${headers.keys}');
    if (headers['x-api-key'] != null) {
      print('🔑 x-api-key: ${headers['x-api-key']!.substring(0, 10)}...');
    }
    if (headers['Cookie'] != null) {
      print('🍪 Cookie: ${headers['Cookie']!.substring(0, 20)}...');
    }

    // ✅ KIRIM REQUEST SESUAI CURL: --data ''
    final response = await http.post(
      Uri.parse('$baseUrl/users/userInfo'),
      headers: headers,
      body: '', // ✅ SESUAI CURL: --data ''
    ).timeout(const Duration(seconds: 30));

    print('📡 UserInfo Response Status: ${response.statusCode}');
    print('📡 UserInfo Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      
      // ✅ RESPONSE YANG DIHARAPKAN:
      // {
      //   "status": true,
      //   "username": "sonik",
      //   "nama": "Robilul Ilmi Sonic Rahmatul Huda",
      //   "email": "sonik@sonik.gmail.com",
      //   "telp": "",
      //   "alamat": "Dsn Manggisan, Ds Plosokandang, Kec Kedungwaru, Kab Tulungagung, RT 2, RW 3, 66221",
      //   "foto_kk": "90a1958e4ea2334994a57af125e61c32.jpg",
      //   "foto_ktp": "8af1ca6e08735b706ef9794482508c4c.jpg",
      //   "foto_bukti": "200911cfa2b2296edd1ebc112d1037af.jpg",
      //   "foto_diri": "0d1e20729270a97f4ebac246082d69b3.jpg",
      //   "message": "OK"
      // }
      
      if (result['status'] == true) {
        print('✅ UserInfo data loaded successfully');
        print('👤 Username: ${result['username']}');
        print('📧 Email: ${result['email']}');
        print('📍 Alamat: ${result['alamat']}');
        
        // ✅ SIMPAN DATA USER KE LOCAL STORAGE
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_info', jsonEncode(result));
        
        return {
          'success': true,
          'data': result,
          'message': result['message'] ?? 'Success get user info',
        };
      } else {
        print('❌ UserInfo API status false: ${result['message']}');
        return {
          'success': false,
          'message': result['message'] ?? 'Gagal mengambil data user',
        };
      }
    } else if (response.statusCode == 401) {
      print('❌ Unauthorized - Token mungkin expired');
      await _clearToken();
      return {
        'success': false,
        'message': 'Sesi telah berakhir. Silakan login kembali.',
        'token_expired': true
      };
    } else {
      print('❌ UserInfo HTTP error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'HTTP error: ${response.statusCode}',
      };
    }
  } catch (e) {
    print('❌ getUserInfo error: $e');
    return {
      'success': false,
      'message': 'Error: $e',
    };
  }
}



 // ✅ SUPER METHOD: GET USER INFO LENGKAP DARI SEMUA SUMBER
Future<Map<String, dynamic>> getCompleteUserInfo() async {
  try {
    print('🚀 SUPER GETUSERINFO - Loading complete user data from all sources...');
    
    final prefs = await SharedPreferences.getInstance();
    
    // ✅ 1. DAPATKAN DATA DARI GETUSERINFO API
    final userInfoResult = await getUserInfo();
    Map<String, dynamic> completeData = {};
    
    if (userInfoResult['success'] == true && userInfoResult['data'] != null) {
      completeData = Map<String, dynamic>.from(userInfoResult['data']);
      print('✅ getUserInfo API data loaded');
    }
    
    // ✅ 2. DAPATKAN DATA DARI LOGIN RESPONSE
    final loginDataString = prefs.getString('login_user');
    if (loginDataString != null) {
      final loginData = jsonDecode(loginDataString);
      if (loginData['user'] != null) {
        completeData.addAll(loginData['user']);
        print('✅ Login data merged');
      }
    }
    
    // ✅ 3. DAPATKAN DATA DARI USER SAVED
    final userString = prefs.getString('user');
    if (userString != null) {
      final userData = jsonDecode(userString);
      completeData.addAll(userData);
      print('✅ Saved user data merged');
    }
    
    // ✅ 4. DAPATKAN DATA DARI REGISTRASI BACKUP
    final regDataString = prefs.getString('registration_data');
    if (regDataString != null) {
      final regData = jsonDecode(regDataString);
      completeData.addAll(regData);
      print('✅ Registration data merged');
    }
    
    // ✅ 5. TAMBAHKAN SYSTEM INFO YANG PALING PENTING
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      completeData['user_key'] = token;
      completeData['token'] = token;
    }
    
    final userId = prefs.getString('user_id');
    if (userId != null && userId.isNotEmpty) {
      completeData['user_id'] = userId;
      completeData['id'] = userId;
    }
    
    // ✅ 6. SIMPAN DATA LENGKAP KE LOCAL STORAGE
    await prefs.setString('complete_user_data', jsonEncode(completeData));
    await prefs.setString('user', jsonEncode(completeData));
    
    print('🎉 SUPER GETUSERINFO COMPLETE!');
    print('📊 Total keys: ${completeData.keys.length}');
    print('🔑 User Key: ${completeData['user_key']?.toString().substring(0, 10)}...');
    print('👤 User ID: ${completeData['user_id']}');
    
    return {
      'success': true,
      'data': completeData,
      'message': 'Complete user data loaded successfully'
    };
    
  } catch (e) {
    print('❌ SUPER GETUSERINFO error: $e');
    return {
      'success': false,
      'message': 'Error loading complete user data: $e'
    };
  }
}

// ✅ METHOD ALTERNATIF: AMBIL DATA DARI ENDPOINT LAIN JIKA ENDPOINT UTAMA TIDAK ADA
Future<Map<String, dynamic>> getUserProfileFromDashboard() async {
  try {
    final dashboardResult = await getDashboardDataRobust();
    
    if (dashboardResult['success'] == true) {
      final dashboardData = dashboardResult['data'] ?? {};
      final profileData = dashboardData['profile'] ?? {};
      
      if (profileData.isNotEmpty) {
        print('✅ Profile data loaded from dashboard');
        return {
          'success': true,
          'data': profileData,
          'message': 'Profile data loaded from dashboard'
        };
      }
    }
    
    return {
      'success': false,
      'message': 'Tidak dapat mengambil data profile dari dashboard'
    };
  } catch (e) {
    return {
      'success': false,
      'message': 'Error loading profile from dashboard: $e'
    };
  }
}

  // ✅ FIX: CEK STATUS DOKUMEN YANG BENAR
Map<String, dynamic> _getDokumenStatus(Map<String, dynamic> user) {
  final ktp = user['foto_ktp'];
  final kk = user['foto_kk'];
  final diri = user['foto_diri'];
  final bukti = user['foto_bukti'];
  
  print('🐛 === DOCUMENT STATUS DEBUG ===');
  print('📄 KTP Status: $ktp');
  print('📄 KK Status: $kk');
  print('📄 Foto Diri Status: $diri');
  print('📄 Foto Bukti Status: $bukti');
  
  // ✅ FIX: CEK APAKAH FILE SUDAH ADA DI SERVER
  final hasKTP = ktp != null && 
                ktp.toString().isNotEmpty && 
                ktp != 'uploaded' &&
                ktp.toString().contains('.jpg');
  
  final hasKK = kk != null && 
               kk.toString().isNotEmpty && 
               kk != 'uploaded' &&
               kk.toString().contains('.jpg');
  
  final hasDiri = diri != null && 
                 diri.toString().isNotEmpty && 
                 diri != 'uploaded' &&
                 diri.toString().contains('.jpg');
  
  final hasBukti = bukti != null && 
                  bukti.toString().isNotEmpty && 
                  bukti != 'uploaded' &&
                  bukti.toString().contains('.jpg');
  
  print('✅ KTP Uploaded: $hasKTP');
  print('✅ KK Uploaded: $hasKK');
  print('✅ Foto Diri Uploaded: $hasDiri');
  print('✅ Foto Bukti Uploaded: $hasBukti');
  print('🐛 === DEBUG END ===');
  
  return {
    'ktp': hasKTP,
    'kk': hasKK,
    'diri': hasDiri,
    'bukti': hasBukti,
    'allComplete': hasKTP && hasKK && hasDiri && hasBukti,
  };
}

  // ✅ UPLOAD BUKTI TRANSFER: 3 DUMMY + 1 ASLI
  Future<Map<String, dynamic>> uploadBuktiTransferLengkap({
    required String transaksiId,
    required String jenisTransaksi,
    required String buktiTransferAsliPath, // ASLI
    required String dummyFilePath1,        // DUMMY 1
    required String dummyFilePath2,        // DUMMY 2  
    required String dummyFilePath3,        // DUMMY 3
  }) async {
    try {
      print('🚀 UPLOAD BUKTI TRANSFER LENGKAP START (3 DUMMY + 1 ASLI)');
      print('📁 Transaksi ID: $transaksiId');
      print('📁 Jenis: $jenisTransaksi');
      print('📁 Files to upload:');
      print('   - bukti_transfer (ASLI): $buktiTransferAsliPath');
      print('   - dummy_1: $dummyFilePath1');
      print('   - dummy_2: $dummyFilePath2');
      print('   - dummy_3: $dummyFilePath3');

      // ✅ VALIDASI SEMUA FILE
      final filesToValidate = {
        'bukti_transfer': buktiTransferAsliPath,
        'dummy_1': dummyFilePath1,
        'dummy_2': dummyFilePath2,
        'dummy_3': dummyFilePath3,
      };

      for (var entry in filesToValidate.entries) {
        final file = File(entry.value);
        if (!await file.exists()) {
          return {
            'success': false,
            'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'
          };
        }
      }

      // ✅ GET HEADERS
      final headers = await getMultipartHeaders();
      
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/transaction/uploadBukti')
      );
      request.headers.addAll(headers);

      // ✅ TAMBAHKAN SEMUA FILE
      try {
        // ✅ bukti_transfer (ASLI)
        request.files.add(await http.MultipartFile.fromPath(
          'bukti_transfer',
          buktiTransferAsliPath,
          filename: 'bukti_${jenisTransaksi}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        // ✅ DUMMY 1
        request.files.add(await http.MultipartFile.fromPath(
          'foto_dummy_1',
          dummyFilePath1,
          filename: 'dummy_1_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        // ✅ DUMMY 2
        request.files.add(await http.MultipartFile.fromPath(
          'foto_dummy_2',
          dummyFilePath2,
          filename: 'dummy_2_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        // ✅ DUMMY 3
        request.files.add(await http.MultipartFile.fromPath(
          'foto_dummy_3',
          dummyFilePath3,
          filename: 'dummy_3_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

        print('✅ Semua file bukti transfer berhasil ditambahkan');
      } catch (e) {
        print('❌ Gagal menambahkan file bukti: $e');
        return {
          'success': false,
          'message': 'Gagal menambahkan file bukti: $e'
        };
      }

      // ✅ TAMBAHKAN FORM FIELDS
      request.fields['transaksi_id'] = transaksiId;
      request.fields['jenis_transaksi'] = jenisTransaksi;
      
      // ✅ TAMBAHKAN USER DATA
      final currentUser = await getCurrentUser();
      if (currentUser != null && currentUser['user_id'] != null) {
        request.fields['user_id'] = currentUser['user_id'].toString();
      }

      print('📤 Request fields: ${request.fields}');
      print('📤 Total files: ${request.files.length}');

      // ✅ KIRIM REQUEST
      final response = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();
      
      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        if (data['status'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Bukti transfer berhasil diupload',
            'data': data
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Upload bukti transfer gagal'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Upload bukti transfer gagal: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ UPLOAD BUKTI TRANSFER ERROR: $e');
      return {
        'success': false,
        'message': 'Upload bukti transfer error: $e'
      };
    }
  }

  // ✅ METHOD SINGLE UPLOAD (backward compatibility)
  Future<Map<String, dynamic>> uploadFoto({
    required String type,
    required String filePath,
  }) async {
    try {
      print('🚀 SINGLE UPLOAD START: $type');
      print('📁 File path: $filePath');
      
      File file = File(filePath);
      if (!await file.exists()) {
        return {
          'success': false, 
          'message': 'File tidak ditemukan: $filePath'
        };
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return {
          'success': false, 
          'message': 'File kosong'
        };
      }

      final headers = await getMultipartHeaders();
      
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/users/setPhoto')
      );
      request.headers.addAll(headers);

      String usedFieldName = 'foto';
      
      try {
        var multipartFile = await http.MultipartFile.fromPath(
          usedFieldName,
          filePath,
          filename: '${type}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(multipartFile);
        print('✅ File berhasil dilampirkan dengan field: $usedFieldName');
      } catch (e) {
        print('❌ Gagal dengan field $usedFieldName: $e');
        return {
          'success': false, 
          'message': 'Gagal menambahkan file ke request'
        };
      }

      request.fields['type'] = type;
      
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        if (currentUser['user_id'] != null) {
          request.fields['user_id'] = currentUser['user_id'].toString();
        }
        if (currentUser['user_key'] != null) {
          request.fields['user_key'] = currentUser['user_key'].toString();
        }
      }

      print('📤 Request fields: ${request.fields}');
      print('📤 Files count: ${request.files.length}');

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();
      
      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: $responseBody');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        
        if (data['status'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Upload berhasil',
            'data': data,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Upload gagal',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server error ${response.statusCode}: $responseBody',
        };
      }
    } catch (e) {
      print('❌ UPLOAD ERROR: $e');
      return {
        'success': false,
        'message': 'Upload error: $e'
      };
    }
  }

// ✅ FIX: GET USER DATA DENGAN PRIORITAS DATA LOGIN
Future<Map<String, dynamic>?> getCurrentUserForUpload() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    print('🔍 Getting user data for upload...');
    
    // ✅ PRIORITAS 1: CEK DATA LOGIN (YANG ADA user_id dan user_key)
    final loginUserString = prefs.getString('login_user');
    if (loginUserString != null && loginUserString.isNotEmpty) {
      final loginData = jsonDecode(loginUserString);
      if (loginData['user'] != null) {
        final userData = loginData['user'];
        print('✅ Using login user data:');
        print('   - user_id: ${userData['user_id']}');
        print('   - user_key: ${userData['user_key']?.substring(0, 10)}...');
        return userData;
      }
    }
    
    // ✅ PRIORITAS 2: CEK USER DATA BIASA
    final userString = prefs.getString('user');
    if (userString != null && userString.isNotEmpty) {
      final userData = jsonDecode(userString);
      print('⚠️ Using regular user data (may lack user_id/user_key):');
      print('   - Available keys: ${userData.keys}');
      return userData;
    }
    
    print('❌ No user data found in storage');
    return null;
  } catch (e) {
    print('❌ Error getting user data for upload: $e');
    return null;
  }
}

// ✅ FIX: SIMPAN DATA LOGIN DENGAN BENAR
Future<void> saveLoginData(Map<String, dynamic> loginResponse) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    print('💾 Saving login data...');
    
    // Simpan token
    if (loginResponse['token'] != null) {
      await prefs.setString('token', loginResponse['token']);
      print('   ✅ Token saved');
    }
    
    // ✅ SIMPAN USER DATA LENGKAP (DENGAN user_id DAN user_key)
    if (loginResponse['user'] != null) {
      final userData = loginResponse['user'];
      await prefs.setString('user', jsonEncode(userData));
      print('   ✅ User data saved with keys: ${userData.keys}');
    }
    
    // ✅ SIMPAN SEBAGAI login_user UNTUK BACKUP
    await prefs.setString('login_user', jsonEncode(loginResponse));
    print('   ✅ Login response saved as backup');
    
    // ✅ DEBUG: CEK DATA YANG DISIMPAN
    final savedUser = prefs.getString('user');
    final savedLogin = prefs.getString('login_user');
    
    print('📦 Storage check:');
    print('   - User data: ${savedUser != null ? "✅" : "❌"}');
    print('   - Login data: ${savedLogin != null ? "✅" : "❌"}');
    
    if (loginResponse['user'] != null) {
      final user = loginResponse['user'];
      print('👤 Final saved user data:');
      print('   - user_id: ${user['user_id']}');
      print('   - user_key: ${user['user_key']?.substring(0, 10)}...');
      print('   - username: ${user['username']}');
    }
  } catch (e) {
    print('❌ Error saving login data: $e');
  }
}

  // ✅ GET CURRENT USER FROM LOCAL STORAGE
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      if (userString != null && userString.isNotEmpty) {
        return jsonDecode(userString);
      }
      return null;
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  // ✅ CLEAR TOKEN
  Future<void> _clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      await prefs.remove('ci_session');
      await prefs.remove('user_info');
      print('🔐 Token cleared due to expiration');
    } catch (e) {
      print('❌ Error clearing token: $e');
    }
  }

// ✅ FIXED LOGIN METHOD - DENGAN RESTORE BACKUP
Future<Map<String, dynamic>> login(String username, String password) async {
  try {
    final headers = getAuthHeaders();
    
    print('🔐 Login attempt for: $username');
    
    final response = await http.post(
      Uri.parse('$baseUrl/login/auth'),
      headers: headers,
      body: 'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}',
    ).timeout(const Duration(seconds: 30));

    print('📡 Login Response Status: ${response.statusCode}');
    print('📡 Login Response Body: ${response.body}');

    // ✅ FIX: HANDLE 400 STATUS CODE (BAD REQUEST) - BIASANYA UNTUK LOGIN SALAH
    if (response.statusCode == 200 || response.statusCode == 400) {
      final data = jsonDecode(response.body);

      if (data['status'] == true) {
        // ✅ LOGIN SUKSES
        final userKey = data['user_key'].toString();
        final userData = {
          'user_id': data['user_id'],
          'user_name': data['user_name'],
          'nama': data['nama'],
          'email': data['email'],
          'status_user': data['status_user'],
          'user_key': userKey,
        };

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', userKey);
        await prefs.setString('user', jsonEncode(userData));
        
        // ✅ SIMPAN DATA LOGIN UNTUK UPLOAD
        await saveLoginData({
          'token': userKey,
          'user': userData,
          'status': true,
          'message': data['message'] ?? 'Login berhasil'
        });
        
        if (response.headers['set-cookie'] != null) {
          final cookies = response.headers['set-cookie'];
          if (cookies != null && cookies.contains('ci_session')) {
            final sessionMatch = RegExp(r'ci_session=([^;]+)').firstMatch(cookies);
            if (sessionMatch != null) {
              final sessionValue = sessionMatch.group(1);
              await prefs.setString('ci_session', sessionValue!);
              print('✅ CI Session saved: ${sessionValue.substring(0, 10)}...');
            }
          }
        }
        
        // ✅ ✅ ✅ TAMBAHKAN INI: RESTORE BACKUP DATA SETELAH LOGIN
        await restoreBackupData();
        
        print('✅ Login successful for user: ${data['user_name']}');
        
        return {
          'success': true,
          'token': userKey,
          'user': userData,
          'message': data['message'] ?? 'Login berhasil'
        };
      } else {
        // ✅ LOGIN GAGAL - PASSWORD SALAH DLL
        print('❌ Login failed: ${data['message']}');
        
        return {
          'success': false,
          'message': data['message'] ?? 'Username atau password salah',
          'error_code': 'LOGIN_FAILED'
        };
      }
    } else if (response.statusCode == 401) {
      // ✅ UNAUTHORIZED
      return {
        'success': false,
        'message': 'Akun tidak terdaftar atau tidak aktif',
        'error_code': 'UNAUTHORIZED'
      };
    } else if (response.statusCode == 500) {
      // ✅ SERVER ERROR
      return {
        'success': false,
        'message': 'Terjadi kesalahan server. Silakan coba lagi.',
        'error_code': 'SERVER_ERROR'
      };
    } else {
      // ✅ OTHER HTTP ERRORS
      return {
        'success': false,
        'message': 'Terjadi kesalahan (${response.statusCode})',
        'error_code': 'HTTP_${response.statusCode}'
      };
    }
  } on SocketException {
    return {
      'success': false,
      'message': 'Tidak ada koneksi internet',
      'error_code': 'NO_INTERNET'
    };
  } on http.ClientException catch (e) {
    return {
      'success': false,
      'message': 'Gagal terhubung ke server: $e',
      'error_code': 'CONNECTION_ERROR'
    };
  }
}

// ✅ METHOD UNTUK RESTORE DATA SETELAH LOGIN
Future<void> restoreBackupData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    print('🔄 Checking for backup data...');
    
    // ✅ CEK APAKAH ADA BACKUP DATA
    final userBackup = prefs.getString('user_backup');
    final loginBackup = prefs.getString('login_backup');
    
    if (userBackup != null) {
      print('✅ Restoring user backup data...');
      
      // ✅ DAPATKAN DATA USER YANG BARU LOGIN
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        final backupUser = jsonDecode(userBackup);
        
        // ✅ GABUNGKAN DATA: data login baru + data backup lama
        final mergedUser = {
          ...currentUser,           // Data baru dari login (user_id, token, dll)
          ...backupUser,            // Data backup (profile lengkap, alamat, dll)
          
          // ✅ PASTIKAN DATA LOGIN TETAP YANG BARU
          'user_id': currentUser['user_id'],
          'user_key': currentUser['user_key'],
          'token': currentUser['token'],
          'status_user': currentUser['status_user'],
        };
        
        await prefs.setString('user', jsonEncode(mergedUser));
        print('✅ User backup data restored successfully');
        
        // ✅ HAPUS BACKUP SETELAH BERHASIL RESTORE
        await prefs.remove('user_backup');
      }
    }
    
    if (loginBackup != null) {
      print('✅ Restoring login backup data...');
      await prefs.setString('login_user', loginBackup);
      await prefs.remove('login_backup');
      print('✅ Login backup data restored');
    }
    
    // ✅ CEK APAKAH MASIH ADA DATA REGISTRASI YANG BELUM DISIMPAN
    final regData = prefs.getString('registration_data');
    if (regData != null) {
      print('🔄 Found registration data, attempting to save...');
      final regUserData = jsonDecode(regData);
      
      // ✅ COBA SIMPAN DATA REGISTRASI KE PROFILE
      try {
        final currentUser = await getCurrentUser();
        if (currentUser != null) {
          final mergedWithReg = {...currentUser, ...regUserData};
          await prefs.setString('user', jsonEncode(mergedWithReg));
          await prefs.remove('registration_data');
          print('✅ Registration data merged to user profile');
        }
      } catch (e) {
        print('⚠️ Failed to merge registration data: $e');
      }
    }
    
  } catch (e) {
    print('❌ Error restoring backup data: $e');
  }
}

// ✅ FIX: LOGOUT METHOD YANG TIDAK MENGHAPUS BACKUP DATA
Future<Map<String, dynamic>> logout() async {
  try {
    // ✅ 1. BACKUP DATA PENTING SEBELUM LOGOUT
    final prefs = await SharedPreferences.getInstance();
    
    // Simpan data penting ke backup keys
    final userData = prefs.getString('user');
    final loginData = prefs.getString('login_user');
    final registrationData = prefs.getString('registration_data');
    
    if (userData != null) {
      await prefs.setString('user_backup', userData);
      print('✅ User data backed up before logout');
    }
    
    if (loginData != null) {
      await prefs.setString('login_backup', loginData);
      print('✅ Login data backed up before logout');
    }

    // ✅ 2. PANGGIL API LOGOUT (OPTIONAL)
    try {
      final headers = await getProtectedHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/logout'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 5));
      print('🔐 Logout API call completed');
    } catch (e) {
      print('⚠️ Logout API call failed: $e');
      // Tidak masalah jika API gagal, yang penting local data dihandle
    }

    // ✅ 3. HAPUS HANYA DATA SESSION, BUKAN SEMUA DATA
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('ci_session');
    await prefs.remove('login_user');
    
    // ✅ JANGAN GUNAKAN prefs.clear()! ❌
    // prefs.clear() akan menghapus SEMUA data termasuk backup
    
    print('✅ Logout successful - session cleared, backup preserved');
    
    return {
      'success': true,
      'message': 'Logout berhasil'
    };
    
  } catch (e) {
    print('❌ Logout error: $e');
    return {
      'success': false,
      'message': 'Gagal logout: $e'
    };
  }
}

  // ✅ METHOD UNTUK SYNC DATA LOKAL KE SERVER
Future<Map<String, dynamic>> syncLocalDataToServer() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    
    if (userString == null) {
      return {'success': false, 'message': 'Tidak ada data lokal untuk disinkronisasi'};
    }
    
    final localData = jsonDecode(userString);
    
    // ✅ FILTER HANYA DATA YANG PERLU DIKIRIM KE SERVER
    final dataToSync = {
      'username': localData['username'],
      'fullname': localData['fullname'] ?? localData['nama'],
      'email': localData['email'],
      'telp': localData['telp'] ?? localData['phone'],
      'job': localData['job'] ?? localData['pekerjaan'],
      'birth_place': localData['birth_place'] ?? localData['tempat_lahir'],
      'agama_id': localData['agama_id'],
      'ktp_alamat': localData['ktp_alamat'] ?? localData['alamat'],
      'ktp_rt': localData['ktp_rt'] ?? localData['rt'],
      'ktp_rw': localData['ktp_rw'] ?? localData['rw'],
      'ktp_no': localData['ktp_no'] ?? localData['no_rumah'],
      'ktp_postal': localData['ktp_postal'] ?? localData['kode_pos'],
      'ktp_id_province': localData['ktp_id_province'] ?? localData['id_province'],
      'ktp_id_regency': localData['ktp_id_regency'] ?? localData['id_regency'],
      'domisili_alamat': localData['domisili_alamat'],
      'domisili_rt': localData['domisili_rt'],
      'domisili_rw': localData['domisili_rw'],
      'domisili_no': localData['domisili_no'],
      'domisili_postal': localData['domisili_postal'],
      'domisili_id_province': localData['domisili_id_province'],
      'domisili_id_regency': localData['domisili_id_regency'],
    };
    
    // ✅ COBA BERBAGAI ENDPOINT
    final possibleEndpoints = [
      '$baseUrl/users/updateProfile',
      '$baseUrl/users/update',
      '$baseUrl/users/setProfile',
    ];
    
    for (var endpoint in possibleEndpoints) {
      try {
        final headers = await getProtectedHeaders();
        final body = dataToSync.entries
            .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}')
            .join('&');
        
        final response = await http.post(
          Uri.parse(endpoint),
          headers: headers,
          body: body,
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == true) {
            print('✅ Data berhasil disinkronisasi ke: $endpoint');
            return {
              'success': true,
              'message': 'Data berhasil disinkronisasi',
              'endpoint': endpoint
            };
          }
        }
      } catch (e) {
        print('❌ Endpoint $endpoint gagal: $e');
        continue;
      }
    }
    
    return {
      'success': false, 
      'message': 'Semua endpoint sinkronisasi gagal'
    };
    
  } catch (e) {
    return {
      'success': false,
      'message': 'Error sinkronisasi: $e'
    };
  }
}

// ✅ TAMBAHKAN DI ApiService - METHOD UNTUK UPLOAD PROFILE PHOTO
Future<Map<String, dynamic>> setProfilePhoto(String filePath) async {
  try {
    print('🚀 UPLOAD PROFILE PHOTO START');
    print('📁 File path: $filePath');

    // ✅ VALIDASI FILE
    final file = File(filePath);
    if (!await file.exists()) {
      return {
        'success': false,
        'message': 'File tidak ditemukan: $filePath'
      };
    }

    final fileSize = await file.length();
    if (fileSize == 0) {
      return {
        'success': false,
        'message': 'File kosong (0 bytes)'
      };
    }

    print('✅ File valid, size: $fileSize bytes');

    // ✅ DAPATKAN HEADERS SESUAI SPESIFIKASI CURL
    final prefs = await SharedPreferences.getInstance();
    final userKey = prefs.getString('token'); // user_key dari login
    final sessionCookie = prefs.getString('ci_session');

    if (userKey == null || userKey.isEmpty) {
      return {
        'success': false,
        'message': 'User tidak terautentikasi. Silakan login kembali.',
        'token_expired': true
      };
    }

    print('✅ User key found: ${userKey.substring(0, 10)}...');

    // ✅ HEADERS SESUAI CURL: device-id, x-api-key, content-type, cookie
    final headers = {
      'device-id': '12341231313131',
      'x-api-key': userKey,
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    // ✅ TAMBAHKAN COOKIE SESSION JIKA ADA
    if (sessionCookie != null && sessionCookie.isNotEmpty) {
      headers['Cookie'] = 'ci_session=$sessionCookie';
      print('✅ Cookie session ditambahkan: ${sessionCookie.substring(0, 20)}...');
    } else {
      print('⚠️ Cookie session tidak ditemukan!');
    }

    print('📤 Headers: ${headers.keys}');

    // ✅ BUAT MULTIPART REQUEST
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('http://demo.bsdeveloper.id/api/users/setProfilePhoto')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN FILE DENGAN FIELD NAME "foto_diri" SESUAI CURL
    try {
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri', // ✅ SESUAI CURL: --form 'foto_diri=@"test.jpg"'
        filePath,
        filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ File berhasil ditambahkan dengan field: foto_diri');
    } catch (e) {
      print('❌ Gagal menambahkan file: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke: http://demo.bsdeveloper.id/api/users/setProfilePhoto');
    final response = await request.send().timeout(const Duration(seconds: 60));
    
    // ✅ BACA RESPONSE
    final responseBody = await response.stream.bytesToString();
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true || data['success'] == true) {
        print('✅ UPLOAD PROFILE PHOTO SUCCESS');
        return {
          'success': true,
          'message': data['message'] ?? 'Foto profil berhasil diupload',
          'data': data
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        
        // ✅ CEK JIKA ADA ISSUE DENGAN AUTHENTIKASI
        if (data['message']?.toString().toLowerCase().contains('session') == true ||
            data['message']?.toString().toLowerCase().contains('login') == true ||
            data['message']?.toString().toLowerCase().contains('auth') == true ||
            data['message']?.toString().toLowerCase().contains('token') == true) {
          return {
            'success': false,
            'message': 'Sesi telah berakhir. Silakan login kembali.',
            'token_expired': true
          };
        }
        
        return {
          'success': false,
          'message': data['message'] ?? 'Upload foto profil gagal',
          'data': data
        };
      }
    } else if (response.statusCode == 401) {
      print('❌ Unauthorized - kemungkinan token expired');
      return {
        'success': false,
        'message': 'Sesi telah berakhir. Silakan login kembali.',
        'token_expired': true
      };
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Upload gagal: ${response.statusCode} - $responseBody'
      };
    }
  } catch (e) {
    print('❌ UPLOAD PROFILE PHOTO ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

  // ✅ METHOD UNTUK UPLOAD 3 FILE ASLI + FOTO DIRI SEBAGAI BUKTI (FILE KE-4)
Future<Map<String, dynamic>> uploadThreeRealPhotos({
  required String fotoKtpPath,
  required String fotoKkPath, 
  required String fotoDiriPath,
}) async {
  try {
    print('🚀 UPLOAD 3 REAL + FOTO DIRI AS BUKTI START');
    print('📁 Real files:');
    print('   - KTP: $fotoKtpPath');
    print('   - KK: $fotoKkPath'); 
    print('   - Foto Diri: $fotoDiriPath');
    print('   - Foto Bukti: $fotoDiriPath (DUPLIKAT DARI FOTO DIRI)');

    // ✅ DAPATKAN USER DATA
    final currentUser = await getCurrentUserForUpload();
    if (currentUser == null) {
      return {'success': false, 'message': 'User tidak ditemukan. Silakan login ulang.'};
    }

    final userId = currentUser['user_id']?.toString();
    final userKey = currentUser['user_key']?.toString();

    if (userId == null || userId.isEmpty || userKey == null || userKey.isEmpty) {
      return {'success': false, 'message': 'Data user tidak lengkap. user_id: $userId, user_key: $userKey'};
    }

    print('✅ User data valid - user_id: $userId');

    // ✅ VALIDASI SEMUA FILE
    final filesToValidate = {
      'KTP': fotoKtpPath,
      'KK': fotoKkPath,
      'Foto Diri': fotoDiriPath,
    };

    for (var entry in filesToValidate.entries) {
      final file = File(entry.value);
      if (!await file.exists()) {
        return {'success': false, 'message': 'File ${entry.key} tidak ditemukan: ${entry.value}'};
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return {'success': false, 'message': 'File ${entry.key} kosong (0 bytes)'};
      }

      print('✅ File ${entry.key}: $fileSize bytes');
    }

    // ✅ GET HEADERS
    final headers = await getMultipartHeaders();
    print('📤 Headers: ${headers.keys}');

    // ✅ BUAT REQUEST
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse('$baseUrl/users/setPhoto')
    );
    request.headers.addAll(headers);

    // ✅ TAMBAHKAN 4 FILE: 3 ASLI + 1 DUPLIKAT FOTO DIRI SEBAGAI BUKTI
    try {
      // ✅ FILE 1: KTP (ASLI)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_ktp',
        fotoKtpPath,
        filename: 'ktp_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added KTP file');

      // ✅ FILE 2: KK (ASLI)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_kk',
        fotoKkPath,
        filename: 'kk_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added KK file');

      // ✅ FILE 3: FOTO DIRI (ASLI)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_diri',
        fotoDiriPath,
        filename: 'diri_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added Foto Diri file');

      // ✅ FILE 4: FOTO BUKTI (DUPLIKAT DARI FOTO DIRI)
      request.files.add(await http.MultipartFile.fromPath(
        'foto_bukti',
        fotoDiriPath, // FILE YANG SAMA DENGAN FOTO DIRI
        filename: 'bukti_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      print('✅ Added Foto Bukti (duplicate from Foto Diri)');

    } catch (e) {
      print('❌ Error adding files: $e');
      return {
        'success': false,
        'message': 'Gagal menambahkan file: $e'
      };
    }

    // ✅ TAMBAHKAN FORM FIELDS
    request.fields['type'] = 'complete_upload';
    request.fields['user_id'] = userId;
    request.fields['user_key'] = userKey;
    request.fields['upload_type'] = 'dokumen_lengkap';

    print('📤 Request fields: ${request.fields}');
    print('📤 Total files: ${request.files.length}');

    // ✅ KIRIM REQUEST
    print('🔄 Mengirim request ke server...');
    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString();
    
    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: $responseBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      
      if (data['status'] == true) {
        print('🎉 UPLOAD 3 ASLI + 1 DUPLIKAT FOTO DIRI SUKSES!');
        return {
          'success': true,
          'message': data['message'] ?? 'Semua dokumen berhasil diupload',
          'data': data
        };
      } else {
        print('❌ Upload gagal: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Upload dokumen gagal',
          'data': data
        };
      }
    } else {
      print('❌ Server error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Server error ${response.statusCode}: $responseBody'
      };
    }
    
  } catch (e) {
    print('❌ UPLOAD 3+1 ERROR: $e');
    return {
      'success': false,
      'message': 'Upload error: $e'
    };
  }
}

  // ✅ GET USER PROFILE
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final headers = await getProtectedHeaders();
      
      final prefs = await SharedPreferences.getInstance();
      final sessionCookie = prefs.getString('ci_session');
      
      var finalHeaders = Map<String, String>.from(headers);
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        finalHeaders['Cookie'] = 'ci_session=$sessionCookie';
      }
      
      print('🚀 Fetching user profile...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/users/userInfo'),
        headers: finalHeaders,
        body: '',
      ).timeout(const Duration(seconds: 30));

      print('📡 Profile API Response Status: ${response.statusCode}');
      print('📡 Profile API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          if (data['data'] != null) {
            await prefs.setString('user', jsonEncode(data['data']));
            print('✅ User profile saved to local storage');
          } else {
            await prefs.setString('user', jsonEncode(data));
            print('✅ User profile (root data) saved to local storage');
          }
          
          return {
            'success': true,
            'data': data['data'] ?? data,
            'message': data['message'] ?? 'Success get profile'
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil profile'
          };
        }
      } else if (response.statusCode == 401) {
        await _clearToken();
        return {
          'success': false,
          'message': 'Sesi telah berakhir',
          'token_expired': true
        };
      } else {
        print('❌ Profile API Error: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Gagal mengambil profile: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ Profile API Exception: $e');
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ✅ GET DASHBOARD DATA
  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final headers = await getProtectedHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/dashboard/getData'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? {},
            'message': data['message'] ?? 'Success get dashboard data'
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil data dashboard'
          };
        }
      } else if (response.statusCode == 401) {
        await _clearToken();
        return {
          'success': false,
          'message': 'Sesi telah berakhir, silakan login kembali',
          'token_expired': true
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil data dashboard: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ✅ FIX: ROBUST DASHBOARD DATA FETCHING
Future<Map<String, dynamic>> getDashboardDataRobust() async {
  try {
    print('🚀 Starting robust dashboard data loading...');
    
    // Coba ambil data dashboard utama dulu
    final dashboardResult = await getDashboardData();
    
    if (dashboardResult['success'] == true) {
      print('✅ Dashboard data loaded successfully');
      return dashboardResult;
    }
    
    print('🔄 Fallback ke manual data loading...');
    
    // Fallback: Ambil data secara manual dan parallel
    final results = await Future.wait([
      getAllSaldo(),
      getAlltaqsith(),
      getUserProfile(),
    ], eagerError: true);
    
    final saldoResult = results[0] as Map<String, dynamic>;
    final taqsithResult = results[1] as Map<String, dynamic>;
    final profileResult = results[2] as Map<String, dynamic>;
    
    // ✅ GABUNGKAN SEMUA DATA DENGAN HANDLING ERROR
    final combinedData = {
      'saldo': saldoResult['success'] == true ? saldoResult['data'] : _createDefaultSaldoData(),
      'taqsith': taqsithResult['success'] == true ? taqsithResult['processed_data'] : {'total_angsuran': 0, 'items': []},
      'profile': profileResult['success'] == true ? profileResult['data'] : {},
      'raw_taqsith': taqsithResult['success'] == true ? taqsithResult['data'] : [],
      'raw_master': taqsithResult['success'] == true ? taqsithResult['data_master'] : [],
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    print('✅ Manual dashboard data loaded successfully');
    
    return {
      'success': true,
      'data': combinedData,
      'message': 'Data dashboard berhasil diambil (fallback mode)',
      'source': 'fallback'
    };
    
  } catch (e) {
    print('❌ All dashboard methods failed: $e');
    return {
      'success': true,
      'data': {
        'saldo': _createDefaultSaldoData(),
        'taqsith': {'total_angsuran': 0, 'items': []},
        'profile': {},
        'raw_taqsith': [],
        'raw_master': [],
        'timestamp': DateTime.now().toIso8601String(),
      },
      'message': 'Menggunakan data default karena error',
      'source': 'default'
    };
  }
}

// ✅ CREATE DEFAULT SALDO DATA
Map<String, dynamic> _createDefaultSaldoData() {
  return {
    'pokok': 0,
    'wajib': 0,
    'sukarela': 0,
    'sitabung': 0,
    'siumna': 0,
    'siquna': 0,
    'saldo': 0,
  };
}

// ✅ FIX: GET ALL SALDO YANG SESUAI DENGAN RESPONSE + KEEP RAW DATA
Future<Map<String, dynamic>> getAllSaldo() async {
  try {
    final headers = await getProtectedHeaders();
    
    print('🚀 Fetching saldo data from API...');
    
    final response = await http.post(
      Uri.parse('$baseUrl/transaction/getAllSaldo'),
      headers: headers,
      body: '',
    ).timeout(const Duration(seconds: 30));

    print('📡 Saldo API Response Status: ${response.statusCode}');
    print('📡 Saldo API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data['status'] == true) {
        final responseData = data['data'] ?? {};
        
        print('✅ Saldo data structure: ${responseData.keys}');
        
        // ✅ NORMALISASI DATA SESUAI RESPONSE AKTUAL
        final normalizedData = _normalizeSaldoDataNew(responseData);
        
        return {
          'success': true,
          'data': normalizedData,
          'raw_data': responseData, // ← TAMBAH INI! Data mentah untuk riwayat
          'message': data['message'] ?? 'Success get saldo'
        };
      } else {
        print('❌ Saldo API status false: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mengambil data saldo'
        };
      }
    } else if (response.statusCode == 401) {
      await _clearToken();
      return {
        'success': false,
        'message': 'Sesi telah berakhir',
        'token_expired': true
      };
    } else {
      print('❌ Saldo API HTTP error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Gagal mengambil data saldo: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ Saldo API Exception: $e');
    return {
      'success': false,
      'message': 'Error: $e'
    };
  }
}

// ✅ FIX: NORMALISASI DATA SALDO BARU - SESUAI RESPONSE
Map<String, dynamic> _normalizeSaldoDataNew(Map<String, dynamic> rawData) {
  final normalized = <String, dynamic>{};
  
  print('🔧 Normalizing saldo data from: ${rawData.keys}');
  
  // ✅ HANDLE POKOK
  if (rawData.containsKey('pokok') && rawData['pokok'] is List) {
    final pokokList = rawData['pokok'] as List;
    if (pokokList.isNotEmpty) {
      final pokokItem = pokokList[0] as Map<String, dynamic>;
      normalized['pokok'] = _safeConvertToInt(pokokItem['saldo']);
      print('✅ Normalized pokok: ${pokokItem['saldo']} → ${normalized['pokok']}');
    } else {
      normalized['pokok'] = 0;
    }
  } else {
    normalized['pokok'] = 0;
  }
  
  // ✅ HANDLE WAJIB
  if (rawData.containsKey('wajib') && rawData['wajib'] is List) {
    final wajibList = rawData['wajib'] as List;
    if (wajibList.isNotEmpty) {
      final wajibItem = wajibList[0] as Map<String, dynamic>;
      normalized['wajib'] = _safeConvertToInt(wajibItem['saldo']);
      print('✅ Normalized wajib: ${wajibItem['saldo']} → ${normalized['wajib']}');
    } else {
      normalized['wajib'] = 0;
    }
  } else {
    normalized['wajib'] = 0;
  }
  
  // ✅ HANDLE SUKARELA (bisa null)
  if (rawData.containsKey('sukarela') && rawData['sukarela'] != null) {
    if (rawData['sukarela'] is List) {
      final sukarelaList = rawData['sukarela'] as List;
      if (sukarelaList.isNotEmpty) {
        final sukarelaItem = sukarelaList[0] as Map<String, dynamic>;
        normalized['sukarela'] = _safeConvertToInt(sukarelaItem['saldo']);
        print('✅ Normalized sukarela: ${sukarelaItem['saldo']} → ${normalized['sukarela']}');
      } else {
        normalized['sukarela'] = 0;
      }
    } else {
      normalized['sukarela'] = 0;
    }
  } else {
    normalized['sukarela'] = 0;
    print('⚠️ sukarela is null, setting to 0');
  }
  
  // ✅ HANDLE SITABUNG
  if (rawData.containsKey('sitabung') && rawData['sitabung'] is List) {
    final sitabungList = rawData['sitabung'] as List;
    if (sitabungList.isNotEmpty) {
      final sitabungItem = sitabungList[0] as Map<String, dynamic>;
      normalized['sitabung'] = _safeConvertToInt(sitabungItem['saldo']);
      print('✅ Normalized sitabung: ${sitabungItem['saldo']} → ${normalized['sitabung']}');
    } else {
      normalized['sitabung'] = 0;
    }
  } else {
    normalized['sitabung'] = 0;
  }
  
  // ✅ HANDLE SIUMNA (bisa null)
  if (rawData.containsKey('siumna') && rawData['siumna'] != null) {
    if (rawData['siumna'] is List) {
      final siumnaList = rawData['siumna'] as List;
      if (siumnaList.isNotEmpty) {
        final siumnaItem = siumnaList[0] as Map<String, dynamic>;
        normalized['siumna'] = _safeConvertToInt(siumnaItem['saldo']);
        print('✅ Normalized siumna: ${siumnaItem['saldo']} → ${normalized['siumna']}');
      } else {
        normalized['siumna'] = 0;
      }
    } else {
      normalized['siumna'] = 0;
    }
  } else {
    normalized['siumna'] = 0;
    print('⚠️ siumna is null, setting to 0');
  }
  
  // ✅ HANDLE SIQUNA (bisa null)
  if (rawData.containsKey('siquna') && rawData['siquna'] != null) {
    if (rawData['siquna'] is List) {
      final siqunaList = rawData['siquna'] as List;
      if (siqunaList.isNotEmpty) {
        final siqunaItem = siqunaList[0] as Map<String, dynamic>;
        normalized['siquna'] = _safeConvertToInt(siqunaItem['saldo']);
        print('✅ Normalized siquna: ${siqunaItem['saldo']} → ${normalized['siquna']}');
      } else {
        normalized['siquna'] = 0;
      }
    } else {
      normalized['siquna'] = 0;
    }
  } else {
    normalized['siquna'] = 0;
    print('⚠️ siquna is null, setting to 0');
  }
  
  // ✅ HITUNG TOTAL SALDO
  final total = (normalized['pokok'] ?? 0) + 
               (normalized['wajib'] ?? 0) + 
               (normalized['sukarela'] ?? 0) + 
               (normalized['sitabung'] ?? 0) + 
               (normalized['siumna'] ?? 0) + 
               (normalized['siquna'] ?? 0);
  normalized['saldo'] = total;
  
  print('📊 Final normalized saldo data:');
  print('   - Pokok: ${normalized['pokok']}');
  print('   - Wajib: ${normalized['wajib']}');
  print('   - Sukarela: ${normalized['sukarela']}');
  print('   - Sitabung: ${normalized['sitabung']}');
  print('   - Siumna: ${normalized['siumna']}');
  print('   - Siquna: ${normalized['siquna']}');
  print('   - TOTAL: ${normalized['saldo']}');
  
  return normalized;
}

  // ✅ GET ALL ANGSURAN/TAQSITH
  Future<Map<String, dynamic>> getAllAngsuran() async {
    try {
      final headers = await getProtectedHeaders();
      
      print('🚀 Fetching angsuran data from API...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/getAllTaqsith'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      print('📡 Angsuran API Response Status: ${response.statusCode}');
      print('📡 Angsuran API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          dynamic responseData = data['data'] ?? {};
          
          if (responseData is List) {
            print('✅ Angsuran data is List with ${responseData.length} items');
            return {
              'success': true,
              'data': responseData,
              'message': data['message'] ?? 'Success get angsuran'
            };
          }
          else if (responseData is Map) {
            if (responseData.containsKey('angsuran')) {
              final angsuranList = responseData['angsuran'];
              if (angsuranList is List) {
                print('✅ Found angsuran list with ${angsuranList.length} items');
                return {
                  'success': true,
                  'data': angsuranList,
                  'message': data['message'] ?? 'Success get angsuran'
                };
              }
            }
            if (responseData.containsKey('taqsith')) {
              final taqsithList = responseData['taqsith'];
              if (taqsithList is List) {
                print('✅ Found taqsith list with ${taqsithList.length} items');
                return {
                  'success': true,
                  'data': taqsithList,
                  'message': data['message'] ?? 'Success get angsuran'
                };
              }
            }
            if (responseData.containsKey('data')) {
              final nestedData = responseData['data'];
              if (nestedData is List) {
                print('✅ Found nested data list with ${nestedData.length} items');
                return {
                  'success': true,
                  'data': nestedData,
                  'message': data['message'] ?? 'Success get angsuran'
                };
              }
            }
            
            print('⚠️ Angsuran data is Map but no valid list found, returning empty');
            return {
              'success': true,
              'data': [],
              'message': data['message'] ?? 'Success get angsuran'
            };
          }
          else {
            print('⚠️ Angsuran data is null or other type: ${responseData.runtimeType}');
            return {
              'success': true,
              'data': [],
              'message': data['message'] ?? 'Success get angsuran'
            };
          }
        } else {
          print('❌ Angsuran API status false: ${data['message']}');
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil data angsuran'
          };
        }
      } else if (response.statusCode == 401) {
        await _clearToken();
        return {
          'success': false,
          'message': 'Sesi telah berakhir',
          'token_expired': true
        };
      } else {
        print('❌ Angsuran API HTTP error: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Gagal mengambil data angsuran: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ Angsuran API Exception: $e');
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

// ✅ FIX: GET ALL TAQSITH YANG SESUAI DENGAN RESPONSE
Future<Map<String, dynamic>> getAlltaqsith() async {
  try {
    final headers = await getProtectedHeaders();
    
    print('🚀 Fetching taqsith data from API...');
    
    final response = await http.post(
      Uri.parse('$baseUrl/transaction/getAlltaqsith'),
      headers: headers,
      body: '',
    ).timeout(const Duration(seconds: 30));

    print('📡 Taqsith API Response Status: ${response.statusCode}');
    print('📡 Taqsith API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['status'] == true) {
        final responseData = data['data'] ?? [];
        final dataMaster = data['data_master'] ?? [];
        
        print('✅ Taqsith data: ${responseData.length} items');
        print('✅ Data master: ${dataMaster.length} items');
        
        // ✅ PROCESS DATA UNTUK DASHBOARD
        final processedData = _processTaqsithForDashboard(responseData, dataMaster);
        
        return {
          'success': true,
          'data': responseData,
          'data_master': dataMaster,
          'processed_data': processedData,
          'total_angsuran': processedData['total_angsuran'],
          'message': data['message'] ?? 'Success get taqsith'
        };
      } else {
        print('❌ Taqsith API status false: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mengambil data taqsith',
          'data': [],
          'data_master': [],
          'processed_data': {'total_angsuran': 0, 'items': []},
          'total_angsuran': 0
        };
      }
    } else if (response.statusCode == 401) {
      await _clearToken();
      return {
        'success': false,
        'message': 'Sesi telah berakhir',
        'token_expired': true,
        'data': [],
        'data_master': [],
        'processed_data': {'total_angsuran': 0, 'items': []},
        'total_angsuran': 0
      };
    } else {
      print('❌ Taqsith API HTTP error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Gagal mengambil data taqsith: ${response.statusCode}',
        'data': [],
        'data_master': [],
        'processed_data': {'total_angsuran': 0, 'items': []},
        'total_angsuran': 0
      };
    }
  } catch (e) {
    print('❌ Taqsith API Exception: $e');
    return {
      'success': false,
      'message': 'Error: $e',
      'data': [],
      'data_master': [],
      'processed_data': {'total_angsuran': 0, 'items': []},
      'total_angsuran': 0
    };
  }
}

// ✅ PROCESS TAQSITH DATA UNTUK DASHBOARD
Map<String, dynamic> _processTaqsithForDashboard(List<dynamic> data, List<dynamic> dataMaster) {
  double totalAngsuran = 0;
  final List<Map<String, dynamic>> items = [];
  
  print('🔧 Processing taqsith data for dashboard...');
  
  for (var item in data) {
    if (item is Map<String, dynamic>) {
      final idKredit = item['id_kredit']?.toString();
      final namaBarang = item['nama_barang']?.toString() ?? 'Unknown';
      final angsuranList = item['angsuran'] ?? [];
      
      // ✅ CARI DATA MASTER YANG SESUAI
      Map<String, dynamic>? masterItem;
      for (var master in dataMaster) {
        if (master is Map<String, dynamic> && master['id_kredit']?.toString() == idKredit) {
          masterItem = Map<String, dynamic>.from(master);
          break;
        }
      }
      
      // ✅ HITUNG TOTAL ANGSURAN DARI DATA MASTER
      if (masterItem != null && masterItem['angsuran'] != null) {
        final angsuranValue = _safeConvertToDouble(masterItem['angsuran']);
        totalAngsuran += angsuranValue;
        
        print('✅ Angsuran for $namaBarang: $angsuranValue');
      }
      
      items.add({
        'id_kredit': idKredit,
        'nama_barang': namaBarang,
        'total_angsuran': angsuranList.length,
        'master_data': masterItem,
      });
    }
  }
  
  print('📊 Total angsuran calculated: $totalAngsuran');
  
  return {
    'total_angsuran': totalAngsuran,
    'items': items,
  };
}

  // ✅ GET RIWAYAT TABUNGAN
  Future<Map<String, dynamic>> getRiwayatTabungan() async {
    try {
      final headers = await getProtectedHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/getRiwayatTabungan'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? [],
            'message': data['message'] ?? 'Success get riwayat tabungan'
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil riwayat tabungan'
          };
        }
      } else if (response.statusCode == 401) {
        await _clearToken();
        return {
          'success': false,
          'message': 'Sesi telah berakhir',
          'token_expired': true
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil riwayat tabungan: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ✅ GET RIWAYAT ANGSURAN
  Future<Map<String, dynamic>> getRiwayatAngsuran() async {
    try {
      final headers = await getProtectedHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/getRiwayatAngsuran'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? [],
            'message': data['message'] ?? 'Success get riwayat angsuran'
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil riwayat angsuran'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil riwayat angsuran: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

// ✅ FIX: REGISTER + AUTO UPDATE PROFILE + BACKUP DATA
Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
  try {
    final headers = getAuthHeaders();
    
    print('👤 Registering new user with data:');
    userData.forEach((key, value) {
      print('   - $key: $value');
    });

    final body = userData.entries
        .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}')
        .join('&');
    
    print('📤 Sending register request...');
    
    final response = await http.post(
      Uri.parse('$baseUrl/users/register'),
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 30));

    print('📡 Register Response Status: ${response.statusCode}');
    print('📡 Register Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['status'] == true) {
        print('✅ Registration successful');
        
        // ✅ ✅ ✅ SIMPAN DATA REGISTRASI KE BACKUP SEBELUM LOGIN
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('registration_data', jsonEncode(userData));
        print('✅ Registration data saved to backup');
        
        // ✅ OTOMATIS LOGIN SETELAH REGISTER BERHASIL
        final loginResult = await login(
          userData['username']?.toString() ?? '',
          userData['password']?.toString() ?? ''
        );
        
        if (loginResult['success'] == true) {
          print('✅ Auto-login after registration successful');
          
          // ✅ DATA SUDAH DI-RESTORE OTOMATIS OLEH login() METHOD
          // Karena kita sudah panggil restoreBackupData() di login()
          
          // ✅ COBA SYNC KE SERVER (OPTIONAL)
          try {
            final syncResult = await syncLocalDataToServer();
            if (syncResult['success'] == true) {
              print('✅ Registration data synced to server');
            } else {
              print('⚠️ Registration data saved locally only: ${syncResult['message']}');
            }
          } catch (e) {
            print('⚠️ Sync failed, but data saved locally: $e');
          }
          
          return {
            'success': true,
            'message': data['message'] ?? 'Registrasi dan login berhasil',
            'user': loginResult['user'],
            'token': loginResult['token'],
          };
        } else {
          print('⚠️ Registration successful but auto-login failed');
          // Data registrasi sudah disimpan di backup, bisa di-restore nanti
          return {
            'success': true,
            'message': 'Registrasi berhasil! Silakan login dengan username dan password Anda.',
            'need_login': true,
            'has_backup_data': true, // ✅ TANDA BAHWA ADA DATA BACKUP
          };
        }
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registrasi gagal'
        };
      }
    } else {
      return {
        'success': false,
        'message': 'Registrasi gagal: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ Register error: $e');
    return {
      'success': false,
      'message': 'Error: $e'
    };
  }
}

  // ✅ GET MASTER DATA
  Future<Map<String, dynamic>> getMasterData() async {
    try {
      final headers = getAuthHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/master/get'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
          'message': 'Success get master data'
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil master data'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ✅ GET PROVINCE
  Future<Map<String, dynamic>> getProvince() async {
    try {
      final headers = getAuthHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/master/getProvince'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          if (data.containsKey('provinces')) {
            return {
              'success': true,
              'data': data['provinces'] ?? [],
              'message': data['message'] ?? 'Success get province'
            };
          } else {
            return {
              'success': false,
              'message': 'Format response tidak sesuai: tidak ada key provinces'
            };
          }
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil data province'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil data province: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ✅ GET REGENCY
  Future<Map<String, dynamic>> getRegency(String idProvince) async {
    try {
      final headers = getAuthHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/master/getRegency'),
        headers: headers,
        body: 'id_province=$idProvince',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          if (data.containsKey('regency')) {
            return {
              'success': true,
              'data': data['regency'] ?? [],
              'message': data['message'] ?? 'Success get regency'
            };
          } else {
            return {
              'success': false,
              'message': 'Format response tidak sesuai: tidak ada key regency'
            };
          }
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil data regency'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil data regency: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ✅ INSERT INBOX
  Future<Map<String, dynamic>> insertInbox({
    required String subject,
    required String keterangan,
    required String userId,
  }) async {
    try {
      final headers = await getProtectedHeaders();
      
      final body = 'subject=${Uri.encodeComponent(subject)}&keterangan=${Uri.encodeComponent(keterangan)}&user_id=${Uri.encodeComponent(userId)}';

      final response = await http.post(
        Uri.parse('$baseUrl/transaction/InsertInbox'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['status'] == true,
          'message': data['message'] ?? 'Notifikasi berhasil dikirim'
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal mengirim notifikasi: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

// ✅ PERBAIKAN: GET ALL INBOX DENGAN HANDLING BERBAGAI FORMAT
Future<Map<String, dynamic>> getAllInbox() async {
  try {
    final headers = await getProtectedHeaders();
    
    print('📥 Getting all inbox data...');

    final response = await http.post(
      Uri.parse('$baseUrl/transaction/getAllinbox'),
      headers: headers,
      body: '',
    ).timeout(const Duration(seconds: 30));

    print('📡 Inbox Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['status'] == true) {
        final responseData = data['data'] ?? {};
        
        print('✅ Inbox data loaded successfully');
        print('📊 Inbox data structure: ${responseData.keys}');
        
        // ✅ PROCESS DATA UNTUK FORMAT YANG BERBEDA-BEDA
        List<Map<String, dynamic>> inboxList = [];
        
        // Format 1: Data langsung berupa list
        if (responseData is List) {
          inboxList = List<Map<String, dynamic>>.from(responseData);
        }
        // Format 2: Data dalam key 'inbox'
        else if (responseData['inbox'] is List) {
          inboxList = List<Map<String, dynamic>>.from(responseData['inbox']);
        }
        // Format 3: Data dalam key 'data'
        else if (responseData['data'] is List) {
          inboxList = List<Map<String, dynamic>>.from(responseData['data']);
        }
        // Format 4: Data dalam key 'messages'
        else if (responseData['messages'] is List) {
          inboxList = List<Map<String, dynamic>>.from(responseData['messages']);
        }
        
        // ✅ TAMBAHKAN ID JIKA TIDAK ADA
        for (int i = 0; i < inboxList.length; i++) {
          if (!inboxList[i].containsKey('id') && !inboxList[i].containsKey('id_inbox')) {
            inboxList[i]['id'] = '${DateTime.now().millisecondsSinceEpoch}_$i';
          }
        }
        
        return {
          'success': true,
          'data': responseData,
          'inbox_list': inboxList,
          'unread_count': responseData['belum_terbaca'] ?? 0,
          'message': data['message'] ?? 'Success get inbox'
        };
      } else {
        print('❌ Inbox API status false: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mengambil data inbox',
          'inbox_list': [],
          'unread_count': 0
        };
      }
    } else {
      print('❌ Inbox HTTP error: ${response.statusCode}');
      return {
        'success': false,
        'message': 'Gagal mengambil data inbox: ${response.statusCode}',
        'inbox_list': [],
        'unread_count': 0
      };
    }
  } catch (e) {
    print('❌ Inbox API Exception: $e');
    return {
      'success': false,
      'message': 'Error: $e',
      'inbox_list': [],
      'unread_count': 0
    };
  }
}

// ✅ METHOD UNTUK PROCESS INBOX DATA UNTUK DASHBOARD
// ✅ FIX: METHOD UNTUK PROCESS INBOX DATA UNTUK DASHBOARD - SESUAI FORMAT getAllInbox
List<Map<String, dynamic>> processInboxDataForDashboard(Map<String, dynamic> inboxData) {
  try {
    List<Map<String, dynamic>> result = [];
    
    print('🔧 Processing inbox data for dashboard...');
    print('📦 Inbox data keys: ${inboxData.keys}');
    
    // ✅ SESUAI DENGAN FORMAT getAllInbox YANG SUDAH BEKERJA
    // Data inbox biasanya ada di key 'inbox' dalam Map
    if (inboxData['inbox'] is List) {
      final inboxList = inboxData['inbox'] as List;
      result = inboxList.whereType<Map<String, dynamic>>().toList();
      print('✅ Using inbox list: ${result.length} items');
    } 
    // Atau mungkin di key 'data' sebagai List
    else if (inboxData['data'] is List) {
      final dataList = inboxData['data'] as List;
      result = dataList.whereType<Map<String, dynamic>>().toList();
      print('✅ Using data list: ${result.length} items');
    }
    // Jika tidak ada list yang jelas, coba ekstrak dari values
    else {
      print('⚠️ No direct list found, extracting from map values...');
      for (var value in inboxData.values) {
        if (value is List) {
          final listItems = value.whereType<Map<String, dynamic>>().toList();
          if (listItems.isNotEmpty) {
            result = listItems;
            print('✅ Found list in values: ${result.length} items');
            break;
          }
        }
      }
    }
    
    // ✅ TAMBAHKAN ID JIKA TIDAK ADA
    for (int i = 0; i < result.length; i++) {
      if (!result[i].containsKey('id') && !result[i].containsKey('id_inbox')) {
        result[i]['id'] = 'temp_${DateTime.now().millisecondsSinceEpoch}_$i';
      }
    }
    
    // ✅ SORT BY TIME (TERBARU DULUAN)
    result.sort((a, b) {
      final timeA = a['created_at'] ?? a['timestamp'] ?? a['time'] ?? '';
      final timeB = b['created_at'] ?? b['timestamp'] ?? b['time'] ?? '';
      return timeB.compareTo(timeA);
    });
    
    // ✅ LIMIT UNTUK DASHBOARD (10 ITEM SAJA)
    if (result.length > 10) {
      result = result.sublist(0, 10);
    }
    
    print('🎉 Processed ${result.length} inbox items for dashboard');
    return result;
    
  } catch (e) {
    print('❌ Error processing inbox data: $e');
    return [];
  }
}

// ✅ METHOD UNTUK GET REAL INBOX DATA (UNTUK FIREBASE SERVICE)
Future<List<Map<String, dynamic>>> getRealInboxData() async {
  try {
    final inboxResult = await getAllInbox();
    
    if (inboxResult['success'] == true) {
      return processInboxDataForDashboard(inboxResult['data'] ?? {});
    }
    
    return [];
  } catch (e) {
    print('❌ Error getting real inbox data: $e');
    return [];
  }
}

  // ✅ GET INBOX READ
  Future<Map<String, dynamic>> getInboxRead(String idInbox) async {
    try {
      final headers = await getProtectedHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/getInboxRead'),
        headers: headers,
        body: 'id_inbox=$idInbox',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['status'] == true,
          'message': data['message'] ?? 'Inbox ditandai terbaca'
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal menandai inbox'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

// ✅ METHOD UNTUK MARK ALL NOTIFICATIONS AS READ
Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
  try {
    print('📖 Marking all notifications as read...');
    
    final headers = await getProtectedHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/transaction/getInboxReadAll'),
      headers: headers,
      body: '',
    ).timeout(const Duration(seconds: 30));

    print('📡 Mark All as Read Response Status: ${response.statusCode}');
    print('📡 Mark All as Read Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? 'Semua notifikasi ditandai sebagai dibaca',
        'data': data
      };
    } else {
      return {
        'success': false,
        'message': 'Gagal menandai semua notifikasi sebagai dibaca: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ Mark all as read error: $e');
    return {
      'success': false,
      'message': 'Error menandai semua notifikasi sebagai dibaca: $e'
    };
  }
}

// ✅ METHOD UNTUK GET NOTIFICATION DETAIL
Future<Map<String, dynamic>> getNotificationDetail(String notificationId) async {
  try {
    print('🔍 Getting notification detail: $notificationId');
    
    final headers = await getProtectedHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/transaction/getInboxDetail'),
      headers: headers,
      body: 'id_inbox=$notificationId',
    ).timeout(const Duration(seconds: 30));

    print('📡 Notification Detail Response Status: ${response.statusCode}');
    print('📡 Notification Detail Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['status'] == true) {
        return {
          'success': true,
          'data': data['data'] ?? data,
          'message': data['message'] ?? 'Success get notification detail'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gagal mengambil detail notifikasi'
        };
      }
    } else {
      return {
        'success': false,
        'message': 'Gagal mengambil detail notifikasi: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ Get notification detail error: $e');
    return {
      'success': false,
      'message': 'Error mengambil detail notifikasi: $e'
    };
  }
}

// ✅ METHOD UNTUK HAPUS NOTIFIKASI TUNGGAL
Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
  try {
    print('🗑️ Deleting notification: $notificationId');
    
    final headers = await getProtectedHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/transaction/getInboxDeleted'),
      headers: headers,
      body: 'id_inbox=$notificationId',
    ).timeout(const Duration(seconds: 30));

    print('📡 Delete Notification Response Status: ${response.statusCode}');
    print('📡 Delete Notification Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? 'Notifikasi berhasil dihapus',
        'data': data
      };
    } else {
      return {
        'success': false,
        'message': 'Gagal menghapus notifikasi: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ Delete notification error: $e');
    return {
      'success': false,
      'message': 'Error menghapus notifikasi: $e'
    };
  }
}

// ✅ METHOD UNTUK HAPUS SEMUA NOTIFIKASI
Future<Map<String, dynamic>> deleteAllNotifications() async {
  try {
    print('🗑️ Deleting all notifications...');
    
    final headers = await getProtectedHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/transaction/getInboxDeletedAll'),
      headers: headers,
      body: '',
    ).timeout(const Duration(seconds: 30));

    print('📡 Delete All Notifications Response Status: ${response.statusCode}');
    print('📡 Delete All Notifications Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? 'Semua notifikasi berhasil dihapus',
        'data': data
      };
    } else {
      return {
        'success': false,
        'message': 'Gagal menghapus semua notifikasi: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ Delete all notifications error: $e');
    return {
      'success': false,
      'message': 'Error menghapus semua notifikasi: $e'
    };
  }
}

  // ✅ CHANGE PASSWORD
// ✅ FIX: CHANGE PASSWORD - PROPER ERROR HANDLING
Future<Map<String, dynamic>> changePassword(String oldPass, String newPass, String newPassConf) async {
  try {
    final headers = await getProtectedHeaders();
    
    print('🔐 Changing password...');
    
    final response = await http.post(
      Uri.parse('$baseUrl/users/changePass'),
      headers: headers,
      body: 'old_pass=${Uri.encodeComponent(oldPass)}&new_pass=${Uri.encodeComponent(newPass)}&new_pass_conf=${Uri.encodeComponent(newPassConf)}',
    ).timeout(const Duration(seconds: 30));

    print('📡 ChangePass Response Status: ${response.statusCode}');
    print('📡 ChangePass Response Body: ${response.body}');

    // ✅ PARSE RESPONSE TERLEPAS DARI STATUS CODE
    final data = jsonDecode(response.body);
    
    if (response.statusCode == 200) {
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? (data['status'] == true ? 'Password berhasil diubah' : 'Gagal mengubah password'),
        'data': data
      };
    } else {
      // ✅ FIX: GUNAKAN PESAN ERROR DARI API, BUKAN STATUS CODE
      return {
        'success': false,
        'message': data['message'] ?? 'Terjadi kesalahan', // ← INI YANG PERLU DIFIX
        'status': response.statusCode,
        'data': data
      };
    }
  } catch (e) {
    print('❌ Change password error: $e');
    return {
      'success': false,
      'message': 'Error: $e'
    };
  }
}

// ✅ FIX: CHECK USER EXIST YANG SESUAI DENGAN RESPONSE
Future<Map<String, dynamic>> checkUserExist(String username, String email) async {
  try {
    final headers = getAuthHeaders();
    
    print('🔍 Checking user exist: username=$username, email=$email');
    
    final response = await http.post(
      Uri.parse('$baseUrl/users/checkUserExist'),
      headers: headers,
      body: 'username=${Uri.encodeComponent(username)}&email=${Uri.encodeComponent(email)}',
    ).timeout(const Duration(seconds: 30));

    print('📡 CheckUserExist Response Status: ${response.statusCode}');
    print('📡 CheckUserExist Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // ✅ SESUAI RESPONSE AKTUAL: {"status": true, "is_exist": 1, "message": "..."}
      final isExist = data['is_exist'] == 1;
      
      return {
        'exists': isExist,
        'message': data['message'] ?? (isExist ? 'User sudah ada' : 'User tersedia'),
        'status': data['status'] ?? false
      };
    } else {
      return {
        'exists': false,
        'message': 'Tidak dapat memeriksa user: ${response.statusCode}',
        'status': false
      };
    }
  } catch (e) {
    return {
      'exists': false,
      'message': 'Error: $e',
      'status': false
    };
  }
}

// ✅ UPDATE DEVICE TOKEN KE SERVER
Future<Map<String, dynamic>> updateDeviceToken(String token) async {
  try {
    final headers = await getProtectedHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/users/updateDeviceToken'),
      headers: headers,
      body: 'device_token=$token&device_type=${Platform.isAndroid ? 'android' : 'ios'}',
    ).timeout(const Duration(seconds: 30));

    print('📡 Update Device Token Response: ${response.statusCode}');
    print('📡 Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? 'Token updated successfully'
      };
    } else {
      return {
        'success': false,
        'message': 'Failed to update token: ${response.statusCode}'
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Error updating token: $e'
    };
  }
}

// ✅ MARK NOTIFICATION AS READ
Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
  try {
    print('📖 Marking notification as read: $notificationId');
    
    final headers = await getProtectedHeaders();
    
    final response = await http.post(
      Uri.parse('$baseUrl/transaction/getInboxRead'),
      headers: headers,
      body: 'id_inbox=$notificationId',
    ).timeout(const Duration(seconds: 30));

    print('📡 Mark as Read Response Status: ${response.statusCode}');
    print('📡 Mark as Read Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? 'Notifikasi ditandai sebagai dibaca',
        'data': data
      };
    } else {
      return {
        'success': false,
        'message': 'Gagal menandai notifikasi sebagai dibaca: ${response.statusCode}'
      };
    }
  } catch (e) {
    print('❌ Mark as read error: $e');
    return {
      'success': false,
      'message': 'Error menandai notifikasi sebagai dibaca: $e'
    };
  }
}

// ✅ METHOD UNTUK GET UNREAD COUNT YANG LEBIH AKURAT
Future<int> getUnreadNotificationCount() async {
  try {
    print('📊 Getting unread notification count...');
    
    final inboxResult = await getAllInbox();
    
    if (inboxResult['success'] == true) {
      final data = inboxResult['data'] ?? {};
      
      // ✅ CEK BERBAGAI FORMAT RESPONSE YANG MUNGKIN
      int unreadCount = 0;
      
      // Format 1: Data langsung berisi list inbox
      if (data is List) {
        unreadCount = data.where((item) {
          if (item is Map) {
            final readStatus = item['read_status'] ?? item['is_read'] ?? item['status_baca'] ?? '0';
            return readStatus == '0' || readStatus == 0 || readStatus == false;
          }
          return false;
        }).length;
      }
      // Format 2: Data dalam key 'inbox'
      else if (data['inbox'] is List) {
        final inboxList = data['inbox'] as List;
        unreadCount = inboxList.where((item) {
          if (item is Map) {
            final readStatus = item['read_status'] ?? item['is_read'] ?? item['status_baca'] ?? '0';
            return readStatus == '0' || readStatus == 0 || readStatus == false;
          }
          return false;
        }).length;
      }
      // Format 3: Data dalam key 'belum_terbaca' (langsung ada count-nya)
      else if (data['belum_terbaca'] != null) {
        unreadCount = _safeConvertToInt(data['belum_terbaca']);
      }
      
      print('✅ Unread notification count: $unreadCount');
      return unreadCount;
    }
    
    return 0;
  } catch (e) {
    print('❌ Get unread count error: $e');
    return 0;
  }
}

// ✅ FIX: UPDATE USER PROFILE DENGAN ENDPOINT YANG BENAR
Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> profileData) async {
  try {
    final headers = await getProtectedHeaders();
    
    print('🔄 Updating user profile...');
    print('📤 Profile data to update: $profileData');
    
    // ✅ BUAT FORM DATA YANG LEBIH SEDERHANA (HANYA FIELD YANG DIPERLUKAN)
    final simplifiedData = {
      'username': profileData['username'],
      'fullname': profileData['fullname'] ?? profileData['nama'],
      'email': profileData['email'],
      'telp': profileData['telp'] ?? profileData['phone'],
      'job': profileData['job'] ?? profileData['pekerjaan'],
      'birth_place': profileData['birth_place'] ?? profileData['tempat_lahir'],
      'agama_id': profileData['agama_id'],
      'ktp_alamat': profileData['ktp_alamat'] ?? profileData['alamat'],
      'ktp_rt': profileData['ktp_rt'] ?? profileData['rt'],
      'ktp_rw': profileData['ktp_rw'] ?? profileData['rw'],
      'ktp_no': profileData['ktp_no'] ?? profileData['no_rumah'],
      'ktp_postal': profileData['ktp_postal'] ?? profileData['kode_pos'],
      'ktp_id_province': profileData['ktp_id_province'] ?? profileData['id_province'],
      'ktp_id_regency': profileData['ktp_id_regency'] ?? profileData['id_regency'],
      'domisili_alamat': profileData['domisili_alamat'],
      'domisili_rt': profileData['domisili_rt'],
      'domisili_rw': profileData['domisili_rw'],
      'domisili_no': profileData['domisili_no'],
      'domisili_postal': profileData['domisili_postal'],
      'domisili_id_province': profileData['domisili_id_province'],
      'domisili_id_regency': profileData['domisili_id_regency'],
    };
    
    // ✅ HAPUS NULL VALUES
    simplifiedData.removeWhere((key, value) => value == null);
    
    final body = simplifiedData.entries
        .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}')
        .join('&');
    
    print('📤 Simplified request body: $body');
    
    // ✅ COBA BERBAGAI ENDPOINT YANG MUNGKIN
    final possibleEndpoints = [
      '$baseUrl/users/updateProfile',
      '$baseUrl/users/update',
      '$baseUrl/users/setProfile',
      '$baseUrl/profile/update',
    ];
    
    for (var endpoint in possibleEndpoints) {
      try {
        print('🔄 Trying endpoint: $endpoint');
        
        final response = await http.post(
          Uri.parse(endpoint),
          headers: headers,
          body: body,
        ).timeout(const Duration(seconds: 30));

        print('📡 Update Profile Response Status: ${response.statusCode}');
        print('📡 Update Profile Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['status'] == true) {
            print('✅ Profile updated successfully via: $endpoint');
            
            // ✅ UPDATE LOCAL STORAGE
            final prefs = await SharedPreferences.getInstance();
            final currentUser = await getCurrentUser();
            if (currentUser != null) {
              final updatedUser = {...currentUser, ...simplifiedData};
              await prefs.setString('user', jsonEncode(updatedUser));
            }
            
            return {
              'success': true,
              'message': data['message'] ?? 'Profile berhasil diupdate',
              'data': data['data'] ?? data,
              'endpoint': endpoint,
            };
          }
        }
      } catch (e) {
        print('❌ Endpoint $endpoint failed: $e');
        continue;
      }
    }
    
    // ✅ JIKA SEMUA ENDPOINT GAGAL, COBA GUNAKAN ENDPOINT CHANGE PASS YANG BEKERJA
    print('🔄 Fallback: Using changePass endpoint for profile update...');
    final changePassResponse = await http.post(
      Uri.parse('$baseUrl/users/changePass'),
      headers: headers,
      body: body + '&update_profile=true',
    ).timeout(const Duration(seconds: 30));

    if (changePassResponse.statusCode == 200) {
      final data = jsonDecode(changePassResponse.body);
      return {
        'success': data['status'] == true,
        'message': data['message'] ?? 'Profile updated via changePass endpoint',
        'data': data,
        'endpoint': 'changePass_fallback',
      };
    }
    
    return {
      'success': false,
      'message': 'Semua endpoint update profile gagal',
      'http_status': 405,
    };
    
  } catch (e) {
    print('❌ Update profile API error: $e');
    return {
      'success': false,
      'message': 'Error: $e',
      'http_status': 0,
    };
  }
}

  // ✅ METHOD UNTUK DEBUG USER DATA
Future<void> debugUserData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    print('🐛 === USER DATA DEBUG ===');
    
    // Cek semua key yang ada
    final keys = prefs.getKeys();
    print('📦 All storage keys: $keys');
    
    // Cek user data
    final userString = prefs.getString('user');
    final loginUserString = prefs.getString('login_user');
    final token = prefs.getString('token');
    
    print('👤 User Data: ${userString != null ? "✅" : "❌"}');
    print('🔐 Login Data: ${loginUserString != null ? "✅" : "❌"}');
    print('🎫 Token: ${token != null ? "✅" : "❌"}');
    
    if (userString != null) {
      final userData = jsonDecode(userString);
      print('📄 User Data Content:');
      print('   - Keys: ${userData.keys}');
      print('   - user_id: ${userData['user_id']}');
      print('   - user_key: ${userData['user_key']}');
      print('   - username: ${userData['username']}');
    }
    
    if (loginUserString != null) {
      final loginData = jsonDecode(loginUserString);
      print('📄 Login Data Content:');
      print('   - Keys: ${loginData.keys}');
      if (loginData['user'] != null) {
        print('   - user.user_id: ${loginData['user']['user_id']}');
        print('   - user.user_key: ${loginData['user']['user_key']}');
      }
    }
    
    print('🐛 === DEBUG END ===');
  } catch (e) {
    print('❌ Debug error: $e');
  }
}

  // ✅ CHECK LOGIN STATUS
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final user = prefs.getString('user');
      return token != null && token.isNotEmpty && user != null && user.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ✅ VALIDATE TOKEN
  Future<bool> validateToken() async {
    try {
      final headers = await getProtectedHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/users/validateToken'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ✅ HELPER METHODS UNTUK NORMALISASI DATA SALDO
  Map<String, dynamic> _normalizeSaldoData(Map<String, dynamic> rawData) {
    final normalized = <String, dynamic>{};
    
    print('🔧 Normalizing saldo data from: ${rawData.keys}');
    
    for (var key in ['pokok', 'wajib', 'sukarela', 'sitabung', 'sita', 'siumna', 'simuna', 'siquna', 'taqsith']) {
      if (rawData.containsKey(key)) {
        final value = rawData[key];
        
        if (value is List && value.isNotEmpty) {
          final firstItem = value[0];
          if (firstItem is Map && firstItem.containsKey('saldo')) {
            normalized[key] = firstItem['saldo'];
            print('✅ Normalized $key from array: ${firstItem['saldo']}');
          } else {
            normalized[key] = 0;
          }
        } 
        else if (value is Map && value.containsKey('saldo')) {
          normalized[key] = value['saldo'];
          print('✅ Normalized $key from map: ${value['saldo']}');
        }
        else if (value is num) {
          normalized[key] = value;
          print('✅ Normalized $key from direct value: $value');
        }
        else {
          normalized[key] = 0;
          print('⚠️ Could not normalize $key, setting to 0');
        }
      } else {
        normalized[key] = 0;
      }
    }
    
    if (rawData.containsKey('saldo')) {
      normalized['saldo'] = _parseSaldoValue(rawData['saldo']);
    } else {
      final total = (normalized['pokok'] ?? 0) + 
                   (normalized['wajib'] ?? 0) + 
                   (normalized['sukarela'] ?? 0) + 
                   (normalized['sitabung'] ?? normalized['sita'] ?? 0) + 
                   (normalized['siumna'] ?? normalized['simuna'] ?? 0) + 
                   (normalized['siquna'] ?? normalized['taqsith'] ?? 0);
      normalized['saldo'] = total;
    }
    
    print('📊 Normalized saldo data: $normalized');
    return normalized;
  }

  // ✅ IMPROVED: SAFE CONVERSION METHODS
int _safeConvertToInt(dynamic value) {
  try {
    if (value == null) return 0;
    
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      // Handle string dengan decimal
      if (value.contains('.')) {
        return double.tryParse(value)?.toInt() ?? 0;
      }
      return int.tryParse(value) ?? 0;
    }
    
    return 0;
  } catch (e) {
    print('❌ Error converting $value to int: $e');
    return 0;
  }
}

double _safeConvertToDouble(dynamic value) {
  try {
    if (value == null) return 0.0;
    
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    
    return 0.0;
  } catch (e) {
    print('❌ Error converting $value to double: $e');
    return 0.0;
  }
}

String _safeConvertToString(dynamic value) {
  try {
    if (value == null) return '';
    return value.toString();
  } catch (e) {
    return '';
  }
}

  dynamic _parseSaldoValue(dynamic value) {
    if (value == null) return 0;
    
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    if (value is Map && value.containsKey('saldo')) {
      return _parseSaldoValue(value['saldo']);
    }
    if (value is List && value.isNotEmpty) {
      return _parseSaldoValue(value[0]);
    }
    
    return 0;
  }
}