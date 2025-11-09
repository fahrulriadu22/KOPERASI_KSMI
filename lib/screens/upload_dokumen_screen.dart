import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/temporary_storage_service.dart';
import 'dashboard_main.dart';
import 'profile_screen.dart';

class UploadDokumenScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onDocumentsComplete;

  const UploadDokumenScreen({
    super.key, 
    required this.user,
    this.onDocumentsComplete,
  });

  @override
  State<UploadDokumenScreen> createState() => _UploadDokumenScreenState();
}

class _UploadDokumenScreenState extends State<UploadDokumenScreen> {
  final TemporaryStorageService _storageService = TemporaryStorageService();
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _uploadError;
  Map<String, dynamic> _currentUser = {};
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _initializeData();
  }

  @override
  void dispose() {
    _isNavigating = true;
    super.dispose();
  }

  // ✅ INITIALIZE DATA DENGAN CEK STATUS DOKUMEN DARI SERVER
  Future<void> _initializeData() async {
    try {
      setState(() => _isInitializing = true);
      
      // ✅ CEK STATUS DOKUMEN DARI SERVER
      final profileResult = await _apiService.getUserProfile();
      if (profileResult['success'] == true && profileResult['data'] != null) {
        setState(() {
          _currentUser = profileResult['data'];
        });
        print('✅ User profile loaded from API for document status check');
        
        // ✅ DEBUG: CEK STATUS DOKUMEN DI SERVER
        _debugServerDocumentStatus();
      }
      
      // ✅ INITIALIZE TEMPORARY STORAGE
      await _storageService.loadFilesFromStorage();
      print('✅ TemporaryStorageService initialized');
      _storageService.printDebugInfo();
      
    } catch (e) {
      print('❌ Error initializing data: $e');
      // ✅ FALLBACK: GUNAKAN DATA LOKAL
      await _storageService.loadFilesFromStorage();
    } finally {
      if (mounted && !_isNavigating) {
        setState(() => _isInitializing = false);
      }
    }
  }

  // ✅ FIX: DEBUG SERVER DOCUMENT STATUS
  void _debugServerDocumentStatus() {
    print('🐛 === SERVER DOCUMENT STATUS ===');
    print('📄 KTP Server: ${_currentUser['foto_ktp'] ?? 'NULL'}');
    print('📄 KK Server: ${_currentUser['foto_kk'] ?? 'NULL'}');
    print('📄 Foto Diri Server: ${_currentUser['foto_diri'] ?? 'NULL'}');
    
    final ktpUploaded = _isDocumentUploadedToServer('ktp');
    final kkUploaded = _isDocumentUploadedToServer('kk');
    final diriUploaded = _isDocumentUploadedToServer('diri');
    
    print('✅ KTP Uploaded to Server: $ktpUploaded');
    print('✅ KK Uploaded to Server: $kkUploaded');
    print('✅ Foto Diri Uploaded to Server: $diriUploaded');
    print('🐛 === DEBUG END ===');
  }

  // ✅ PERBAIKAN: VALIDASI SEBELUM UPLOAD DENGAN SAFE CHECK
  bool _validateBeforeUpload() {
    // ✅ CEK FILE LOKAL
    if (!_storageService.isAllFilesComplete) {
      _showSafeSnackBar('Harap lengkapi semua 3 dokumen terlebih dahulu', isError: true);
      return false;
    }

    // ✅ CEK APAKAH SUDAH DI SERVER
    final ktpServer = _isDocumentUploadedToServer('ktp');
    final kkServer = _isDocumentUploadedToServer('kk');
    final diriServer = _isDocumentUploadedToServer('diri');
    
    if (ktpServer && kkServer && diriServer) {
      _showSafeSnackBar('Semua dokumen sudah terupload ke server');
      return false;
    }

    // ✅ CEK FILE SIZE
    final ktpSize = _storageService.ktpFile?.lengthSync() ?? 0;
    final kkSize = _storageService.kkFile?.lengthSync() ?? 0;
    final diriSize = _storageService.diriFile?.lengthSync() ?? 0;

    if (ktpSize > 5 * 1024 * 1024 || kkSize > 5 * 1024 * 1024 || diriSize > 5 * 1024 * 1024) {
      _showSafeSnackBar('Ukuran file terlalu besar. Maksimal 5MB per file', isError: true);
      return false;
    }

    return true;
  }

  // ✅ FIX: CEK STATUS DOKUMEN YANG LEBIH KETAT DAN AKURAT
  bool _isDocumentUploadedToServer(String type) {
    String? documentUrl;
    
    switch (type) {
      case 'ktp':
        documentUrl = _currentUser['foto_ktp'];
        break;
      case 'kk':
        documentUrl = _currentUser['foto_kk'];
        break;
      case 'diri':
        documentUrl = _currentUser['foto_diri'];
        break;
      case 'bukti':
        documentUrl = _currentUser['foto_bukti'];
        break;
    }
    
    // ✅ FIX: VALIDASI YANG LEBIH KETAT
    if (documentUrl == null || 
        documentUrl.toString().isEmpty || 
        documentUrl == 'null' ||
        documentUrl == 'uploaded' ||
        documentUrl.trim().isEmpty) {
      return false;
    }
    
    final urlString = documentUrl.toString().trim();
    
    // ✅ FIX: HANYA RETURN TRUE JIKA BENAR-BENAR ADA FILENAME DENGAN EXTENSION
    final isUploaded = 
        (urlString.toLowerCase().contains('.jpg') || 
         urlString.toLowerCase().contains('.jpeg') || 
         urlString.toLowerCase().contains('.png')) &&
        urlString.length > 5 && // Pastikan bukan string pendek
        !urlString.toLowerCase().contains('null') &&
        !urlString.toLowerCase().contains('uploaded'); // Pastikan bukan status string
    
    print('🔍 Document $type: "$urlString" → Uploaded: $isUploaded');
    return isUploaded;
  }

  // ✅ PERBAIKAN: UPLOAD DOKUMEN DENGAN SAFE CHECK
  Future<void> _uploadDocument(String type, String documentName) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (mounted) {
          setState(() {
            _uploadError = null;
          });
        }

        final file = File(pickedFile.path);
        print('📤 Uploading $documentName: ${file.path}');
        
        // ✅ VALIDASI FILE - HANYA JPG/JPEG
        if (!await file.exists()) {
          throw Exception('File tidak ditemukan');
        }

        final fileSize = file.lengthSync();
        if (fileSize > 5 * 1024 * 1024) {
          throw Exception('Ukuran file terlalu besar. Maksimal 5MB.');
        }

        final fileExtension = pickedFile.path.toLowerCase().split('.').last;
        if (!['jpg', 'jpeg'].contains(fileExtension)) {
          throw Exception('Format file tidak didukung. Gunakan JPG atau JPEG saja.');
        }

        // ✅ SIMPAN FILE KE TEMPORARY STORAGE
        switch (type) {
          case 'ktp':
            await _storageService.setKtpFile(file);
            break;
          case 'kk':
            await _storageService.setKkFile(file);
            break;
          case 'diri':
            await _storageService.setDiriFile(file);
            break;
        }

        if (mounted) {
          setState(() {});
        }

        // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
        _showSafeSnackBar('$documentName berhasil disimpan ✅');

        print('💾 $documentName saved to temporary storage');
        
        // ✅ CHECK AUTO UPLOAD SETELAH SIMPAN FILE
        _checkAutoUpload();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadError = 'Error upload $documentName: $e';
        });
      }

      print('❌ Upload failed: $e');
      
      // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
      _showSafeSnackBar('Gagal upload $documentName: $e', isError: true);
    }
  }

  // ✅ PERBAIKAN: TAKE PHOTO DENGAN SAFE CHECK
  Future<void> _takePhoto(String type, String documentName) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (mounted && !_isNavigating) {
          setState(() {
            _uploadError = null;
          });
        }

        final file = File(pickedFile.path);
        print('📸 Taking photo for $documentName: ${file.path}');
        
        // ✅ VALIDASI FILE - HANYA JPG/JPEG
        if (!await file.exists()) {
          throw Exception('File tidak ditemukan');
        }

        final fileSize = file.lengthSync();
        if (fileSize > 5 * 1024 * 1024) {
          throw Exception('Ukuran file terlalu besar. Maksimal 5MB.');
        }

        // ✅ SIMPAN FILE KE TEMPORARY STORAGE
        switch (type) {
          case 'ktp':
            await _storageService.setKtpFile(file);
            break;
          case 'kk':
            await _storageService.setKkFile(file);
            break;
          case 'diri':
            await _storageService.setDiriFile(file);
            break;
        }

        if (mounted && !_isNavigating) {
          setState(() {});
        }

        // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
        _showSafeSnackBar('$documentName berhasil diambil ✅');

        print('💾 $documentName from camera saved to temporary storage');
        
        // ✅ CHECK AUTO UPLOAD SETELAH SIMPAN FILE
        _checkAutoUpload();
      }
    } catch (e) {
      if (mounted && !_isNavigating) {
        setState(() {
          _uploadError = 'Error mengambil foto $documentName: $e';
        });
      }

      print('❌ Camera failed: $e');
      
      // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
      _showSafeSnackBar('Gagal mengambil foto $documentName: $e', isError: true);
    }
  }

  // ✅ CHECK AUTO UPLOAD JIKA SEMUA FILE LENGKAP
  void _checkAutoUpload() {
    print('🔄 _checkAutoUpload called');
    print('   - isAllFilesComplete: ${_storageService.isAllFilesComplete}');
    print('   - isUploading: ${_storageService.isUploading}');
    print('   - hasKtpFile: ${_storageService.hasKtpFile}');
    print('   - hasKkFile: ${_storageService.hasKkFile}');
    print('   - hasDiriFile: ${_storageService.hasDiriFile}');
    
    // ✅ CEK APAKAH SUDAH ADA DI SERVER
    final ktpServer = _isDocumentUploadedToServer('ktp');
    final kkServer = _isDocumentUploadedToServer('kk');
    final diriServer = _isDocumentUploadedToServer('diri');
    
    print('   - KTP Server: $ktpServer');
    print('   - KK Server: $kkServer');
    print('   - Diri Server: $diriServer');
    
    // ✅ JIKA SEMUA FILE LENGKAP DAN BELUM DIUPLOAD KE SERVER
    if (_storageService.isAllFilesComplete && 
        !_storageService.isUploading &&
        (!ktpServer || !kkServer || !diriServer)) {
      print('🚀 All files complete, showing upload confirmation...');
      _showUploadConfirmationDialog();
    } else {
      print('⏳ Not ready for auto-upload yet');
    }
  }

  // ✅ UPLOAD KTP
  Future<void> _uploadKTP() async {
    await _uploadDocument('ktp', 'KTP');
  }

  // ✅ UPLOAD KK
  Future<void> _uploadKK() async {
    await _uploadDocument('kk', 'Kartu Keluarga');
  }

  // ✅ UPLOAD FOTO DIRI
  Future<void> _uploadFotoDiri() async {
    await _uploadDocument('diri', 'Foto Diri');
  }

  // ✅ UPLOAD KTP DARI KAMERA
  Future<void> _takePhotoKTP() async {
    await _takePhoto('ktp', 'KTP');
  }

  // ✅ UPLOAD KK DARI KAMERA
  Future<void> _takePhotoKK() async {
    await _takePhoto('kk', 'Kartu Keluarga');
  }

  // ✅ UPLOAD FOTO DIRI DARI KAMERA
  Future<void> _takePhotoFotoDiri() async {
    await _takePhoto('diri', 'Foto Diri');
  }

  // ✅ PERBAIKAN: CLEAR FILE DENGAN SAFE CHECK
  Future<void> _clearFile(String type, String documentName) async {
    await _storageService.clearFile(type);
    if (mounted) {
      setState(() {});
    }
    
    // ✅ PERBAIKAN: GUNAKAN SAFE SNACKBAR
    _showSafeSnackBar('$documentName dihapus');
  }

  // ✅ PERBAIKAN: MANUAL UPLOAD ALL FILES DENGAN SAFE CHECK
  Future<void> _uploadAllFiles() async {
    // ✅ VALIDASI SEBELUM UPLOAD
    if (!_validateBeforeUpload()) {
      return;
    }

    if (_storageService.isUploading) {
      _showSafeSnackBar('Upload sedang berjalan, harap tunggu...', isError: false);
      return;
    }

    _showUploadConfirmationDialog();
  }

  // ✅ PERBAIKAN: DIALOG KONFIRMASI UPLOAD DENGAN STATUS VERIFIKASI
  void _showUploadConfirmationDialog() {
    // ✅ HITUNG FILE YANG AKAN DIUPLOAD
    final filesToUpload = [
      !_isDocumentUploadedToServer('ktp') && _storageService.hasKtpFile,
      !_isDocumentUploadedToServer('kk') && _storageService.hasKkFile,
      !_isDocumentUploadedToServer('diri') && _storageService.hasDiriFile,
    ].where((e) => e).length;

    // ✅ PERBAIKAN: GUNAKAN SAFE DIALOG
    if (!mounted || _isNavigating) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Upload 4 File ke Server?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sistem akan mengupload $filesToUpload file asli + 1 file duplikat foto diri:\n\n'
              '${!_isDocumentUploadedToServer('ktp') && _storageService.hasKtpFile ? '• KTP (ASLI)\n' : ''}'
              '${!_isDocumentUploadedToServer('kk') && _storageService.hasKkFile ? '• Kartu Keluarga (ASLI)\n' : ''}'
              '${!_isDocumentUploadedToServer('diri') && _storageService.hasDiriFile ? '• Foto Diri (ASLI)\n' : ''}'
              '• Foto Bukti (DUPLIKAT DARI FOTO DIRI)\n\n'
              'Total: ${filesToUpload + 1} file akan dikirim ke server.',
            ),
            const SizedBox(height: 16),
            _buildVerificationStatusInfo(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Periksa Lagi'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startUploadProcess();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Ya, Upload Sekarang'),
          ),
        ],
      ),
    );
  }

  // ✅ PERBAIKAN: SAFE SNACKBAR DENGAN MOUNTED CHECK
  void _showSafeSnackBar(String message, {bool isError = false, int duration = 3}) {
    if (!mounted) {
      print('⚠️ Widget not mounted, skipping snackbar: $message');
      return;
    }
    
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: duration),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('❌ Error showing snackbar (safe): $e');
    }
  }

  // ✅ PERBAIKAN: PROSES UPLOAD DENGAN STATUS VERIFIKASI & SAFE CHECK
  Future<void> _startUploadProcess() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    print('🚀 Starting upload process with 3 REAL + FOTO_DIRI AS BUKTI...');
    
    try {
      // ✅ VALIDASI FILE LOKAL
      if (!_storageService.isAllFilesComplete) {
        throw Exception('Semua file belum lengkap. KTP, KK, dan Foto Diri harus diisi.');
      }

      // ✅ DAPATKAN PATH FILE LOKAL
      final ktpPath = _storageService.ktpFile?.path;
      final kkPath = _storageService.kkFile?.path;
      final diriPath = _storageService.diriFile?.path;

      if (ktpPath == null || kkPath == null || diriPath == null) {
        throw Exception('Path file tidak valid. Silakan pilih ulang file.');
      }

      print('📁 File paths for upload:');
      print('   - KTP: $ktpPath');
      print('   - KK: $kkPath');
      print('   - Foto Diri: $diriPath');
      print('   - Foto Bukti: $diriPath (SAMA DENGAN FOTO DIRI)');

      // ✅ UPLOAD KE SERVER
      final result = await _apiService.uploadThreeRealPhotos(
        fotoKtpPath: ktpPath,
        fotoKkPath: kkPath,
        fotoDiriPath: diriPath,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (result['success'] == true) {
        // ✅ PERBAIKAN: TAMPILKAN STATUS VERIFIKASI BUKAN AUTO VERIFIED
        _showSafeSnackBar(
          '✅ Upload berhasil! Status: Menunggu Verifikasi Admin\nDokumen akan diverifikasi dalam 1x24 jam',
          duration: 5
        );

        // ✅ CLEAR TEMPORARY STORAGE SETELAH UPLOAD BERHASIL
        await _storageService.clearAllFiles();
        
        // ✅ REFRESH USER DATA SETELAH UPLOAD BERHASIL
        print('🔄 Refreshing user data after successful upload...');
        await _refreshUserData();

        // ✅ TAMPILKAN DIALOG VERIFIKASI SEBELUM KE DASHBOARD
        _showVerificationDialog();
      } else {
        _showSafeSnackBar(result['message'] ?? 'Upload gagal', isError: true);
      }
    } catch (e) {
      print('❌ Upload process error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      _showSafeSnackBar('Error upload: $e', isError: true);
    }
  }

  // ✅ FIX: REFRESH USER DATA SETELAH UPLOAD
  Future<void> _refreshUserData() async {
    try {
      print('🔄 Refreshing user data from server...');
      
      final profileResult = await _apiService.getUserProfile();
      if (profileResult['success'] == true && profileResult['data'] != null) {
        final newUserData = profileResult['data'];
        
        if (mounted && !_isNavigating) {
          setState(() {
            _currentUser = newUserData;
          });
        }
        
        print('✅ User data refreshed after upload');
        
        // ✅ DEBUG STATUS TERBARU
        print('🐛 === AFTER UPLOAD STATUS ===');
        print('📄 KTP: ${newUserData['foto_ktp']}');
        print('📄 KK: ${newUserData['foto_kk']}');
        print('📄 Foto Diri: ${newUserData['foto_diri']}');
        
        final ktpUploaded = _isDocumentUploadedToServer('ktp');
        final kkUploaded = _isDocumentUploadedToServer('kk');
        final diriUploaded = _isDocumentUploadedToServer('diri');
        
        print('✅ KTP Uploaded: $ktpUploaded');
        print('✅ KK Uploaded: $kkUploaded');
        print('✅ Foto Diri Uploaded: $diriUploaded');
        print('🎯 All documents uploaded: ${ktpUploaded && kkUploaded && diriUploaded}');
        print('🐛 === DEBUG END ===');
        
      } else {
        print('❌ Failed to refresh user data: ${profileResult['message']}');
      }
    } catch (e) {
      print('❌ Error refreshing user data: $e');
    }
  }

  // ✅ FITUR LEWATI - Skip upload dan langsung ke dashboard
  void _lewatiUpload() {
    // ✅ CEK APAKAH SUDAH ADA DOKUMEN DI SERVER
    final ktpServer = _isDocumentUploadedToServer('ktp');
    final kkServer = _isDocumentUploadedToServer('kk');
    final diriServer = _isDocumentUploadedToServer('diri');
    
    final hasSomeServerDocuments = ktpServer || kkServer || diriServer;
    final hasSomeLocalFiles = _storageService.hasAnyFile;

    String message;
    if (hasSomeServerDocuments) {
      message = 'Beberapa dokumen sudah terupload ke server. '
          'Dokumen yang belum terupload dapat diupload nanti di menu Profile. '
          'Apakah Anda yakin ingin melanjutkan ke dashboard?';
    } else if (hasSomeLocalFiles) {
      message = 'Anda memiliki dokumen yang belum diupload. '
          'Dokumen akan disimpan sementara dan dapat diupload nanti di menu Profile. '
          'Apakah Anda yakin ingin melanjutkan ke dashboard?';
    } else {
      message = 'Anda dapat mengupload dokumen nanti di menu Profile. '
          'Apakah Anda yakin ingin melanjutkan ke dashboard?';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lewati Upload Dokumen?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Lanjut Upload'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToDashboard();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Ya, Lewati'),
          ),
        ],
      ),
    );
  }

  // Di upload_dokumen_screen.dart - tambahkan method baru
void _proceedBasedOnUserStatus() {
  final userStatus = _currentUser['status_user'] ?? 0;
  
  print('🎯 Proceeding based on user status: $userStatus');
  
  if (userStatus == 0) {
    // ✅ STATUS 0: KEMBALI KE PROFILE SCREEN
    _proceedToProfileOnly();
  } else {
    // ✅ STATUS 1: KE DASHBOARD
    _proceedToDashboard();
  }
}

  // ✅ PERBAIKAN: NAVIGATION KE DASHBOARD DENGAN SAFE CHECK
  void _proceedToDashboard() {
    print('🚀 Starting proceed to dashboard...');
    
    if (_isNavigating) {
      print('⚠️ Already navigating, skipping...');
      return;
    }
    
    _isNavigating = true;

    // ✅ GUNAKAN Future.microtask UNTUK MEMASTIKAN BUILD SELESAI
    Future.microtask(() {
      if (!mounted) {
        print('🔄 Widget not mounted, skipping navigation');
        return;
      }

      final updatedUser = Map<String, dynamic>.from(_currentUser);

      print('🎯 Final navigation check:');
      print('   - KTP Server: ${_isDocumentUploadedToServer('ktp')}');
      print('   - KK Server: ${_isDocumentUploadedToServer('kk')}');
      print('   - Foto Diri Server: ${_isDocumentUploadedToServer('diri')}');

      try {
        if (widget.onDocumentsComplete != null) {
          print('📞 Memanggil callback onDocumentsComplete...');
          widget.onDocumentsComplete!();
        } else {
          print('🔄 Navigasi langsung ke Dashboard...');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => DashboardMain(user: updatedUser)),
            (route) => false,
          );
          print('✅ Navigation to dashboard successful');
        }
      } catch (e) {
        print('❌ Navigation error: $e');
        // FALLBACK: Coba navigasi sederhana
        if (mounted) {
          try {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => DashboardMain(user: _currentUser)),
              (route) => false,
            );
          } catch (e2) {
            print('❌ Fallback navigation also failed: $e2');
          }
        }
      }
    });
  }

// ✅ UPDATE: SHOW VERIFICATION DIALOG
void _showVerificationDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.verified_user, color: Colors.green),
          SizedBox(width: 8),
          Text('Upload Berhasil'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dokumen Anda telah berhasil diupload ke server dan sedang menunggu verifikasi admin.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text(
              '🔒 Status: Menunggu Verifikasi\n'
              'Saat ini Anda hanya dapat mengakses menu profile. '
              'Setelah diverifikasi, Anda akan mendapatkan akses penuh.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _proceedBasedOnUserStatus(); // ✅ GUNAKAN METHOD BARU
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Lanjut ke Profile'),
        ),
      ],
    ),
  );
}

// ✅ METHOD BARU: KE PROFILE SAJA (UNTUK STATUS 0)
void _proceedToProfileOnly() {
  print('🚀 Navigating to ProfileScreen (status 0 restriction)');
  
  if (_isNavigating) return;
  _isNavigating = true;

  final updatedUser = Map<String, dynamic>.from(_currentUser);
  
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => ProfileScreen(user: updatedUser)),
    (route) => false,
  );
}

  // ✅ SHOW IMAGE SOURCE DIALOG dengan opsi kamera
  void _showImageSourceDialog(String type, String documentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Sumber $documentName'),
        content: Text('Pilih sumber untuk mengambil gambar $documentName'),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    switch (type) {
                      case 'ktp':
                        _takePhotoKTP();
                        break;
                      case 'kk':
                        _takePhotoKK();
                        break;
                      case 'diri':
                        _takePhotoFotoDiri();
                        break;
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    switch (type) {
                      case 'ktp':
                        _uploadKTP();
                        break;
                      case 'kk':
                        _uploadKK();
                        break;
                      case 'diri':
                        _uploadFotoDiri();
                        break;
                    }
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galeri'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ BUILD DOKUMEN CARD dengan status dari TemporaryStorage + Server
  Widget _buildDokumenCard({
    required String type,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final fileInfo = _storageService.getFileInfo(type);
    final hasLocalFile = fileInfo['exists'] == true;
    final isUploading = _storageService.isUploading;
    
    // ✅ CEK STATUS UPLOAD KE SERVER
    final isUploadedToServer = _isDocumentUploadedToServer(type);
    final serverUrl = _getDocumentServerUrl(type);

    print('🎨 Building $type card - Server: $isUploadedToServer, Local: $hasLocalFile');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // ✅ STATUS INDICATOR (PRIORITAS SERVER STATUS)
                  if (isUploadedToServer) ...[
                    Row(
                      children: [
                        Icon(Icons.cloud_done, color: Colors.green, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Terverifikasi di Server',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (serverUrl != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'URL: ${_shortenUrl(serverUrl)}',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ] else if (hasLocalFile) ...[
                    Row(
                      children: [
                        Icon(Icons.pending, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Menunggu Upload',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(fileInfo['size'] / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    if (fileInfo['filename'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        fileInfo['filename'],
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Belum Diupload',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // UPLOAD/GANTI BUTTON
                SizedBox(
                  width: 80,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: isUploading ? null : () => _showImageSourceDialog(type, title),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUploadedToServer ? Colors.green : 
                                    hasLocalFile ? Colors.orange : color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isUploadedToServer ? '✓ Verified' : 
                            hasLocalFile ? 'Upload' : 'Pilih',
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
                ),
                if (hasLocalFile && !isUploadedToServer) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 80,
                    height: 28,
                    child: OutlinedButton(
                      onPressed: isUploading ? null : () => _clearFile(type, title),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Hapus',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ PERBAIKAN: BUILD UPLOAD MANUAL SECTION DENGAN STATUS VERIFIKASI
  Widget _buildUploadManualSection() {
    final allFilesComplete = _storageService.isAllFilesComplete;
    final hasAnyFile = _storageService.hasAnyFile;

    // ✅ CEK APAKAH ADA FILE YANG BELUM TERUPLOAD KE SERVER
    final hasPendingUpload = hasAnyFile && 
        (!_isDocumentUploadedToServer('ktp') || 
         !_isDocumentUploadedToServer('kk') || 
         !_isDocumentUploadedToServer('diri'));

    if (!hasPendingUpload && !allFilesComplete) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              Text(
                allFilesComplete ? 'Siap Upload 4 File!' : 'Upload Manual',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            allFilesComplete 
                ? 'Semua 3 dokumen sudah lengkap. Sistem akan menggunakan foto diri sebagai foto bukti. Total 4 file akan diupload ke server.'
                : 'Upload dokumen yang sudah dipilih atau lengkapi semua dokumen terlebih dahulu.',
            style: TextStyle(fontSize: 12, color: Colors.blue[700]),
          ),
          
          // ✅ TAMBAHKAN INFO VERIFIKASI
          if (allFilesComplete) ...[
            const SizedBox(height: 8),
            _buildVerificationStatusInfo(),
          ],
          
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: _storageService.isUploading ? null : _uploadAllFiles,
              style: ElevatedButton.styleFrom(
                backgroundColor: allFilesComplete ? Colors.green[700] : Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.cloud_upload, size: 20),
              label: _storageService.isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      allFilesComplete ? 'Upload 4 File ke Server' : 'Upload Manual',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ WIDGET BARU: STATUS VERIFIKASI UNTUK USER STATUS 0
  Widget _buildVerificationStatusInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Status: Menunggu Verifikasi Admin\nDokumen akan diverifikasi dalam 1x24 jam',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ WIDGET BARU: VERIFICATION TIMELINE
  Widget _buildVerificationTimeline() {
    final userStatus = _currentUser['status_user'] ?? 0;
    final isVerified = userStatus == 1 || userStatus == '1';
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proses Verifikasi',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildTimelineStep(1, 'Upload Dokumen', true, Icons.cloud_upload),
          _buildTimelineStep(2, 'Review Admin', isVerified, Icons.verified_user),
          _buildTimelineStep(3, 'Aktif', isVerified, Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(int step, String title, bool isCompleted, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(icon, color: Colors.white, size: 16)
                  : Text(
                      '$step',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isCompleted ? Colors.green[800] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          if (isCompleted)
            Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  // ✅ WIDGET BARU: USER STATUS BANNER
  Widget _buildUserStatusBanner() {
    final userStatus = _currentUser['status_user'] ?? 0;
    final isVerified = userStatus == 1 || userStatus == '1';
    
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.green[700], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Akun Terverifikasi',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Selamat! Akun Anda sudah aktif dan dapat menggunakan semua fitur',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange[700], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menunggu Verifikasi Admin',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Dokumen akan diverifikasi dalam 1x24 jam. Anda tetap dapat menggunakan aplikasi',
                    style: TextStyle(
                      color: Colors.orange[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.green[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.green[700],
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat data dokumen...',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allFilesComplete = _storageService.isAllFilesComplete;
    final uploadedCount = [
      _storageService.hasKtpFile,
      _storageService.hasKkFile,
      _storageService.hasDiriFile,
    ].where((e) => e).length;

    // ✅ HITUNG DOKUMEN YANG SUDAH DI SERVER
    final serverUploadedCount = [
      _isDocumentUploadedToServer('ktp'),
      _isDocumentUploadedToServer('kk'),
      _isDocumentUploadedToServer('diri'),
    ].where((e) => e).length;

    final userStatus = _currentUser['status_user'] ?? 0;
    final isVerified = userStatus == 1 || userStatus == '1';

    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text('Upload Dokumen'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (uploadedCount > 0 || serverUploadedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$uploadedCount/3',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (serverUploadedCount > 0)
                      Text(
                        '$serverUploadedCount server',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    isVerified ? Icons.verified_user : Icons.verified_user_outlined, 
                    size: 60, 
                    color: isVerified ? Colors.green : Colors.green[700]
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isVerified ? 'Dokumen Terverifikasi' : 'Lengkapi Dokumen',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isVerified 
                        ? 'Semua dokumen sudah terverifikasi dan aktif'
                        : 'Upload 3 dokumen wajib + foto diri sebagai bukti',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // PROGRESS INDICATOR (3 STEP) - TANPA BUKTI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildProgressStep(1, 'KTP', _isDocumentUploadedToServer('ktp') || _storageService.hasKtpFile),
                      Container(width: 15, height: 2, color: (_isDocumentUploadedToServer('ktp') || _storageService.hasKtpFile) ? Colors.green : Colors.grey[300]),
                      _buildProgressStep(2, 'KK', _isDocumentUploadedToServer('kk') || _storageService.hasKkFile),
                      Container(width: 15, height: 2, color: (_isDocumentUploadedToServer('kk') || _storageService.hasKkFile) ? Colors.green : Colors.grey[300]),
                      _buildProgressStep(3, 'Diri', _isDocumentUploadedToServer('diri') || _storageService.hasDiriFile),
                    ],
                  ),

                  // STATUS INFO
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isVerified ? Icons.verified : Icons.info_outline, 
                        color: isVerified ? Colors.green : Colors.green[700], 
                        size: 16
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified 
                            ? 'Status: Terverifikasi • $serverUploadedCount/3 dokumen'
                            : 'Status: $serverUploadedCount/3 di server • Menunggu verifikasi',
                        style: TextStyle(
                          color: isVerified ? Colors.green : Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // UPLOAD STATUS
                  if (_storageService.isUploading) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _storageService.uploadMessage,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // USER STATUS BANNER
            _buildUserStatusBanner(),

            // ERROR MESSAGE
            if (_uploadError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _uploadError!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red[700], size: 16),
                      onPressed: () {
                        if (mounted && !_isNavigating) {
                          setState(() => _uploadError = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],

            // CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // VERIFICATION TIMELINE (Hanya untuk status 0)
                    if (!isVerified) _buildVerificationTimeline(),

                    const SizedBox(height: 16),

                    // KTP CARD
                    _buildDokumenCard(
                      type: 'ktp',
                      title: 'KTP (Kartu Tanda Penduduk)',
                      description: 'Upload foto KTP yang jelas dan terbaca\n• Pastikan foto tidak blur\n• Semua informasi terbaca jelas\n• Format JPG/PNG (max 5MB)',
                      icon: Icons.credit_card,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),

                    // KK CARD
                    _buildDokumenCard(
                      type: 'kk',
                      title: 'Kartu Keluarga (KK)',
                      description: 'Upload foto KK yang jelas dan terbaca\n• Pastikan foto tidak blur\n• Semua halaman penting terbaca\n• Format JPG/PNG (max 5MB)',
                      icon: Icons.family_restroom,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),

                    // FOTO DIRI CARD
                    _buildDokumenCard(
                      type: 'diri',
                      title: 'Foto Diri Terbaru',
                      description: 'Upload pas foto terbaru\n• Latar belakang polos\n• Wajah terlihat jelas\n• Ekspresi netral\n• Format JPG/PNG (max 5MB)',
                      icon: Icons.person,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 24),

                    // UPLOAD MANUAL SECTION (Hanya jika belum verified atau ada file pending)
                    if (!isVerified || !_storageService.isAllFilesComplete) 
                      _buildUploadManualSection(),

                    const SizedBox(height: 16),

                    // TOMBOL LEWATI (Hanya untuk status 0)
                    if (!isVerified) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton(
                          onPressed: _isLoading || _storageService.isUploading ? null : _lewatiUpload,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange,
                                  ),
                                )
                              : const Text(
                                  'Lewati & Lanjut ke Dashboard',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // TOMBOL LANJUT KE DASHBOARD (Untuk status 1)
                    if (isVerified) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _proceedToDashboard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Lanjut ke Dashboard',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // INFO
                    if (!allFilesComplete && !isVerified) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Upload semua 3 dokumen untuk pengalaman terbaik. '
                                'Foto diri akan digunakan sebagai foto bukti. '
                                'Dokumen akan disimpan sementara dan diupload otomatis ketika lengkap.',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // TROUBLESHOOTING INFO
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.help_outline, color: Colors.blue[700], size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Sistem 4 File:',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Upload 3 file asli (KTP, KK, Foto Diri)\n'
                            '• Foto diri digunakan sebagai foto bukti\n'
                            '• Total 4 file dikirim ke server\n'
                            '• Tidak ada file dummy/dummy.jpg\n'
                            '• Semua file berasal dari user\n'
                            '• Ukuran maksimal 5MB per file\n'
                            '• Format JPG/PNG didukung\n'
                            '• Data tersimpan meski app ditutup',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, bool isCompleted) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted 
                ? Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isCompleted ? Colors.green : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ✅ HELPER: GET DOCUMENT SERVER URL
  String? _getDocumentServerUrl(String type) {
    switch (type) {
      case 'ktp':
        return _currentUser['foto_ktp'];
      case 'kk':
        return _currentUser['foto_kk'];
      case 'diri':
        return _currentUser['foto_diri'];
      default:
        return null;
    }
  }

  // ✅ HELPER: SHORTEN URL UNTUK DISPLAY
  String _shortenUrl(String url) {
    if (url.length <= 30) return url;
    return '${url.substring(0, 15)}...${url.substring(url.length - 10)}';
  }
}