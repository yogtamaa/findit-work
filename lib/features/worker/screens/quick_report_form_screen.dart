import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../data/report_repository.dart';
import '../models/auto_fill_result.dart';
import '../theme/app_colors.dart';
import '../widgets/category_grid_selector.dart';
import '../widgets/photo_upload_card.dart';
import '../widgets/report_datetime_field.dart';
import '../widgets/report_text_field.dart';
import '../widgets/worker_header.dart';
import 'item_saved_success_screen.dart';

/// Form Pencatatan Lengkap barang temuan (Petugas / Room Attendant).
///
/// Alur:
/// 1. RA foto barang -> foto otomatis dikirim ke endpoint auto-fill
///    (`POST /reports/auto-fill`) yang sekaligus upload + analisis AI.
/// 2. Hasil AI dipakai sebagai DRAFT (bisa diedit), diberi badge
///    "Perlu dicek" bila confidence rendah / tidak lengkap.
/// 3. RA review, lalu submit ke `POST /reports`.
///
/// Foto kamera HP dikompres di sisi app (maxWidth 1600, quality 80)
/// supaya ukuran kirim kecil dan hemat data di jaringan koridor/basement.
class QuickReportFormScreen extends StatefulWidget {
  const QuickReportFormScreen({super.key, this.photoPath});

  /// Path foto awal opsional — bisa dari kamera sebelumnya.
  final String? photoPath;

  @override
  State<QuickReportFormScreen> createState() => _QuickReportFormScreenState();
}

class _QuickReportFormScreenState extends State<QuickReportFormScreen> {
  static const _fallbackCategories = [
    'Elektronik',
    'Dompet & Tas',
    'Pakaian',
    'Dokumen/ID',
    'Perhiasan/Jam',
    'Lainnya',
  ];

  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Foto & auto-fill
  late String? _photoPath = widget.photoPath;
  String? _photoUrl; // hasil upload (auto-fill atau fallback upload). JANGAN upload 2x.
  AutoFillResult? _autoFill; // hasil analisis AI (ada/draf vs kosong)
  bool _analyzing = false;
  double _uploadProgress = 0; // 0..1 fase upload foto ke auto-fill
  bool _submitting = false;
  double _submitUploadProgress = 0;

  List<String> _categories = _fallbackCategories;
  int _selectedCategory = 0;
  late DateTime _foundAt = DateTime.now();

  final _report = ReportRepository();
  final _auth = AuthRepository();
  String _staffName = '';

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndUser();
    if (widget.photoPath != null) {
      // Foto sudah ada dari screen sebelumnya -> langsung analisis.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onPhotoPicked(widget.photoPath!));
    }
  }

  Future<void> _loadCategoriesAndUser() async {
    try {
      final categories = await _report.getCategories();
      if (mounted && categories.isNotEmpty) {
        setState(() {
          _categories = categories.map((c) => c.name).toList();
        });
      }
    } catch (_) {
      // Pakai fallback statis bila jaringan gagal.
    }
    final user = await _auth.getStoredUser();
    if (mounted && user != null) _staffName = user.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roomCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil Foto', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      // Kompresi: maxWidth 1600 + quality 80 untuk memperkecil ukuran
      // sebelum dikirim (RA di koridor/basement, sinyal lemah).
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _photoPath = picked.path;
        _photoUrl = null;
        _autoFill = null;
      });
      await _onPhotoPicked(picked.path);
    } on Exception {
      // Kamera/galeri tidak tersedia — biarkan tanpa foto.
    }
  }

  /// Kirim foto ke auto-fill (upload + analisis AI). Bila gagal total,
  /// RA tetap bisa isi manual — foto diupload ulang saat submit bila perlu.
  Future<void> _onPhotoPicked(String path) async {
    setState(() {
      _analyzing = true;
      _uploadProgress = 0;
    });
    try {
      final result = await _report.autoFill(
        photoPath: path,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _uploadProgress = sent / total);
        },
      );
      if (!mounted) return;
      setState(() {
        _photoUrl = result.photoUrl; // foto sudah ter-upload di sini
        _autoFill = result;
        if (result.hasData) {
          if (result.title.isNotEmpty) _nameCtrl.text = result.title;
          if (result.description.isNotEmpty) _descCtrl.text = result.description;
          if (result.category.isNotEmpty) {
            final idx = _categories.indexWhere(
              (c) => c.toUpperCase() == result.category.trim().toUpperCase(),
            );
            if (idx >= 0) _selectedCategory = idx;
          }
        }
        _analyzing = false;
        _uploadProgress = 1;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _uploadProgress = 0;
      });
      _showMessage('Analisis gagal (${e.message}). Isi manual saja — foto akan diunggah saat disimpan.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _uploadProgress = 0;
      });
      _showMessage('Analisis foto gagal. Anda tetap bisa mengisi manual.');
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showMessage('Nama barang wajib diisi.');
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _submitUploadProgress = 0;
    });

    try {
      final room = _roomCtrl.text.trim();
      final location = room.isEmpty ? '' : 'Kamar $room';

      // FOTO HARUS UPLOAD TEPAT 1X:
      // - auto-fill sukses -> photo_url sudah ada, TIDAK upload ulang.
      // - auto-fill gagal total -> baru fallback ke POST /upload.
      var photoUrl = _photoUrl ?? '';
      if (photoUrl.isEmpty && _photoPath != null) {
        photoUrl = await _report.uploadPhotoAsFallback(
          photoPath: _photoPath!,
          onSendProgress: (sent, total) {
            if (!mounted || total <= 0) return;
            setState(() => _submitUploadProgress = sent / total);
          },
        );
      }

      final created = await _report.createReport(
        title: name,
        description: _descCtrl.text.trim(),
        category: _categories[_selectedCategory],
        roomNumber: room,
        location: location,
        photoUrl: photoUrl,
        itemDate: _foundAt,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ItemSavedSuccessScreen(
            item: created,
            staffName: _staffName,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan. Periksa koneksi dan coba lagi.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            WorkerHeader(
              showBack: true,
              subtitle: 'Form Pencatatan Lengkap',
              onBack: () => Navigator.pop(context),
              trailing: const WorkerBrandLogo(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  PhotoUploadCard(
                    photoPath: _photoPath,
                    onPick: _analyzing ? () {} : _pickPhoto,
                  ),
                  if (_analyzing) ...[
                    const SizedBox(height: 10),
                    _analyzingPanel(),
                  ] else if (_autoFill != null && _autoFill!.hasData) ...[
                    const SizedBox(height: 10),
                    _aiDraftPanel(),
                  ],
                  const SizedBox(height: 20),
                  ReportTextField(
                    label: 'Nama Barang',
                    hint: 'Contoh: Jam Tangan Pintar',
                    controller: _nameCtrl,
                  ),
                  const SizedBox(height: 20),
                  CategoryGridSelector(
                    categories: _categories,
                    selectedIndex: _selectedCategory,
                    onSelected: (i) => setState(() => _selectedCategory = i),
                  ),
                  const SizedBox(height: 20),
                  ReportTextField(
                    label: 'Nomor Kamar',
                    hint: 'Masukkan nomor kamar (misal: 314)',
                    controller: _roomCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.meeting_room_outlined, size: 20, color: AppColors.navy),
                  ),
                  const SizedBox(height: 20),
                  ReportDateTimeField(
                    value: _foundAt,
                    onChanged: (dt) => setState(() => _foundAt = dt),
                  ),
                  const SizedBox(height: 20),
                  ReportTextField(
                    label: 'Deskripsi / Catatan Tambahan',
                    hint: 'Contoh: Ditemukan di atas meja nakas sebelah kanan tempat tidur',
                    controller: _descCtrl,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 22),
                  _submitButton(),
                  if (_submitting && _submitUploadProgress > 0 && _submitUploadProgress < 1) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _submitUploadProgress,
                      color: AppColors.navy,
                      backgroundColor: AppColors.softBlueBg,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Panel saat foto sedang dianalisis: progress upload foto + status AI.
  Widget _analyzingPanel() {
    final progressText = _uploadProgress >= 1
        ? 'Menganalisis foto…'
        : 'Mengunggah foto ${(_uploadProgress * 100).round()}%…';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC6CFE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  progressText,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadProgress.clamp(0.0, 1.0),
            color: AppColors.yellow,
            backgroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  /// Panel hasil AI: badge "Perlu dicek" + hint confidence. Data tetap
  /// editable — RA wajib review sebelum submit.
  Widget _aiDraftPanel() {
    final ai = _autoFill!;
    final needsReview = ai.needsReview;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: needsReview ? const Color(0xFFFFF6E5) : const Color(0xFFEDFBF1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: needsReview ? const Color(0xFFF3C46B) : const Color(0xFF86D7A5)),
      ),
      child: Row(
        children: [
          Icon(
            needsReview ? Icons.error_outline : Icons.auto_awesome,
            size: 20,
            color: needsReview ? const Color(0xFFB45309) : AppColors.greenStrong,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needsReview ? 'Hasil AI — Perlu dicek' : 'Draf dari AI',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: needsReview ? const Color(0xFF92400E) : AppColors.greenStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Periksa kembali isian di bawah sebelum menyimpan.',
                  style: TextStyle(fontSize: 10.5, color: Colors.black54.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${ai.confidencePercent}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: needsReview ? const Color(0xFFB45309) : AppColors.greenStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navy),
              )
            : const Text(
                'Simpan & Laporkan Temuan ➔',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}