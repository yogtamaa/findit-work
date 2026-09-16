import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/network/api_config.dart';
import '../models/found_item_model.dart';
import '../theme/app_colors.dart';

/// Card barang temuan untuk daftar riwayat di Dashboard Petugas.
///
/// Menampilkan foto (lokal atau dari server), nama barang, badge status,
/// tag kategori, waktu relatif, dan ikon panah.
class FoundItemCard extends StatelessWidget {
  const FoundItemCard({super.key, required this.item, this.onTap});

  final FoundItemModel item;
  final VoidCallback? onTap;

  String _timeLabel() {
    final diff = DateTime.now().difference(item.foundDate);
    String rel;
    if (diff.inMinutes < 1) {
      rel = 'Baru saja';
    } else if (diff.inMinutes < 60) {
      rel = '${diff.inMinutes} mnt lalu';
    } else if (diff.inHours < 24) {
      rel = '${diff.inHours} jam lalu';
    } else {
      rel = '${diff.inDays} hari lalu';
    }
    final hh = item.foundDate.hour.toString().padLeft(2, '0');
    final mm = item.foundDate.minute.toString().padLeft(2, '0');
    return '$rel ($hh:$mm)';
  }

  Widget _thumbnail() {
    if (item.photoPath != null) {
      return Image.file(File(item.photoPath!), width: 64, height: 64, fit: BoxFit.cover);
    }
    final photoUrl = item.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        ApiConfig.resolve(photoUrl),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (_, child, progress) {
          return progress == null ? child : _placeholder();
        },
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFFE6ECF9),
      child: const Icon(Icons.inventory_2_outlined, color: AppColors.navy, size: 26),
    );
  }

  @override
  Widget build(BuildContext context) {
    final claimed = item.isClaimed;
    final statusBg = claimed ? AppColors.greenSoft : const Color(0xFFFFF0DC);
    final statusFg = claimed ? AppColors.greenStrong : const Color(0xFFB45309);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _thumbnail(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.roomLabel,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          item.statusLabel,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusFg),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.category.isNotEmpty) ...[
                        _tag(item.category, AppColors.softBlueBg, AppColors.navy),
                        const SizedBox(width: 6),
                      ],
                      _tag('Oleh Anda', const Color(0xFFF1F5F9), AppColors.ink),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeLabel(),
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}