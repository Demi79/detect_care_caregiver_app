import 'package:flutter/material.dart';
import '../models/plan.dart';

class ComparisonTable extends StatelessWidget {
  final List<Plan> plans;
  const ComparisonTable({super.key, required this.plans});

  String _featureValue(Plan p, String key) {
    switch (key) {
      case 'cameraQuota':
        return '${p.cameraQuota}';
      case 'storageSize':
        return p.storageSize;
      case 'retentionDays':
        return '${p.retentionDays}';
      case 'caregiverSeats':
        return '${p.caregiverSeats}';
      case 'sites':
        return '${p.sites}';
      case 'majorUpdatesMonths':
        return '${p.majorUpdatesMonths}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['Camera', 'cameraQuota'],
      ['Lưu trữ (GB)', 'storageSize'],
      ['Retention (ngày)', 'retentionDays'],
      ['Caregiver seats', 'caregiverSeats'],
      ['Sites', 'sites'],
      ['Major updates (tháng)', 'majorUpdatesMonths'],
    ];

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade200),
            ),
            children: [
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Tính năng',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  for (final p in plans)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        r[0],
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    for (final p in plans)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_featureValue(p, r[1])),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
