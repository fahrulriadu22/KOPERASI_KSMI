import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import '../services/temporary_storage_service.dart';
import 'package:flutter/painting.dart'; // Untuk NetworkImage
import '../services/file_validator.dart';
import 'auth_wrapper.dart';
import 'edit_profile_screen.dart';
import 'package:flutter/foundation.dart'; // ✅ UNTUK kDebugMode
import 'package:path_provider/path_provider.dart';
import '../services/local_image_service.dart';
import 'dashboard_screen.dart';


// ✅ CUSTOM SHAPE UNTUK APPBAR
class NotchedAppBarShape extends ContinuousRectangleBorder {
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final double centerWidth = 180.0;
    final double centerDepth = 25.0;
    final double sideCurveDepth = 25.0;
    
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..quadraticBezierTo(
        rect.right - 40, 
        rect.bottom - sideCurveDepth,
        rect.right - 80, 
        rect.bottom - centerDepth,
      )
      ..lineTo(rect.left + 80, rect.bottom - centerDepth)
      ..quadraticBezierTo(
        rect.left + 40, 
        rect.bottom - sideCurveDepth,
        rect.left, 
        rect.bottom,
      )
      ..lineTo(rect.left, rect.top)
      ..close();
  }
}

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onLogout;

  const ProfileScreen({
    super.key, 
    required this.user,
    this.onProfileUpdated,
    this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _currentUser;
  final ApiService _apiService = ApiService();
  final TemporaryStorageService _storageService = TemporaryStorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final LocalImageService _localImageService = LocalImageService(); // ✅ TAMBAH INI
  
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isRefreshing = false;
  String? _uploadError;
  String? _authStatusUser;

@override
void initState() {
  super.initState();
  _currentUser = Map<String, dynamic>.from(widget.user);
  _loadAuthStatus();
  
  // ✅ CEK STATUS USER DAN REDIRECT JIKA SUDAH VERIFIED
  _checkUserStatusAndRedirect();
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    print('🔄 PostFrameCallback - Starting data load...');
    _initializeStorage();
    _loadCurrentUser();
    _syncProfileData();
    _cleanupOldImages();
  });
}

  // ✅ METHOD BARU: LOAD STATUS DARI AUTH LOGIN
  Future<void> _loadAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authStatus = prefs.getString('auth_status_user');
      
      print('🎯 Loading auth status from SharedPreferences: $authStatus');
      
      if (mounted) {
        setState(() {
          _authStatusUser = authStatus ?? '0';
        });
      }
    } catch (e) {
      print('❌ Error loading auth status: $e');
      if (mounted) {
        setState(() {
          _authStatusUser = '0';
        });
      }
    }
  }

    // ✅ METHOD BARU: GET FINAL STATUS (PRIORITAS AUTH)
  String get _finalStatusUser {
    if (_authStatusUser != null && _authStatusUser!.isNotEmpty) {
      return _authStatusUser!;
    }
    
    final currentStatus = _currentUser['status_user']?.toString();
    if (currentStatus != null && currentStatus.isNotEmpty && currentStatus != 'null') {
      return currentStatus;
    }
    
    final widgetStatus = widget.user['status_user']?.toString();
    if (widgetStatus != null && widgetStatus.isNotEmpty && widgetStatus != 'null') {
      return widgetStatus;
    }
    
    return '0';
  }


// ✅ TAMBAHKAN METHOD INI:
void _checkUserStatusAndRedirect() {
  try {
    final isVerified = _isUserVerified;
    
    print('🎯 ProfileScreen - User Status Check: $_finalStatusUser → Verified: $isVerified');
    
    if (isVerified) {
      print('✅ User sudah verified, bisa akses dashboard');
    } else {
      print('⏳ User belum verified, hanya bisa akses profile');
    }
  } catch (e) {
    print('❌ Error checking user status: $e');
  }
}

// ✅ METHOD BARU: CLEANUP OLD IMAGES
void _cleanupOldImages() {
  Future.delayed(const Duration(seconds: 5), () async {
    try {
      final localService = LocalImageService();
      await localService.cleanupOldImages();
    } catch (e) {
      print('❌ Cleanup error: $e');
    }
  });
}

// ✅ METHOD BARU: SYNC PROFILE DATA
Future<void> _syncProfileData() async {
  try {
    print('🔄 Syncing profile data for image consistency...');
    
    final apiResult = await _apiService.getUserInfo();
    if (apiResult['success'] == true && apiResult['data'] != null) {
      final apiData = apiResult['data'];
      final apiFotoDiri = apiData['foto_diri'];
      final currentFotoDiri = _currentUser['foto_diri'];
      
      print('📸 Foto diri sync:');
      print('   - API: $apiFotoDiri');
      print('   - Current: $currentFotoDiri');
      
      // ✅ JIKA BERBEDA, UPDATE DARI API
      if (apiFotoDiri != null && apiFotoDiri != currentFotoDiri) {
        print('🔄 Updating foto_diri from API');
        if (mounted) {
          setState(() {
            _currentUser['foto_diri'] = apiFotoDiri;
          });
        }
        _clearAllImageCache();
      }
    }
  } catch (e) {
    print('❌ Error syncing profile data: $e');
  }
}

  // ✅ INITIALIZE TEMPORARY STORAGE
  Future<void> _initializeStorage() async {
    await _storageService.loadFilesFromStorage();
    print('✅ TemporaryStorageService initialized for profile documents');
    _storageService.printDebugInfo();
  }

 // ✅ FIX: LOAD USER INFO DARI SERVER DENGAN SETSTATE YANG BENAR
Future<void> _loadUserInfoFromServer() async {
  try {
    print('🚀 Loading user info from getUserInfo API...');
    
    final userInfoResult = await _apiService.getUserInfo();
    
    if (userInfoResult['success'] == true && userInfoResult['data'] != null) {
      final userInfoData = userInfoResult['data'];
      
      print('✅ getUserInfo API success!');
      print('👤 Data received:');
      print('   - username: ${userInfoData['username']}');
      print('   - nama: ${userInfoData['nama']}');
      print('   - email: ${userInfoData['email']}');
      print('   - alamat: ${userInfoData['alamat']}');
      
      // ✅ FIX: PASTIKAN SETSTATE DIPANGGIL DENGAN BENAR
      if (mounted) {
        setState(() {
          // ✅ UPDATE SEMUA FIELD PENTING KE _currentUser
          _currentUser = {
            ..._currentUser, // Pertahankan data lama
            ...userInfoData,  // Update dengan data baru dari getUserInfo
          };
        });
        
        // ✅ DEBUG: CEK SETELAH UPDATE
        print('🔄 SETSTATE DIPANGGIL - Data updated in UI state');
        print('📊 Current user data after update:');
        print('   - username: ${_currentUser['username']}');
        print('   - nama: ${_currentUser['nama']}');
        print('   - email: ${_currentUser['email']}');
      }
      
      print('✅ User info updated from getUserInfo API');
      return;
    } else {
      print('❌ getUserInfo API failed: ${userInfoResult['message']}');
    }
  } catch (e) {
    print('❌ Error loading user info from server: $e');
  }
}

Future<void> _loadCurrentUser() async {
  try {
    if (mounted) {
      setState(() {
        _isRefreshing = true;
        _isLoading = true;
      });
    }
    
    print('🔄 Loading user data for profile...');
    
    // ✅ PRIORITAS 1: AMBIL DATA SUPER LENGKAP
    final superResult = await _apiService.getCompleteUserInfo();
    
    if (superResult['success'] == true && superResult['data'] != null) {
      final superData = superResult['data'];
      
      // ✅ FIX: PASTIKAN SETSTATE DIPANGGIL
      if (mounted) {
        setState(() {
          _currentUser = superData;
          print('🎉 SUPER USER DATA APPLIED TO UI!');
        });
      }
      
      _debugSuperUserData(superData);
      return;
    }
    
    // ✅ FALLBACK: GUNAKAN GETUSERINFO API
    print('🔄 Fallback to getUserInfo API...');
    await _loadUserInfoFromServer();
    
  } catch (e) {
    print('❌ Error loading current user: $e');
    await _loadLocalDataFallback();
  } finally {
    // ✅ PASTIKAN INI SELALU DIJALANKAN
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      print('✅ Loading states updated: _isLoading=false, _isRefreshing=false');
    }
  }
}

// ✅ DEBUG SUPER USER DATA
void _debugSuperUserData(Map<String, dynamic> userData) {
  print('🐛 === SUPER USER DATA DEBUG ===');
  
  print('🔑 SYSTEM INFO:');
  print('   - user_id: ${userData['user_id']}');
  print('   - id: ${userData['id']}');
  print('   - user_key: ${userData['user_key']}');
  print('   - token: ${userData['token']}');
  print('   - status_user: ${userData['status_user']}');
  
  print('👤 BASIC INFO:');
  print('   - username: ${userData['username']}');
  print('   - nama: ${userData['nama']}');
  print('   - email: ${userData['email']}');
  print('   - telp: ${userData['telp']}');
  
  print('📄 DOCUMENT INFO:');
  print('   - foto_ktp: ${userData['foto_ktp']}');
  print('   - foto_kk: ${userData['foto_kk']}');
  print('   - foto_diri: ${userData['foto_diri']}');
  print('   - foto_bukti: ${userData['foto_bukti']}');
  
  print('🏠 ADDRESS INFO:');
  print('   - alamat: ${userData['alamat']}');
  print('   - ktp_alamat: ${userData['ktp_alamat']}');
  print('   - domisili_alamat: ${userData['domisili_alamat']}');
  
  print('📋 PERSONAL INFO:');
  print('   - job: ${userData['job']}');
  print('   - pekerjaan: ${userData['pekerjaan']}');
  print('   - birth_place: ${userData['birth_place']}');
  print('   - tempat_lahir: ${userData['tempat_lahir']}');
  
  print('🎯 TOTAL KEYS: ${userData.keys.length}');
  print('📋 ALL KEYS: ${userData.keys.toList()}');
  print('🐛 === DEBUG END ===');
}

// ✅ HELPER: CEK APAKAH DATA SUDAH LENGKAP
bool _hasCompleteData() {
  final hasBasicInfo = _currentUser['username'] != null || 
                      _currentUser['nama'] != null || 
                      _currentUser['email'] != null;
  
  final hasDocumentInfo = _currentUser['foto_ktp'] != null || 
                         _currentUser['foto_kk'] != null || 
                         _currentUser['foto_diri'] != null;
  
  return hasBasicInfo && hasDocumentInfo;
}


// ✅ FALLBACK: LOAD DATA DARI DASHBOARD
Future<void> _loadFromDashboardFallback() async {
  try {
    print('🔄 Trying dashboard fallback...');
    final dashboardResult = await _apiService.getDashboardDataRobust();
    
    if (dashboardResult['success'] == true && dashboardResult['data'] != null) {
      final dashboardData = dashboardResult['data'];
      final profileData = dashboardData['profile'] ?? {};
      
      if (profileData.isNotEmpty) {
        if (mounted) {
          setState(() {
            _currentUser = {..._currentUser, ...profileData};
          });
        }
        print('✅ Profile data updated from dashboard fallback');
      }
    }
  } catch (e) {
    print('❌ Dashboard fallback failed: $e');
    await _loadLocalDataFallback();
  }
}

// ✅ FALLBACK: LOAD DATA LOKAL
Future<void> _loadLocalDataFallback() async {
  try {
    print('🔄 Trying local data fallback...');
    final user = await _apiService.getCurrentUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
      print('✅ Using local user data');
    } else {
      print('❌ No local user data available');
    }
  } catch (e) {
    print('❌ Local data fallback failed: $e');
  }
}

// ✅ UPDATE: SAAT PROFILE DIUPDATE, SIMPAN KE LOCAL JUGA
void _onProfileUpdated(Map<String, dynamic> updatedData) {
  print('🔄 Profile updated callback received');
  
  setState(() {
    _currentUser = {..._currentUser, ...updatedData};
  });
  
  // ✅ SIMPAN DATA USER KE LOCAL STORAGE
  _saveUserDataToLocal(updatedData);
}

// ✅ METHOD BARU: SIMPAN USER DATA KE LOCAL
Future<void> _saveUserDataToLocal(Map<String, dynamic> userData) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_data', jsonEncode(userData));
    print('💾 User data saved to local storage');
  } catch (e) {
    print('❌ Error saving user data to local: $e');
  }
}

// ✅ TAMBAHKAN METHOD INI UNTUK DEBUG SEMUA DATA
void _debugAllUserData() {
  print('🐛 === CURRENT USER DATA FOR UI ===');
  
  // BASIC INFO
  print('👤 Basic Info:');
  print('   - username: ${_currentUser['username']}');
  print('   - nama: ${_currentUser['nama']}');
  print('   - email: ${_currentUser['email']}');
  print('   - telp: ${_currentUser['telp']}');
  print('   - phone: ${_currentUser['phone']}');
  
  // ADDRESS INFO
  print('🏠 Address Info:');
  print('   - alamat: ${_currentUser['alamat']}');
  print('   - ktp_alamat: ${_currentUser['ktp_alamat']}');
  print('   - ktp_rt: ${_currentUser['ktp_rt']}');
  print('   - ktp_rw: ${_currentUser['ktp_rw']}');
  print('   - domisili_alamat: ${_currentUser['domisili_alamat']}');
  print('   - domisili_rt: ${_currentUser['domisili_rt']}');
  print('   - domisili_rw: ${_currentUser['domisili_rw']}');
  
  // PERSONAL INFO
  print('📋 Personal Info:');
  print('   - job: ${_currentUser['job']}');
  print('   - pekerjaan: ${_currentUser['pekerjaan']}');
  print('   - birth_place: ${_currentUser['birth_place']}');
  print('   - tempat_lahir: ${_currentUser['tempat_lahir']}');
  
  print('🎯 Total Keys: ${_currentUser.keys.length}');
  print('🐛 === DEBUG END ===');
}

// ✅ METHOD BARU: UPLOAD KE SERVER & SIMPAN KE LOCAL
Future<void> _uploadProfilePhotoWithLocalSave() async {
  try {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      setState(() {
        _isUploading = true;
        _uploadError = null;
      });

      final file = File(pickedFile.path);
      print('📤 Uploading profile photo: ${file.path}');
      
      // ✅ 1. UPLOAD KE API SERVER
      final result = await _apiService.setProfilePhoto(file.path);

      if (result['success'] == true) {
        // ✅ 2. SIMPAN KE LOCAL STORAGE
        final localService = LocalImageService();
        final filename = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // ✅ COPY FILE KE LOCAL STORAGE
        final localFile = await _copyFileToLocalStorage(file, filename);
        
        if (localFile != null) {
          // ✅ 3. UPDATE UI DENGAN FILE LOKAL
          setState(() {
            _currentUser['foto_diri'] = filename; // Simpan filename lokal
          });
          
          _showSafeSnackBar('✅ Foto profil berhasil diupload & disimpan lokal!');
        }
        
      } else {
        throw Exception(result['message'] ?? 'Upload gagal');
      }
    }
  } catch (e) {
    setState(() {
      _isUploading = false;
      _uploadError = 'Error: $e';
    });
    _showSafeSnackBar('Gagal upload: $e', isError: true);
  } finally {
    setState(() => _isUploading = false);
  }
}

// ✅ METHOD BARU: COPY FILE KE LOCAL STORAGE
Future<File?> _copyFileToLocalStorage(File originalFile, String filename) async {
  try {
    final localService = LocalImageService();
    
    // ✅ BACA FILE ASLI
    final bytes = await originalFile.readAsBytes();
    
    // ✅ SIMPAN KE LOCAL STORAGE
    final directory = await getApplicationDocumentsDirectory();
    final localPath = '${directory.path}/profile_images/$filename';
    
    final localDir = Directory('${directory.path}/profile_images');
    if (!await localDir.exists()) {
      await localDir.create(recursive: true);
    }

    final localFile = File(localPath);
    await localFile.writeAsBytes(bytes);
    
    // ✅ SIMPAN REFERENCE KE SHARED PREFS
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_profile_image', localPath);
    await prefs.setString('local_profile_filename', filename);
    
    print('💾 Profile image saved locally: $localPath');
    return localFile;
  } catch (e) {
    print('❌ Error saving to local storage: $e');
    return null;
  }
}

// ✅ METHOD BARU: CLEAR LOCAL IMAGE CACHE
Future<void> _clearLocalImageCache() async {
  try {
    final localService = LocalImageService();
    final fotoDiri = _currentUser['foto_diri'];
    
    if (fotoDiri != null) {
      final filename = _getImageFilename(fotoDiri);
      await localService.deleteLocalImage(filename);
      print('🧹 Cleared local image cache: $filename');
    }
    
    // ✅ CLEAR IMAGE CACHE JUGA
    imageCache.clear();
    
  } catch (e) {
    print('❌ Error clearing local cache: $e');
  }
}

// ✅ FIX: CLEAR ALL IMAGE CACHE YANG LEBIH EFFECTIVE
void _clearAllImageCache() {
  try {
    print('🧹 Clearing all image cache...');
    
    // Clear Flutter's image cache
    imageCache.clear();
    imageCache.clearLiveImages();
    
    print('✅ Image cache cleared successfully');
  } catch (e) {
    print('❌ Error clearing image cache: $e');
  }
}

// ✅ FIX: FORCE RELOAD PROFILE IMAGE YANG SIMPLE
void _forceReloadProfileImage() {
  print('🔄 Force reloading profile image...');
  
  // Clear cache
  _clearAllImageCache();
  
  // Trigger rebuild
  if (mounted) {
    setState(() {});
  }
  
  _showSafeSnackBar('Reloading image...');
}

// ✅ METHOD BARU: CLEAR IMAGE CACHE
void _clearImageCache(String url) {
  try {
    final networkImage = NetworkImage(url);
    networkImage.evict().then((_) {
      print('✅ Image cache cleared for: $url');
    });
  } catch (e) {
    print('❌ Error clearing image cache: $e');
  }
}

// ✅ METHOD BARU: REFRESH PROFILE DENGAN RETRY MECHANISM
Future<void> _refreshProfileWithRetry() async {
  const maxRetries = 3;
  const retryDelay = Duration(seconds: 2);
  
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      print('🔄 Profile refresh attempt $attempt of $maxRetries...');
      
      await _refreshProfile();
      
      // ✅ CEK APAKAH FOTO_DIRI SUDAH TERUPDATE
      final currentFotoDiri = _currentUser['foto_diri'];
      print('📸 Current foto_diri after refresh: $currentFotoDiri');
      
      // Jika foto_diri berisi filename baru,anggap berhasil
      if (currentFotoDiri != null && 
          currentFotoDiri.toString().isNotEmpty && 
          currentFotoDiri != 'uploaded' &&
          currentFotoDiri.toString().contains('.')) {
        print('✅ Foto profil successfully updated in UI');
        return;
      }
      
      // Jika belum berhasil, tunggu dan coba lagi
      if (attempt < maxRetries) {
        print('⏳ Foto belum terupdate, retrying in ${retryDelay.inSeconds} seconds...');
        await Future.delayed(retryDelay);
      }
      
    } catch (e) {
      print('❌ Profile refresh attempt $attempt failed: $e');
      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }
  }
  
  print('⚠️ Foto profil mungkin belum terupdate setelah $maxRetries attempts');
}

// ✅ METHOD BARU: AMBIL FOTO PROFIL DARI KAMERA
Future<void> _takeProfilePhoto() async {
  try {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      if (mounted) {
        setState(() {
          _isUploading = true;
          _uploadError = null;
        });
      }

      final file = File(pickedFile.path);
      print('📸 Taking profile photo: ${file.path}');
      
      // ✅ VALIDASI FILE
      if (!await file.exists()) {
        throw Exception('File tidak ditemukan');
      }

      final fileSize = file.lengthSync();
      if (fileSize > 3 * 1024 * 1024) {
        throw Exception('Ukuran file terlalu besar. Maksimal 3MB.');
      }

      // ✅ UPLOAD KE API setProfilePhoto
      final result = await _apiService.setProfilePhoto(file.path);

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }

      if (result['success'] == true) {
        _showSafeSnackBar('✅ Foto profil berhasil diambil!');
        
        // ✅ REFRESH DATA USER SETELAH UPLOAD BERHASIL
        await _refreshProfile();
        
      } else {
        throw Exception(result['message'] ?? 'Upload foto profil gagal');
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadError = 'Error mengambil foto profil: $e';
      });
    }
    
    print('❌ Profile photo camera failed: $e');
    _showSafeSnackBar('Gagal mengambil foto profil: $e', isError: true);
  }
}

// ✅ INTEGRASI: UPLOAD DOKUMEN DENGAN SAFE CHECK
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

      // ✅ GUNAKAN SAFE SNACKBAR
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
    _showSafeSnackBar('Gagal upload $documentName: $e', isError: true);
  }
}

 // ✅ INTEGRASI: TAKE PHOTO DENGAN SAFE CHECK
Future<void> _takePhoto(String type, String documentName) async {
  try {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
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

      if (mounted) {
        setState(() {});
      }

      // ✅ GUNAKAN SAFE SNACKBAR
      _showSafeSnackBar('$documentName berhasil diambil ✅');

      print('💾 $documentName from camera saved to temporary storage');
      
      // ✅ CHECK AUTO UPLOAD SETELAH SIMPAN FILE
      _checkAutoUpload();
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _uploadError = 'Error mengambil foto $documentName: $e';
      });
    }

    print('❌ Camera failed: $e');
    _showSafeSnackBar('Gagal mengambil foto $documentName: $e', isError: true);
  }
}

// ✅ INTEGRASI: CHECK AUTO UPLOAD YANG SAMA
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

  // ✅ CLEAR SPECIFIC FILE
  Future<void> _clearFile(String type, String documentName) async {
    await _storageService.clearFile(type);
    if (mounted) {
      setState(() {});
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$documentName dihapus'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ✅ MANUAL UPLOAD ALL FILES - 3 ASLI + 1 DUMMY
  Future<void> _uploadAllFiles() async {
    if (!_storageService.isAllFilesComplete) {
      final missingFiles = _getMissingFilesList();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Harap lengkapi semua dokumen terlebih dahulu:'),
              const SizedBox(height: 4),
              Text(
                missingFiles.join(', '),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_storageService.isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Upload sedang berjalan, harap tunggu...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _showUploadConfirmationDialog();
  }

  // ✅ DIALOG KONFIRMASI UPLOAD 4 FILES (3 ASLI + 1 DUMMY)
  void _showUploadConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Upload Semua Dokumen?'),
        content: const Text(
          'Apakah Anda yakin ingin mengupload semua dokumen?\n\n'
          '• KTP\n'
          '• Kartu Keluarga\n'
          '• Foto Diri\n\n'
          'Sistem akan menambahkan file dummy bukti secara otomatis.\n'
          'Total 4 file akan dikirim ke server.'
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

  // ✅ PROSES UPLOAD YANG SEBENARNYA - 3 ASLI + 1 DUMMY
  Future<void> _startUploadProcess() async {
    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    print('🚀 Starting upload process with dummy system...');
    
    try {
      // ✅ GUNAKAN UPLOAD WITH DUMMY SYSTEM YANG SUDAH FIX
      final result = await _storageService.uploadWithDummySystem();

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Upload berhasil'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // ✅ REFRESH USER DATA SETELAH UPLOAD BERHASIL
        print('🔄 Refreshing user data after successful upload...');
        await _loadCurrentUser();
        widget.onProfileUpdated?.call();
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Upload gagal'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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

  // ✅ TAMBAHKAN METHOD UNTUK KE DASHBOARD:
void _goToDashboard() {
  print('🚀 Navigating to Dashboard from Profile');
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) => DashboardScreen(user: _currentUser),
    ),
    (route) => false,
  );
}

// ✅ BUILD DOKUMEN CARD - GUNAKAN LOGIC YANG SAMA
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
  
  // ✅ GUNAKAN METHOD YANG SAMA UNTUK CEK STATUS SERVER
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

// ✅ FIX: GET DOCUMENT SERVER STATUS - SAMA PERSIS DENGAN UPLOAD_DOKUMEN_SCREEN
Map<String, dynamic> _getDocumentServerStatus(String type) {
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
  }
  
  // ✅ GUNAKAN LOGIC YANG SAMA PERSIS: CEK .jpg BUKAN http
  final isUploaded = documentUrl != null && 
                    documentUrl.toString().isNotEmpty && 
                    documentUrl != 'uploaded' &&
                    documentUrl.toString().contains('.jpg');
  
  print('🔍 Document $type server status: $documentUrl → $isUploaded');
  return {
    'uploaded': isUploaded,
    'url': isUploaded ? documentUrl : null,
  };
}

// ✅ INTEGRASI: SAFE SNACKBAR DENGAN MOUNTED CHECK
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

// ✅ INTEGRASI: CEK STATUS DOKUMEN YANG LEBIH AKURAT
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
  }
  
  print('🔍 Document $type check: $documentUrl');
  
  // ✅ FIX: CEK LEBIH DETAIL
  if (documentUrl == null || documentUrl.toString().isEmpty) {
    return false;
  }
  
  final urlString = documentUrl.toString();
  
  // ✅ CEK BERBAGAI KONDISI YANG MENANDAKAN SUDAH UPLOAD
  final isUploaded = 
      // Ada filename dengan extension image
      (urlString.contains('.jpg') || 
       urlString.contains('.jpeg') || 
       urlString.contains('.png')) ||
      // Atau status uploaded
      urlString == 'uploaded' ||
      // Atau mengandung string tertentu
      urlString.contains('upload') ||
      // Atau panjang string menandakan filename
      (urlString.length > 10 && !urlString.contains('null'));
  
  print('   → Uploaded: $isUploaded');
  return isUploaded;
}

// ✅ INTEGRASI: VALIDASI SEBELUM UPLOAD
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

// ✅ METHOD BARU: CEK APAKAH VERIFIED
bool get _isUserVerified {
  return _finalStatusUser == '1' || _finalStatusUser == 1;
}

  // ✅ HELPER: SHORTEN URL UNTUK DISPLAY
  String _shortenUrl(String url) {
    if (url.length <= 30) return url;
    return '${url.substring(0, 15)}...${url.substring(url.length - 10)}';
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

  // ✅ BUILD UPLOAD MANUAL SECTION - HANYA 3 FILE YANG DITAMPILKAN
  Widget _buildUploadManualSection() {
    final allFilesComplete = _storageService.isAllFilesComplete;
    final hasAnyFile = _storageService.hasAnyFile;

    // ✅ CEK APAKAH ADA FILE YANG BELUM TERUPLOAD KE SERVER
    final hasPendingUpload = hasAnyFile && 
        (!_getDocumentServerStatus('ktp')['uploaded'] || 
         !_getDocumentServerStatus('kk')['uploaded'] || 
         !_getDocumentServerStatus('diri')['uploaded']);

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
                ? 'Semua 3 dokumen sudah lengkap. Sistem akan menambahkan 1 file dummy bukti otomatis. Total 4 file akan diupload ke server.'
                : 'Upload dokumen yang sudah dipilih atau lengkapi semua dokumen terlebih dahulu.',
            style: TextStyle(fontSize: 12, color: Colors.blue[700]),
          ),
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
          if (!allFilesComplete) ...[
            const SizedBox(height: 8),
            Text(
              'File yang belum lengkap: ${_getMissingFilesList().join(', ')}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ HELPER: GET LIST OF MISSING FILES - HANYA 3 FILE YANG DITAMPILKAN
  List<String> _getMissingFilesList() {
    List<String> missing = [];
    if (!_storageService.hasKtpFile) missing.add('KTP');
    if (!_storageService.hasKkFile) missing.add('KK');
    if (!_storageService.hasDiriFile) missing.add('Foto Diri');
    return missing;
  }

  // ✅ HANDLE UPLOAD ERROR
  void _handleUploadError(dynamic e, String typeName) {
    setState(() {
      _uploadError = 'Error upload $typeName: $e';
    });
    
    print('❌ Upload failed: $e');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal upload $typeName: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

// Di ProfileScreen - perbaiki method _logout
Future<void> _logout() async {
  bool confirm = await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Konfirmasi Logout'),
      content: const Text('Apakah Anda yakin ingin logout dari aplikasi?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Logout', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  ) ?? false;

  if (confirm && mounted) {
    print('🚪 Logout confirmed from ProfileScreen');
    
    // ✅ OPTION 1: GUNAKAN CALLBACK DARI PARENT (AuthWrapper)
    if (widget.onLogout != null) {
      print('📞 Using parent logout callback');
      widget.onLogout!();
      return;
    }
    
    // ✅ OPTION 2: DIRECT LOGOUT JIKA TIDAK ADA CALLBACK
    print('🔐 Performing direct logout');
    await _performDirectLogout();
  }
}

// ✅ PERBAIKI DIRECT LOGOUT DENGAN ERROR HANDLING
Future<void> _performDirectLogout() async {
  if (!mounted) return;
  
  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Sedang logout...'),
        ],
      ),
    ),
  );

  try {
    print('🔐 Calling API logout...');
    final result = await _apiService.logout();
    print('🔐 Logout API result: ${result['success']}');
    
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      // ✅ NAVIGASI YANG SAMA UNTUK SEMUA STATUS
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  } catch (e) {
    print('❌ Logout error: $e');
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      
      // ✅ FALLBACK: Tetap redirect ke AuthWrapper meski error
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }
}

// ✅ UPDATE: REFRESH PROFILE YANG LEBIH ROBUST DENGAN getUserInfo
Future<void> _refreshProfile() async {
  try {
    if (mounted) {
      setState(() {
        _isRefreshing = true;
        _uploadError = null;
      });
    }
    
    print('🔄 Manual refresh triggered with getUserInfo...');
    
    // ✅ LOAD DATA TERBARU DARI getUserInfo API
    await _loadUserInfoFromServer();
    
    // ✅ LOAD DATA TAMBAHAN DARI SUMBER LAIN
    await _loadCurrentUser();
    
    // ✅ PANGGIL CALLBACK JIKA ADA
    widget.onProfileUpdated?.call();
    
    if (mounted) {
      setState(() => _isRefreshing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Profile berhasil diperbarui',
            style: TextStyle(color: Colors.white), // ← TEXT PUTIH
          ),
          backgroundColor: Colors.green[700], // ← BACKGROUND HIJAU
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    
  } catch (e) {
    print('❌ Refresh error: $e');
    if (mounted) {
      setState(() => _isRefreshing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memperbarui profile: $e',
            style: const TextStyle(color: Colors.white), // ← TEXT PUTIH
          ),
          backgroundColor: Colors.red, // ← BACKGROUND MERAH
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}


// ✅ UPDATE PROFILE HEADER UNTUK TAMPILKAN STATUS
Widget _buildProfileHeader() {
  final userStatus = _currentUser['status_user'] ?? 0;
  final isVerified = userStatus == 1 || userStatus == '1';
  return Center(
    child: Column(
      children: [
        Stack(
          children: [
            // ✅ GUNAKAN CUSTOM IMAGE WIDGET DENGAN ERROR HANDLING
            _buildProfileImageWithErrorHandling(),
            if (_isRefreshing || _isUploading)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _showProfilePhotoOptions,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _currentUser['nama'] ?? 'Anggota Koperasi',
          style: const TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          _currentUser['email'] ?? 'email@koperasi.com',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // ✅ UPDATE BADGE STATUS
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isVerified ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isVerified ? Colors.green[200]! : Colors.orange[200]!
            ),
          ),
          child: Text(
            isVerified ? 'Anggota Terverifikasi' : 'Menunggu Verifikasi',
            style: TextStyle(
              color: isVerified ? Colors.green[800] : Colors.orange[800],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isUploading ? 'Sedang mengupload...' : 
          _isRefreshing ? 'Memperbarui data...' : 'Tap foto untuk mengganti, long press untuk reload',
          style: TextStyle(
            color: _isUploading ? Colors.orange[700] : 
                  _isRefreshing ? Colors.blue[700] : Colors.grey[500],
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ✅ FIX: BUILD PROFILE IMAGE YANG LEBIH AMAN
Widget _buildProfileImageWithErrorHandling() {
  return GestureDetector(
    onTap: _showProfilePhotoOptions,
    onLongPress: _forceReloadProfileImage,
    child: Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green[50],
      ),
      child: ClipOval(
        child: _buildSafeProfileImage(),
      ),
    ),
  );
}

// Di profile_screen.dart - tambahkan banner restriction
Widget _buildStatusRestrictionBanner() {
  final userStatus = _currentUser['status_user'] ?? 0;
  
  if (userStatus == 0) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Akun Menunggu Verifikasi',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Saat ini Anda hanya dapat mengakses menu profile. '
            'Setelah admin memverifikasi dokumen, Anda akan mendapatkan akses penuh ke dashboard.',
            style: TextStyle(
              color: Colors.orange[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          // ✅ TAMPILKAN PROGRESS VERIFIKASI
          _buildVerificationProgress(),
        ],
      ),
    );
  }
  
  return const SizedBox.shrink();
}

Widget _buildVerificationProgress() {
  return Column(
    children: [
      LinearProgressIndicator(
        value: 0.5, // Progress 50% - sudah upload, menunggu verifikasi
        backgroundColor: Colors.grey[300],
        color: Colors.orange,
      ),
      const SizedBox(height: 8),
      Text(
        'Menunggu verifikasi admin...',
        style: TextStyle(
          color: Colors.orange[700],
          fontSize: 12,
        ),
      ),
    ],
  );
}

// ✅ UPDATE: BUILD USER STATUS BANNER
Widget _buildUserStatusBanner() {
  final isVerified = _isUserVerified;
  
  print('🎯 User Status Check in Profile:');
  print('   - Auth Status: $_authStatusUser');
  print('   - Final Status: $_finalStatusUser → Verified: $isVerified');
  
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
                  'Akun Terverifikasi ✅',
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

// ✅ UPDATE: VERIFICATION TIMELINE
Widget _buildVerificationTimeline() {
  final isVerified = _isUserVerified;
  
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

// ✅ METHOD BARU: LOAD PROFILE IMAGE DARI LOCAL
Widget _buildSafeProfileImage() {
  // ✅ CEK APAKAH ADA DI LOCAL STORAGE
  return FutureBuilder<File?>(
    future: _getLocalProfileImage(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildImageLoading();
      }
      
      if (snapshot.hasData && snapshot.data != null) {
        // ✅ GUNAKAN FILE LOKAL
        final localFile = snapshot.data!;
        print('✅ Using local profile image: ${localFile.path}');
        return Image.file(
          localFile,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
        );
      } else {
        // ✅ FALLBACK KE PLACEHOLDER
        return _buildProfilePlaceholder();
      }
    },
  );
}

// ✅ METHOD BARU: GET LOCAL PROFILE IMAGE
Future<File?> _getLocalProfileImage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final localPath = prefs.getString('local_profile_image');
    
    if (localPath != null) {
      final file = File(localPath);
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 1000) { // Validasi file tidak corrupt
          print('✅ Local profile image found: $localPath ($fileSize bytes)');
          return file;
        }
      }
    }
    return null;
  } catch (e) {
    print('❌ Error loading local profile image: $e');
    return null;
  }
}

// ✅ UPDATE DI LocalImageService - PAKAI API UNTUK DOWNLOAD
Future<File?> saveProfileImageFromApi(String filename) async {
  try {
    final apiService = ApiService();
    
    print('💾 Downloading profile image via API: $filename');
    
    // ✅ DOWNLOAD DARI API DENGAN AUTHENTICATION
    final imageBytes = await apiService.downloadProfileImage(filename);
    
    if (imageBytes != null && imageBytes.isNotEmpty) {
      // ✅ SIMPAN KE LOCAL STORAGE
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/profile_images/$filename';
      
      final fileDir = Directory('${directory.path}/profile_images');
      if (!await fileDir.exists()) {
        await fileDir.create(recursive: true);
      }

      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_$filename', filePath);
      
      print('✅ Profile image saved via API: $filePath (${imageBytes.length} bytes)');
      return file;
    } else {
      print('❌ No image data received from API');
      return null;
    }
  } catch (e) {
    print('❌ Error saving profile image via API: $e');
    return null;
  }
}

// ✅ FIX: GET IMAGE FILENAME DARI URL ASSETS/IMAGES
String _getImageFilename(String fotoDiri) {
  if (fotoDiri.contains('/')) {
    // ✅ HANDLE BAIK URL LENGKAP MAUPUN HANYA FILENAME
    if (fotoDiri.contains('assets/images/')) {
      return fotoDiri.split('assets/images/').last;
    }
    return fotoDiri.split('/').last;
  }
  return fotoDiri;
}

// ✅ UPDATE DI ProfileScreen - PAKAI API UNTUK DOWNLOAD
Future<File?> _getProfileImageWithLocalCache(String fotoDiri) async {
  try {
    final localService = LocalImageService();
    final filename = _getImageFilename(fotoDiri);
    
    print('🔍 Checking local cache for: $filename');
    
    // 1. CEK LOCAL CACHE DULU
    final localFile = await localService.getLocalImage(filename);
    if (localFile != null) {
      final fileSize = await localFile.length();
      if (fileSize > 1000) {
        print('✅ Local cache HIT: $filename ($fileSize bytes)');
        return localFile;
      }
    }
    
    // 2. DOWNLOAD DARI API JIKA TIDAK ADA DI CACHE
    print('📥 Downloading from API: $filename');
    final downloadedFile = await localService.saveProfileImageFromApi(filename);
    
    return downloadedFile;
  } catch (e) {
    print('❌ Error in local cache system: $e');
    return null;
  }
}

// ✅ METHOD BARU: NETWORK IMAGE DENGAN AUTO-CACHE
Widget _buildNetworkImageWithCache(String fotoDiri) {
  final imageUrl = _buildCorrectImageUrl(fotoDiri);
  final filename = _getImageFilename(fotoDiri);
  
  print('🌐 Loading from network: $filename');
  
  return Image.network(
    imageUrl,
    fit: BoxFit.cover,
    width: 100,
    height: 100,
    errorBuilder: (context, error, stackTrace) {
      print('❌ Network image failed: $error');
      return _buildProfilePlaceholder();
    },
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) {
        // ✅ IMAGE BERHASIL LOAD, SIMPAN KE CACHE DI BACKGROUND
        _saveToCacheInBackground(imageUrl, filename);
        return child;
      }
      return _buildImageLoading();
    },
  );
}

// ✅ METHOD BARU: DOWNLOAD DAN SIMPAN KE CACHE (BACKGROUND)
void _saveToCacheInBackground(String imageUrl, String filename) async {
  try {
    final localService = LocalImageService();
    await localService.saveNetworkImage(imageUrl, filename);
    print('💾 Background cache saved: $filename');
  } catch (e) {
    print('❌ Background cache save failed: $e');
  }
}

// ✅ METHOD BARU: BERSIHKAN CACHE YANG CORRUPT
void _cleanupCorruptedCache(String filename) async {
  try {
    final localService = LocalImageService();
    await localService.deleteLocalImage(filename);
    print('🧹 Cleaned corrupted cache: $filename');
  } catch (e) {
    print('❌ Cleanup error: $e');
  }
}



// ✅ METHOD BARU: BUILD IMAGE LOADING PLACEHOLDER
Widget _buildImageLoading() {
  return Container(
    width: 100,
    height: 100,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.green[50],
    ),
    child: Center(
      child: CircularProgressIndicator(
        color: Colors.green[700],
        strokeWidth: 2,
      ),
    ),
  );
}

// ✅ METHOD BARU: DOWNLOAD UNTUK FUTURE USE
void _downloadAndSaveImageForFuture(String fotoDiri) {
  // ✅ JALANKAN DI BACKGROUND - TIDAK BLOCK UI
  Future.delayed(Duration.zero, () async {
    try {
      final localService = LocalImageService();
      final filename = _getImageFilename(fotoDiri);
      final imageUrl = _buildCorrectImageUrl(fotoDiri);
      
      await localService.saveNetworkImage(imageUrl, filename);
      print('✅ Background download completed for: $filename');
    } catch (e) {
      print('❌ Background download failed: $e');
    }
  });
}

// ✅ FIX: BUILD CORRECT IMAGE URL UNTUK ASSETS/IMAGES
String _buildCorrectImageUrl(String? fotoDiri) {
  if (fotoDiri == null) return '';
  
  // ✅ JIKA SUDAH FULL URL, LANGSUNG PAKAI
  if (fotoDiri.startsWith('http')) {
    return '$fotoDiri?t=${DateTime.now().millisecondsSinceEpoch}';
  }
  
  // ✅ FIX: GUNAKAN PATH assets/images BUKAN upload/foto_diri
  final baseUrl = 'http://demo.bsdeveloper.id/assets/images/';
  final encodedFilename = Uri.encodeComponent(fotoDiri);
  final cacheBuster = DateTime.now().millisecondsSinceEpoch;
  
  return '$baseUrl$encodedFilename?t=$cacheBuster';
}

// ✅ FIX: VALIDASI IMAGE DENGAN CEK URL YANG BENAR
bool _isValidProfileImage(dynamic fotoDiri) {
  if (fotoDiri == null || 
      fotoDiri.toString().isEmpty || 
      fotoDiri == 'uploaded' ||
      fotoDiri == 'null' ||
      fotoDiri.toString().trim().isEmpty) {
    return false;
  }
  
  final urlString = fotoDiri.toString().trim();
  
  // ✅ FIX: TAMBAH VALIDASI UNTUK CEK JIKA SUDAH ADA DI ASSETS/IMAGES
  if (urlString.contains('assets/images/')) {
    return true;
  }
  
  // ✅ CEK APAKAH ADA EXTENSION YANG VALID
  final hasValidExtension = 
      urlString.toLowerCase().contains('.jpg') || 
      urlString.toLowerCase().contains('.jpeg') || 
      urlString.toLowerCase().contains('.png');
  
  // ✅ CEK APAKAH PANJANG STRING MENANDAKAN FILENAME
  final looksLikeFilename = urlString.length > 5 && 
                           !urlString.contains(' ') &&
                           urlString.contains('.');
  
  print('🔍 Image Validation: "$urlString" → hasExt: $hasValidExtension, looksLikeFile: $looksLikeFilename');
  
  return hasValidExtension || looksLikeFilename;
}

// ✅ METHOD BARU: BUILD PROFILE PLACEHOLDER
Widget _buildProfilePlaceholder() {
  return Container(
    width: 100,
    height: 100,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.green[100],
    ),
    child: Icon(
      Icons.person,
      size: 50,
      color: Colors.green[700],
    ),
  );
}

// ✅ METHOD BARU: CUSTOM IMAGE LOADER DENGAN RETRY
Widget _buildProfileImageWithRetry() {
  return GestureDetector(
    onTap: _showProfilePhotoOptions,
    onLongPress: _forceReloadProfileImage,
    child: FutureBuilder<bool>(
      future: _checkImageAvailability(),
      builder: (context, snapshot) {
        final isImageAvailable = snapshot.data ?? false;
        
        return CircleAvatar(
          radius: 50,
          backgroundColor: Colors.green[50],
          backgroundImage: isImageAvailable ? _getProfileImage() : null,
          child: isImageAvailable 
              ? null 
              : Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.green[700],
                ),
        );
      },
    ),
  );
}

// ✅ METHOD BARU: CHECK IMAGE AVAILABILITY
Future<bool> _checkImageAvailability() async {
  try {
    final fotoDiri = _currentUser['foto_diri'];
    if (fotoDiri == null || fotoDiri.toString().isEmpty) {
      return false;
    }
    
    String imageUrl = fotoDiri.toString();
    if (!imageUrl.startsWith('http')) {
      imageUrl = 'http://demo.bsdeveloper.id/upload/foto_diri/$imageUrl';
    }
    
    final response = await HttpClient().getUrl(Uri.parse(imageUrl));
    final httpResponse = await response.close();
    
    return httpResponse.statusCode == 200;
  } catch (e) {
    print('❌ Image availability check failed: $e');
    return false;
  }
}

// ✅ METHOD BARU: SHOW PROFILE PHOTO OPTIONS
void _showProfilePhotoOptions() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ganti Foto Profil'),
      content: const Text('Pilih sumber untuk foto profil'),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _takeProfilePhoto();
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
                  _uploadProfilePhotoWithLocalSave();
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



  // ✅ HELPER: COUNT UPLOADED DOCUMENTS - GUNAKAN LOGIC YANG SAMA
  int _countUploadedDocuments() {
    int count = 0;
    if (_isDocumentUploadedToServer('ktp')) count++;
    if (_isDocumentUploadedToServer('kk')) count++;
    if (_isDocumentUploadedToServer('diri')) count++;
    return count;
  }

// ✅ FIX: BUILD PERSONAL INFO DENGAN KEY YANG BENAR
Widget _buildPersonalInfoSection() {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: Colors.grey[700]),
              const SizedBox(width: 8),
              const Text(
                'Informasi Pribadi',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          // ✅ FIX: GUNAKAN KEY YANG BENAR
          _buildInfoTile(Icons.person, 'Username', _currentUser['username'] ?? '-'),
          _buildInfoTile(Icons.phone, 'Nomor Telepon', _currentUser['telp'] ?? _currentUser['phone'] ?? '-'),
          _buildInfoTile(Icons.work, 'Pekerjaan', _currentUser['job'] ?? _currentUser['pekerjaan'] ?? '-'),
          _buildInfoTile(Icons.place, 'Tempat Lahir', _currentUser['birth_place'] ?? _currentUser['tempat_lahir'] ?? 'Belum diisi'),
          _buildInfoTile(Icons.cake, 'Tanggal Lahir', 
            _formatTanggalLahir(_currentUser['birth_date'] ?? _currentUser['tanggal_lahir']) ?? 'Belum diisi'),
        ],
      ),
    ),
  );
}

// ✅ FIX: BUILD KTP ADDRESS DENGAN KEY YANG BENAR
Widget _buildKtpAddressSection() {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text(
                'Alamat KTP',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoTile(Icons.home, 'Alamat KTP', _currentUser['ktp_alamat'] ?? '-', maxLines: 3),
          Row(
            children: [
              Expanded(child: _buildInfoTile(Icons.numbers, 'RT', _currentUser['ktp_rt'] ?? '-')),
              Expanded(child: _buildInfoTile(Icons.numbers, 'RW', _currentUser['ktp_rw'] ?? '-')),
            ],
          ),
          _buildInfoTile(Icons.house, 'No. Rumah', _currentUser['ktp_no'] ?? '-'),
          _buildInfoTile(Icons.location_city, 'Kota/Kabupaten', _currentUser['ktp_regency'] ?? '-'),
          _buildInfoTile(Icons.markunread_mailbox, 'Kode Pos', _currentUser['ktp_postal'] ?? '-'),
        ],
      ),
    ),
  );
}

// ✅ FIX: BUILD DOMISILI ADDRESS DENGAN KEY YANG BENAR
Widget _buildDomisiliAddressSection() {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_work, color: Colors.green[700]),
              const SizedBox(width: 8),
              const Text(
                'Alamat Domisili',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoTile(Icons.home, 'Alamat Domisili', _currentUser['domisili_alamat'] ?? '-', maxLines: 3),
          Row(
            children: [
              Expanded(child: _buildInfoTile(Icons.numbers, 'RT', _currentUser['domisili_rt'] ?? '-')),
              Expanded(child: _buildInfoTile(Icons.numbers, 'RW', _currentUser['domisili_rw'] ?? '-')),
            ],
          ),
          _buildInfoTile(Icons.house, 'No. Rumah', _currentUser['domisili_no'] ?? '-'),
          _buildInfoTile(Icons.location_city, 'Kota/Kabupaten', _currentUser['domisili_id_regency'] ?? '-'),
          _buildInfoTile(Icons.markunread_mailbox, 'Kode Pos', _currentUser['domisili_postal'] ?? '-'),
        ],
      ),
    ),
  );
}

  // ✅ BUILD COOPERATIVE INFO SECTION DENGAN USER KEY
  Widget _buildCooperativeInfoSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Informasi Koperasi',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildInfoTile(Icons.credit_card, 'No. Anggota', _currentUser['username'] ?? '-'),
            _buildInfoTile(Icons.calendar_today, 'Bergabung Sejak', _getTahunGabung()),
            _buildInfoTile(Icons.verified, 'Status Keanggotaan', 'Aktif'),
            _buildInfoTile(Icons.fingerprint, 'ID Member', _currentUser['id']?.toString() ?? _currentUser['user_id']?.toString() ?? '-'),
          ],
        ),
      ),
    );
  }

// ✅ FIX: FUNCTION UNTUK DISPLAY USER KEY
String _getUserKeyDisplay([String? userKey]) {
  // Jika ada parameter, gunakan parameter
  if (userKey != null && userKey.isNotEmpty) {
    return userKey.length > 20 ? '${userKey.substring(0, 20)}...' : userKey;
  }
  
  // Jika tidak ada parameter, ambil dari _currentUser
  final keyFromUser = _currentUser['user_key']?.toString() ?? 
                     _currentUser['token']?.toString() ?? 
                     'Tidak tersedia';
  
  return keyFromUser.length > 20 ? '${keyFromUser.substring(0, 20)}...' : keyFromUser;
}

// ✅ FIX: BUILD ACTION BUTTONS HORIZONTAL BERPAPINGAN
Widget _buildActionButtons() {
  print('🔘 ActionButtons building - Horizontal layout');
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        // EDIT PROFILE BUTTON - 48% width
        Expanded(
          flex: 48,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : () {
              print('✏️ Edit profile tapped');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    user: _currentUser,
                    onProfileUpdated: (updatedData) {
                      setState(() {
                        _currentUser = {..._currentUser, ...updatedData};
                      });
                      widget.onProfileUpdated?.call();
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text(
              'Edit Profil',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        // SPACER - 4% width
        const Expanded(flex: 4, child: SizedBox(width: 8)),
        
        // LOGOUT BUTTON - 48% width  
        Expanded(
          flex: 48,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text(
              'Keluar',
              style: TextStyle(
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

// ✅ HELPER: BUILD INFO TILE YANG LEBIH SAFE
Widget _buildInfoTile(IconData icon, String label, String? value, {int maxLines = 1}) {
  final displayValue = value ?? '-';
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green[600], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayValue,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // ✅ HELPER: BUILD PROGRESS STEP
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
                ? const Icon(Icons.check, color: Colors.white, size: 16)
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

// ✅ FIX: GET PROFILE IMAGE DENGAN ROBUST ERROR HANDLING
ImageProvider? _getProfileImage() {
  try {
    final fotoDiri = _currentUser['foto_diri'];
    print('🖼️ Loading profile image: $fotoDiri');
    
    // ✅ VALIDASI LEBIH KETAT
    if (fotoDiri == null || 
        fotoDiri.toString().isEmpty || 
        fotoDiri == 'uploaded' ||
        (!fotoDiri.toString().contains('.jpg') && 
         !fotoDiri.toString().contains('.jpeg') && 
         !fotoDiri.toString().contains('.png'))) {
      print('🖼️ No valid profile image found, using placeholder');
      return null;
    }
    
    // ✅ BUILD FULL URL
    String imageUrl = fotoDiri.toString();
    if (!imageUrl.startsWith('http')) {
      imageUrl = 'http://demo.bsdeveloper.id/upload/foto_diri/$imageUrl';
    }
    
    // ✅ VALIDASI URL
    if (!_isValidUrl(imageUrl)) {
      print('❌ Invalid image URL: $imageUrl');
      return null;
    }
    
    // ✅ CACHE BUSTING DENGAN RANDOM UNTUK MEMASTIKAN REFRESH
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 1000;
    final cacheBustedUrl = '$imageUrl?t=${timestamp}_$random';
    
    print('🖼️ Profile image URL with cache busting: $cacheBustedUrl');
    
    // ✅ RETURN NETWORK IMAGE DENGAN COMPLETE ERROR HANDLING
    return NetworkImage(
      cacheBustedUrl,
      headers: {
        'Accept': 'image/jpeg, image/png, image/jpg, image/*',
        'Cache-Control': 'no-cache',
      },
    );
    
  } catch (e) {
    print('❌ Error loading profile image: $e');
    return null;
  }
}

// ✅ METHOD BARU: VALIDASI URL
bool _isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.isAbsolute && 
           (uri.scheme == 'http' || uri.scheme == 'https') &&
           uri.host.isNotEmpty;
  } catch (e) {
    return false;
  }
}

// ✅ FIX: GET PROFILE PLACEHOLDER YANG LEBIH AKURAT
Widget? _getProfilePlaceholder() {
  final fotoDiri = _currentUser['foto_diri'];
  
  if (fotoDiri == null || 
      fotoDiri.toString().isEmpty || 
      fotoDiri == 'uploaded' ||
      (!fotoDiri.toString().contains('.jpg') && 
       !fotoDiri.toString().contains('.jpeg') && 
       !fotoDiri.toString().contains('.png'))) {
    return Icon(Icons.person, size: 60, color: Colors.green[700]);
  }
  return null;
}

  // ✅ HELPER: FORMAT TANGGAL LAHIR
  String? _formatTanggalLahir(String? tanggalLahir) {
    if (tanggalLahir == null || tanggalLahir.isEmpty) return null;
    
    try {
      final parts = tanggalLahir.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return tanggalLahir;
    } catch (e) {
      return tanggalLahir;
    }
  }

  // ✅ HELPER: GET KOTA NAME
  String? _getKotaName(dynamic kotaId) {
    if (kotaId == null) return null;
    return kotaId.toString();
  }

  // ✅ HELPER: GET TAHUN GABUNG
  String _getTahunGabung() {
    final now = DateTime.now();
    return now.year.toString();
  }

  // ✅ COPY USER KEY TO CLIPBOARD
  void _copyUserKeyToClipboard(String userKey) {
    // Import 'package:flutter/services.dart' di atas
    Clipboard.setData(ClipboardData(text: userKey));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User key berhasil disalin ke clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    print('📋 User key copied to clipboard: ${userKey.substring(0, 10)}...');
  }

@override
Widget build(BuildContext context) {
  final isVerified = _isUserVerified;
  
  print('🎯 BUILD PROFILE - Status Debug:');
  print('   - Auth Status: $_authStatusUser');
  print('   - Final Status: $_finalStatusUser → Verified: $isVerified');
  
  _debugAllUserData();
  
  print('🔄 BUILD METHOD CALLED - _isLoading: $_isLoading, UserData: ${_currentUser.isNotEmpty}');
  print('   - username: ${_currentUser['username']}');
  print('   - nama: ${_currentUser['nama']}');
  print('   - email: ${_currentUser['email']}');

  if (_isLoading) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuat data profile...'),
          ],
        ),
      ),
    );
  }

  final hasUserData = _currentUser.isNotEmpty && 
                      (_currentUser['username'] != null || 
                       _currentUser['nama'] != null);

  if (!hasUserData) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Data profile tidak tersedia',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Silakan refresh atau login ulang',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
            ),
          ],
        ),
      ),
    );
  }

  return Scaffold(
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(70.0),
      child: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(bottom: 10.0),
          child: Text(
            'Profil Saya',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.green.withOpacity(0.5),
        shape: NotchedAppBarShape(),
        automaticallyImplyLeading: false,
        centerTitle: true,
        actions: [
          if (isVerified)
          IconButton(
            icon: _isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshProfile,
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
    ),
    body: SafeArea( // ✅ TAMBAH SafeArea DI SINI
      bottom: true, // ✅ PASTIKAN BOTTOM SafeArea AKTIF
      child: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only( // ✅ UPDATE PADDING
            left: 16,
            right: 16,
            top: 16,
            bottom: 80, // ✅ TAMBAH BOTTOM PADDING UNTUK NAVIGATION BAR
          ),
          child: Column(
            children: [
              _buildStatusRestrictionBanner(),

              if (_uploadError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
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
                        onPressed: () => setState(() => _uploadError = null),
                      ),
                    ],
                  ),
                ),
              ],

              _buildProfileHeader(),
              _buildUserStatusBanner(),
              const SizedBox(height: 16),

              if (!isVerified) _buildVerificationTimeline(),
              const SizedBox(height: 16),

              _buildPersonalInfoSection(),
              const SizedBox(height: 16),
              _buildKtpAddressSection(),
              const SizedBox(height: 16),
              _buildDomisiliAddressSection(),
              const SizedBox(height: 16),
              _buildCooperativeInfoSection(),
              const SizedBox(height: 16),

              // ✅ ACTION BUTTONS - SEKARANG PASTI KELIHATAN
              _buildActionButtons(),

              const SizedBox(height: 40), // ✅ TAMBAH EXTRA SPACE DI BAWAH
            ],
          ),
        ),
      ),
    ),
  );
}
}