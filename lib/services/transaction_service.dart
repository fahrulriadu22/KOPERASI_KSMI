import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'file_validator.dart';

class TransactionService {
  static const String baseUrl = 'http://demo.bsdeveloper.id/api';
  
  final ApiService _apiService = ApiService();

  // ✅ UPLOAD BUKTI TRANSFER YANG BENAR - DIPERBAIKI
  Future<Map<String, dynamic>> uploadBuktiTransfer({
    required String transaksiId,
    required String jenisTransaksi,
    required String filePath,
  }) async {
    try {
      print('🚀 UPLOAD BUKTI TRANSFER START');
      print('📁 Transaksi ID: $transaksiId');
      print('📁 Jenis: $jenisTransaksi');
      print('📁 File path: $filePath');
      
      // ✅ VALIDASI FILE DENGAN FILE VALIDATOR
      final validation = await FileValidator.validateBuktiTransfer(filePath);
      if (!validation['valid']) {
        return {
          'success': false,
          'message': validation['message'],
          'error_code': validation['error_code']
        };
      }

      // ✅ GET HEADERS DARI API SERVICE
      final headers = await _apiService.getMultipartHeaders();
      print('📤 Headers: ${headers.keys}');

      // ✅ BUAT MULTIPART REQUEST
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/transaction/uploadBukti')
      );
      
      // ✅ PERBAIKAN: Set headers dengan benar (jangan pakai addAll)
      request.headers['DEVICE-ID'] = headers['DEVICE-ID'] ?? '12341231313131';
      request.headers['DEVICE-TOKEN'] = headers['DEVICE-TOKEN'] ?? '1234232423424';
      if (headers['x-api-key'] != null) {
        request.headers['x-api-key'] = headers['x-api-key']!;
      }
      
      // ✅ GUNAKAN FIELD NAME YANG BENAR
      String usedFieldName = 'bukti_transfer';
      
      try {
        request.files.add(await http.MultipartFile.fromPath(
          usedFieldName,
          filePath,
          filename: 'bukti_${jenisTransaksi}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
        print('✅ File bukti berhasil dilampirkan dengan field: $usedFieldName');
      } catch (e) {
        print('❌ Gagal dengan field $usedFieldName: $e');
        return {
          'success': false,
          'message': 'Gagal menambahkan file bukti ke request: $e'
        };
      }

      // ✅ TAMBAHKAN FORM FIELDS YANG DIPERLUKAN
      request.fields['transaksi_id'] = transaksiId;
      request.fields['jenis_transaksi'] = jenisTransaksi;
      
      // ✅ TAMBAHKAN USER DATA
      final currentUser = await _apiService.getCurrentUser();
      if (currentUser != null && currentUser['user_id'] != null) {
        request.fields['user_id'] = currentUser['user_id'].toString();
        print('✅ Added user_id: ${currentUser['user_id']}');
      } else {
        print('⚠️ User data not available');
      }

      print('📤 Request fields: ${request.fields}');
      print('📤 Files count: ${request.files.length}');

      // ✅ KIRIM REQUEST
      print('🔄 Mengirim request ke: $baseUrl/transaction/uploadBukti');
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
          // Bersihkan HTML tags dari error message
          String errorMessage = data['message'] ?? 'Upload bukti transfer gagal';
          errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
          
          return {
            'success': false,
            'message': errorMessage,
            'data': data
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
        String errorMessage = 'Server error ${response.statusCode}';
        try {
          final errorData = jsonDecode(responseBody);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'].toString();
            errorMessage = errorMessage.replaceAll(RegExp(r'<[^>]*>'), '');
          }
        } catch (e) {
          errorMessage = responseBody.length > 100 ? 
              responseBody.substring(0, 100) + '...' : responseBody;
        }
        
        return {
          'success': false,
          'message': errorMessage
        };
      }
    } catch (e) {
      print('❌ UPLOAD BUKTI TRANSFER ERROR: $e');
      return {
        'success': false,
        'message': 'Upload bukti transfer error: ${e.toString()}'
      };
    }
  }

  // ✅ CLEAR TOKEN
  Future<void> _clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      print('🔐 Token cleared due to expiration');
    } catch (e) {
      print('❌ Error clearing token: $e');
    }
  }

  // ✅ GET RIWAYAT TRANSAKSI - DIPERBAIKI
  Future<Map<String, dynamic>> getRiwayatTransaksi() async {
    try {
      final headers = await _apiService.getProtectedHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/getRiwayat'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      print('📡 Riwayat transaksi response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? [],
            'message': data['message'] ?? 'Berhasil mengambil riwayat transaksi'
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil riwayat transaksi',
            'data': []
          };
        }
      } else if (response.statusCode == 401) {
        await _clearToken();
        return {
          'success': false,
          'message': 'Sesi telah berakhir',
          'token_expired': true,
          'data': []
        };
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil riwayat transaksi: ${response.statusCode}',
          'data': []
        };
      }
    } catch (e) {
      print('❌ Get riwayat transaksi error: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'data': []
      };
    }
  }

  // ✅ METHOD BARU: Get saldo dan transaksi
  Future<Map<String, dynamic>> getSaldoDanTransaksi() async {
    try {
      final headers = await _apiService.getProtectedHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/transaction/getSaldoDanTransaksi'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? {},
            'message': data['message'] ?? 'Berhasil mengambil data saldo'
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil data saldo',
            'data': {}
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil data saldo: ${response.statusCode}',
          'data': {}
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'data': {}
      };
    }
  } 
}