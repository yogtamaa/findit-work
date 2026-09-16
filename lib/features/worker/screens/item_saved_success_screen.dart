import 'dart:async';

import 'package:flutter/material.dart';

import '../models/found_item_model.dart';
import '../theme/app_colors.dart';
import '../widgets/auto_return_countdown.dart';
import '../widgets/item_saved_card.dart';
import '../widgets/saved_success_intro.dart';
import '../widgets/ticket_registration_card.dart';
import '../widgets/worker_header.dart';
import 'quick_report_form_screen.dart';

/// Layar sukses setelah barang tersimpan (Petugas - Item Saved).
///
/// Menampilkan tiket dari `report_identifier` backend dan detail barang
/// yang beneran tersimpan (nama, kategori, kamar, waktu, petugas), bukan
/// teks hardcoded.
class ItemSavedSuccessScreen extends StatefulWidget {
  const ItemSavedSuccessScreen({super.key, this.item, this.staffName = ''});

  /// Laporan yang baru dibuat di backend.
  final FoundItemModel? item;

  /// Nama petugas yang melapor (dari session login).
  final String staffName;

  @override
  State<ItemSavedSuccessScreen> createState() => _ItemSavedSuccessScreenState();
}

class _ItemSavedSuccessScreenState extends State<ItemSavedSuccessScreen> {
  Timer? _timer;
  int _seconds = 10;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds <= 0) {
        _timer?.cancel();
        _goHome();
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _copyTicket() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode tiket disalin!')),
    );
  }

  void _logAnother() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const QuickReportFormScreen()),
    );
  }

  String get _ticketNo {
    final id = widget.item?.reportIdentifier ?? '';
    return id.isEmpty ? '' : '#$id';
  }

  String get _timeLabel {
    final dt = widget.item?.foundDate ?? DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss WIB';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final staff = widget.staffName.isEmpty ? 'Petugas' : widget.staffName;
    final isClaimed = item?.isClaimed ?? false;
    final badge = item == null
        ? 'Barang Temuan'
        : [item.category, item.roomLabel].where((s) => s.isNotEmpty).join(' • ');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const WorkerHeader(showSearch: true, trailing: WorkerBrandLogo()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  const SavedSuccessIntro(),
                  const SizedBox(height: 16),
                  TicketRegistrationCard(ticketNo: _ticketNo, onCopy: _copyTicket),
                  const SizedBox(height: 14),
                  ItemSavedCard(
                    badge: badge,
                    title: item?.name ?? '',
                    description: item?.description ?? '',
                    location: item?.roomLabel ?? '',
                    timeValue: _timeLabel,
                    staffValue: staff,
                    statusText: isClaimed ? 'Sudah Diambil Tamu' : 'Menunggu Verifikasi Front Office',
                    statusPill: isClaimed ? 'Selesai' : 'Baru',
                  ),
                  const SizedBox(height: 16),
                  AutoReturnCountdown(seconds: _seconds, total: 10),
                  const SizedBox(height: 20),
                  _primaryButton(),
                  const SizedBox(height: 10),
                  _secondaryButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _goHome,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, size: 18, color: AppColors.navy),
            SizedBox(width: 8),
            Text(
              'Kembali ke Beranda Sekarang',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          backgroundColor: AppColors.softBlueBg,
          side: const BorderSide(color: Color(0xB3E4E9F7)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _logAnother,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined, size: 18, color: AppColors.navy),
            SizedBox(width: 8),
            Text(
              '+ Catat Barang Lainnya',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}