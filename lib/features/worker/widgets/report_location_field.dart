import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Field text "Lokasi Ditemukan" untuk pencatatan barang temuan.
///
/// Mengikuti pola guest form (findit-react / `UserReportForm.jsx`):
/// input text bebas + chip quick-add di bawahnya yang menggunakan toggle
/// comma-separated — chip aktif meng-append/menghapus teks di field yang
/// sama, BUKAN pilihan single-select terpisah. Field ini OPSIONAL.
class ReportLocationField extends StatelessWidget {
  const ReportLocationField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.prefixIcon,
  });

  /// Chip quick-add, disamakan dengan `LOCATION_PILLS` di guest form.
  static const List<String> quickAdds = [
    'Di Meja Nakas',
    'Di Lemari Pakaian',
    'Di Kamar Mandi',
    'Bawah Ranjang',
  ];

  final String label;
  final String hint;
  final TextEditingController controller;
  final Widget? prefixIcon;

  List<String> _parts() => controller.text
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  void _toggle(String pill) {
    final parts = _parts();
    final value = parts.contains(pill)
        ? parts.where((p) => p != pill).join(', ')
        : [...parts, pill].join(', ');
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: const Color(0xFFF0F3FF),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final pill in quickAdds) _chip(label: pill, active: parts.contains(pill)),
          ],
        ),
      ],
    );
  }

  Widget _chip({required String label, required bool active}) {
    return GestureDetector(
      onTap: () => _toggle(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.navy : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ] else ...[
              Text(
                '+',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}