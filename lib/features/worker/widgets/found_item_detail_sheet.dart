import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/network/api_config.dart';
import '../models/found_item_model.dart';

/// Modal bottom sheet detail barang temuan.
///
/// Mengembalikan `true` bila RA menandai barang sudah diambil tamu
/// (dan update ke backend sukses), selain itu `null`/`false`.
Future<bool?> showFoundItemDetail(
  BuildContext context, {
  required FoundItemModel item,
  required Future<bool> Function() onMarkClaimed,
}) async {
  const navy = Color(0xFF1E3A8A);
  final isClaimed = item.isClaimed;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),
                _photo(item),
                const SizedBox(height: 14),
                Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (item.category.isNotEmpty)
                      Chip(label: Text(item.category), backgroundColor: navy.withValues(alpha: 0.08)),
                    if (item.roomLabel.isNotEmpty)
                      Chip(label: Text(item.roomLabel), backgroundColor: Colors.grey.shade100),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow(Icons.location_on_outlined, 'Lokasi Ditemukan', item.location),
                if (item.reportIdentifier != null && item.reportIdentifier!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailRow(Icons.confirmation_number_outlined, 'No. Registrasi', item.reportIdentifier!),
                ],
                const SizedBox(height: 12),
                _detailRow(Icons.notes_outlined, 'Deskripsi', item.description),
                const SizedBox(height: 20),
                if (!isClaimed)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () async {
                        final ok = await onMarkClaimed();
                        if (ctx.mounted) Navigator.pop(ctx, ok);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Tandai Sudah Diambil Tamu'),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Barang sudah diambil tamu', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _photo(FoundItemModel item) {
  final photoPath = item.photoPath;
  if (photoPath != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(File(photoPath), height: 160, width: double.infinity, fit: BoxFit.cover),
    );
  }
  final photoUrl = item.photoUrl;
  if (photoUrl != null && photoUrl.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        ApiConfig.resolve(photoUrl),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _photoPlaceholder(),
        loadingBuilder: (_, child, progress) {
          return progress == null ? child : _photoPlaceholder();
        },
      ),
    );
  }
  return _photoPlaceholder();
}

Widget _photoPlaceholder() {
  return Container(
    height: 160,
    width: double.infinity,
    color: const Color(0xFFE6ECF9),
    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF00236F), size: 34),
  );
}

Widget _detailRow(IconData icon, String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF1E3A8A)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ],
  );
}