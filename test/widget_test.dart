import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:findit_worker/core/network/api_client.dart';
import 'package:findit_worker/core/security/token_storage.dart';
import 'package:findit_worker/features/auth/screens/login_screen.dart';
import 'package:findit_worker/features/worker/screens/quick_report_form_screen.dart';
import 'package:findit_worker/features/worker/widgets/worker_header.dart';
import 'package:findit_worker/features/worker/widgets/worker_profile_sheet.dart';
import 'package:findit_worker/main.dart';

/// Mock adapter untuk menggantikan HTTP sungguhan di seluruh flow test.
/// Mengembalikan JSON palsu sesuai path yang dipanggil Dio.
class _MockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final method = options.method.toUpperCase();

    if (path.endsWith('/login') && method == 'POST') {
      return ResponseBody.fromString(jsonEncode({
        'status': 'success',
        'message': 'Login berhasil',
        'data': {
          'token': 'test-mock-token-12345',
          'user': {
            'id': 1,
            'name': 'Siti Nurhaliza',
            'email': 'siti@grandmelia.co.id',
            'phone': '081234567890',
            'role': 'user',
          },
        },
      }), 200, headers: {'content-type': ['application/json']});
    }

    if (path.endsWith('/categories') && method == 'GET') {
      return ResponseBody.fromString(jsonEncode({
        'status': 'success',
        'message': 'Berhasil',
        'data': [
          {'id': 1, 'name': 'Elektronik'},
          {'id': 2, 'name': 'Dompet & Tas'},
          {'id': 3, 'name': 'Pakaian'},
          {'id': 4, 'name': 'Dokumen/ID'},
          {'id': 5, 'name': 'Perhiasan/Jam'},
          {'id': 6, 'name': 'Lainnya'},
        ],
      }), 200, headers: {'content-type': ['application/json']});
    }

    if (path.endsWith('/reports') && method == 'GET') {
      return ResponseBody.fromString(jsonEncode({
        'status': 'success',
        'message': 'Berhasil',
        'data': [],
      }), 200, headers: {'content-type': ['application/json']});
    }

    if (path.endsWith('/reports') && method == 'POST') {
      return ResponseBody.fromString(jsonEncode({
        'status': 'success',
        'message': 'Laporan berhasil dibuat',
        'data': {
          'id': 99,
          'report_identifier': 'FND-TEST-0001',
          'user_id': 1,
          'type': 'found',
          'title': 'Jam Tangan Pintar',
          'description': 'Di atas meja nakas',
          'category': 'Elektronik',
          'room_number': '314',
          'location': 'Kamar 314',
          'photo_url': '',
          'status': 'baru',
          'item_date': '2026-09-16T07:00:00Z',
          'created_at': '2026-09-16T07:00:00Z',
          'updated_at': '2026-09-16T07:00:00Z',
        },
      }), 201, headers: {'content-type': ['application/json']});
    }

    return ResponseBody.fromString('{}', 404, headers: {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'siti@grandmelia.co.id');
  await tester.enterText(find.byType(TextField).at(1), 'password123');
  await tester.tap(find.text('Masuk ➔'));
  await tester.pump();
  // pumpAndSettle di sini bisa timeout karena ada future async (secure storage).
  // Pump beberapa kali secara manual supaya frame-frame async selesai.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Map<String, String> storageData;

  setUp(() {
    storageData = <String, String>{};

    // Pastikan sesi volatile dari test sebelumnya tidak bocor ke test ini.
    TokenStorage.resetForTest();

    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'read':
            return storageData[(call.arguments as Map)['key'] as String];
          case 'write':
            final args = call.arguments as Map;
            storageData[args['key'] as String] = args['value'] as String;
            return null;
          case 'delete':
          case 'deleteAll':
            storageData.clear();
            return null;
          default:
            return null;
        }
      },
    );

    // Aktifkan mock Dio supaya seluruh flow tidak menyentuh jaringan.
    final mockDio = Dio(BaseOptions(
      baseUrl: 'https://mock-test.example.com',
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    ));
    mockDio.httpClientAdapter = _MockAdapter();
    ApiClient.testDio = mockDio;
  });

  tearDown(() {
    ApiClient.reset();
  });

  testWidgets('Worker app opens on login screen first', (WidgetTester tester) async {
    await tester.pumpWidget(const WorkerApp());
    // AuthGate mengecek sesi tersimpan secara async -> tunggu tuntas.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Login Petugas'), findsOneWidget);
    expect(find.text('Masuk ➔'), findsOneWidget);
    expect(find.text('+ Catat Barang Temuan'), findsNothing);
  });

  testWidgets('Auto-login ke Dashboard saat sesi "Ingat Saya" tersimpan', (WidgetTester tester) async {
    storageData['findit_jwt_token'] = 'saved-token-abc';
    storageData['findit_user_json'] = jsonEncode({
      'id': 1,
      'name': 'Siti Nurhaliza',
      'email': 'siti@grandmelia.co.id',
    });

    await tester.pumpWidget(const WorkerApp());
    await tester.pumpAndSettle();

    // Tanpa login ulang, langsung masuk ke dasbor petugas.
    expect(find.text('Login Petugas'), findsNothing);
    expect(find.text('+ Catat Barang Temuan'), findsOneWidget);
  });

  testWidgets('Login tanpa "Ingat Saya" tidak tersimpan setelah app ditutup', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const WorkerApp());
    await tester.pumpAndSettle();

    // Matikan "Ingat Saya" lalu login.
    await tester.enterText(find.byType(TextField).at(0), 'siti@grandmelia.co.id');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Masuk ➔'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('+ Catat Barang Temuan'), findsOneWidget);
    // Sesi tidak disimpan permanen -> secure storage tetap kosong.
    expect(storageData['findit_jwt_token'], isNull);
    expect(storageData['findit_user_json'], isNull);

    // Simulasi tutup & buka aplikasi lagi: harus minta login.
    TokenStorage.resetForTest(); // proses app restart -> RAM bersih
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const WorkerApp());
    await tester.pumpAndSettle();

    expect(find.text('Login Petugas'), findsOneWidget);
    expect(find.text('+ Catat Barang Temuan'), findsNothing);
  });

  testWidgets('Lupa Password opens reset info dialog and closes', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lupa Password?').first);
    await tester.pumpAndSettle();

    expect(find.text('Lupa Password?'), findsAtLeast(1));
    expect(find.text('Cara Reset'), findsOneWidget);
    expect(find.text('Tutup & Mengerti'), findsOneWidget);

    await tester.tap(find.text('Tutup & Mengerti'));
    await tester.pumpAndSettle();

    // Dialog tertutup — tombol "Tutup & Mengerti" sudah tidak ada.
    expect(find.text('Tutup & Mengerti'), findsNothing);
  });

  testWidgets('Full RA flow: login -> dashboard -> form -> submit -> success -> home', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Mock image_picker supaya pemilihan foto tidak jalan (tidak ada foto).
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/image_picker'),
      (call) async => null,
    );

    await tester.pumpWidget(const WorkerApp());
    await tester.pumpAndSettle();

    // 0) Login -> Worker Dashboard
    expect(find.text('Login Petugas'), findsOneWidget);
    await _login(tester);

    // Dashboard terlihat + header profil.
    expect(find.text('+ Catat Barang Temuan'), findsOneWidget);

    // Buka profil -> pastikan nama user dari mock tampil.
    await tester.tap(find.byType(WorkerHeaderAvatar));
    await tester.pumpAndSettle();
    expect(find.byType(WorkerProfileSheet), findsOneWidget);
    expect(find.text('Siti Nurhaliza'), findsOneWidget);

    // Tutup profil (jangan logout dulu, langsung ke form).
    await tester.tapAt(Offset.zero); // tap di luar sheet untuk menutup
    await tester.pumpAndSettle();

    // 1) Buka form Pencatatan
    await tester.tap(find.text('+ Catat Barang Temuan'));
    await tester.pumpAndSettle();

    // 2) Form terlihat + field utama ada
    expect(find.text('Nama Barang'), findsOneWidget);
    expect(find.text('Kategori Barang'), findsOneWidget);
    expect(find.text('Nomor Kamar'), findsOneWidget);

    // Isi field
    await tester.enterText(find.byType(TextField).at(0), 'Jam Tangan Pintar');
    await tester.enterText(find.byType(TextField).at(1), '314');
    await tester.enterText(find.byType(TextField).at(2), 'Di atas meja nakas');

    // Submit
    final submit = find.textContaining('Simpan & Laporkan Temuan');
    final formScrollable = find
        .descendant(
          of: find.byType(QuickReportFormScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(submit, 300, scrollable: formScrollable);
    await tester.tap(submit);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 3) Success screen tampil dengan data dari mock response
    expect(find.text('Barang Berhasil Tersimpan!'), findsOneWidget);
    expect(find.text('#FND-TEST-0001'), findsOneWidget);

    // 4) Kembali ke Beranda -> Dashboard
    await tester.tap(find.text('Kembali ke Beranda Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('+ Catat Barang Temuan'), findsOneWidget);
  });
}