import 'package:flutter/material.dart';

class ErrorMessageWidget extends StatelessWidget {
  final String? error;
  const ErrorMessageWidget({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    if (error == null) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text('Lỗi: $error', style: const TextStyle(color: Colors.red)),
    );
  }
}
