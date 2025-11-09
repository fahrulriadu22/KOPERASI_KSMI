// lib/screens/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'dashboard_main.dart';
import 'profile_screen.dart';
import 'upload_dokumen_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userData;
  int _userStatus = 0; // Default status 0

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null || token.isEmpty) {
        // Tidak ada token, redirect ke login
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoggedIn = false;
          });
        }
        return;
      }

      // Ada token, cek status user
      await _loadUserData();
      
    } catch (e) {
      print('❌ Auth check error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoggedIn = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      print('🔄 Loading user data for auth check...');
      
      // ✅ PRIORITAS: Ambil data lengkap dari getCompleteUserInfo
      final userResult = await _apiService.getCompleteUserInfo();
      
      if (userResult['success'] == true && userResult['data'] != null) {
        final userData = userResult['data'];
        
        // ✅ AMBIL STATUS USER DARI BERBAGAI SUMBER YANG MUNGKIN
        final userStatus = userData['status_user'] ?? 
                          userData['status'] ?? 
                          0; // Default 0 jika tidak ada
        
        print('🎯 User Status from complete data: $userStatus');
        
        if (mounted) {
          setState(() {
            _userData = userData;
            _userStatus = int.tryParse(userStatus.toString()) ?? 0;
            _isLoggedIn = true;
            _isLoading = false;
          });
        }
        return;
      }
      
      // ✅ FALLBACK: Coba getUserInfo API
      print('🔄 Fallback to getUserInfo API...');
      final userInfoResult = await _apiService.getUserInfo();
      
      if (userInfoResult['success'] == true && userInfoResult['data'] != null) {
        final userInfoData = userInfoResult['data'];
        
        final userStatus = userInfoData['status_user'] ?? 
                          userInfoData['status'] ?? 
                          0;
        
        print('🎯 User Status from getUserInfo: $userStatus');
        
        if (mounted) {
          setState(() {
            _userData = userInfoData;
            _userStatus = int.tryParse(userStatus.toString()) ?? 0;
            _isLoggedIn = true;
            _isLoading = false;
          });
        }
        return;
      }
      
      // ✅ FALLBACK: Cek data lokal
      final localUser = await _apiService.getCurrentUser();
      if (localUser != null) {
        final userStatus = localUser['status_user'] ?? 
                          localUser['status'] ?? 
                          0;
        
        print('🎯 User Status from local data: $userStatus');
        
        if (mounted) {
          setState(() {
            _userData = localUser;
            _userStatus = int.tryParse(userStatus.toString()) ?? 0;
            _isLoggedIn = true;
            _isLoading = false;
          });
        }
        return;
      }
      
      // ❌ Tidak ada data user yang valid
      throw Exception('No valid user data found');
      
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoggedIn = false;
        });
      }
    }
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _userData = null;
      _userStatus = 0;
    });
  }

  void _handleLoginSuccess(Map<String, dynamic> userData) {
    final userStatus = userData['status_user'] ?? 
                      userData['status'] ?? 
                      0;
    
    setState(() {
      _userData = userData;
      _userStatus = int.tryParse(userStatus.toString()) ?? 0;
      _isLoggedIn = true;
    });
  }

  // ✅ CEK STATUS DOKUMEN UNTUK NAVIGASI
  void _checkDokumenStatusAndNavigate() {
    if (_userData == null) return;
    
    try {
      print('📄 Checking document status for navigation...');
      
      final fotoKtp = _userData!['foto_ktp']?.toString() ?? '';
      final fotoKk = _userData!['foto_kk']?.toString() ?? '';
      final fotoDiri = _userData!['foto_diri']?.toString() ?? '';
      
      final bool hasKTP = fotoKtp.isNotEmpty && fotoKtp != 'uploaded' && fotoKtp != 'null';
      final bool hasKK = fotoKk.isNotEmpty && fotoKk != 'uploaded' && fotoKk != 'null';
      final bool hasFotoDiri = fotoDiri.isNotEmpty && fotoDiri != 'uploaded' && fotoDiri != 'null';
      
      final bool allDokumenUploaded = hasKTP && hasKK && hasFotoDiri;
      
      print('''
📄 Document Status Check:
  - KTP: $hasKTP ($fotoKtp)
  - KK: $hasKK ($fotoKk)  
  - Foto Diri: $hasFotoDiri ($fotoDiri)
  - All Complete: $allDokumenUploaded
  - User Status: $_userStatus
''');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (!allDokumenUploaded && _userStatus == 0) {
            print('📱 Navigating to UploadDokumenScreen (status 0, dokumen belum lengkap)');
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => UploadDokumenScreen(
                  user: _userData!,
                  onDocumentsComplete: () {
                    // Refresh data setelah upload dokumen
                    _loadUserData();
                  },
                ),
              ),
              (route) => false,
            );
          } else {
            // Biarkan logic utama handle berdasarkan status
            print('📱 Document check completed, using main auth logic');
          }
        }
      });
    } catch (e) {
      print('❌ Error checking document status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.green[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green[700]),
              const SizedBox(height: 16),
              Text(
                'Memeriksa status...',
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

    // ✅ JIKA BELUM LOGIN, TAMPILKAN LOGIN SCREEN
    if (!_isLoggedIn) {
      return LoginScreen(onLoginSuccess: _handleLoginSuccess);
    }

    // ✅ JIKA SUDAH LOGIN, CEK STATUS USER
    print('🎯 User Status: $_userStatus');
    
    // ✅ CEK DOKUMEN STATUS SETELAH LOGIN
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDokumenStatusAndNavigate();
    });
    
    // ✅ STATUS 0: HANYA PROFILE SCREEN
    if (_userStatus == 0) {
      print('🔒 User status 0 - Showing ProfileScreen only');
      return ProfileScreen(
        user: _userData!,
        onLogout: _handleLogout,
      );
    }
    
    // ✅ STATUS 1: DASHBOARD (FULL ACCESS)
    else if (_userStatus == 1) {
      print('🔓 User status 1 - Showing DashboardScreen');
      return DashboardMain(
        user: _userData!,
      );
    }
    
    // ✅ STATUS LAIN: DEFAULT KE PROFILE SCREEN
    else {
      print('⚠️ Unknown user status $_userStatus - Showing ProfileScreen');
      return ProfileScreen(
        user: _userData!,
        onLogout: _handleLogout,
      );
    }
  }
}