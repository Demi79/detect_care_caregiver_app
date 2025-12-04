import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';
import 'package:detect_care_caregiver_app/features/fcm/services/fcm_quick_send_controller.dart';

class FcmQuickSendSheet extends StatefulWidget {
  const FcmQuickSendSheet({super.key});

  @override
  State<FcmQuickSendSheet> createState() => _FcmQuickSendSheetState();
}

class _FcmQuickSendSheetState extends State<FcmQuickSendSheet> {
  final _msgCtl = TextEditingController();
  final _bg = const Color(0xFFF8FAFC);

  bool _loadingList = true;
  bool _sending = false;
  String _selected = '_ALL_';
  List<_CustomerOption> _customers = const [];

  late final FcmQuickSendController _controller;
  final _assignDs = AssignmentsRemoteDataSource();

  @override
  void initState() {
    super.initState();
    _controller = FcmQuickSendController.create();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = await _assignDs.listPending();
      final seen = <String>{};
      final opts = <_CustomerOption>[];
      for (final a in list) {
        if (a.status.toLowerCase() == 'accepted' && a.isActive) {
          if (seen.add(a.customerId)) {
            final display = (a.customerName?.trim().isNotEmpty == true)
                ? a.customerName!.trim()
                : (a.customerUsername?.trim().isNotEmpty == true
                      ? a.customerUsername!.trim()
                      : a.customerId.substring(0, 8));
            opts.add(_CustomerOption(id: a.customerId, name: display));
          }
        }
      }
      opts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _customers = opts;
        _loadingList = false;
      });
    } catch (e) {
      debugPrint('\u274c Lỗi tải khách hàng: $e');
      setState(() {
        _loadingList = false;
        _customers = [];
      });
    }
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final msg = _msgCtl.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập nội dung trước khi gửi')),
      );
      return;
    }
    final caregiverId = context.read<AuthProvider>().user!.id;

    setState(() => _sending = true);
    try {
      final resp = await _controller.sendMessage(
        caregiverId: caregiverId,
        message: msg,
        toCustomerId: _selected == '_ALL_' ? null : _selected,
      );
      final ok = (resp['successCount'] ?? 0).toString();
      final fail = (resp['failureCount'] ?? 0).toString();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gửi: $ok · Lỗi: $fail')));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gửi thông báo cho người nhà',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selected,
                items: [
                  const DropdownMenuItem(value: '_ALL_', child: Text('Tất cả')),
                  ..._customers.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: _loadingList
                    ? null
                    : (v) => setState(() => _selected = v ?? '_ALL_'),
                decoration: InputDecoration(
                  labelText: 'Người nhận',
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _msgCtl,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nội dung…',
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: Text(_sending ? 'Đang gửi…' : 'Gửi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerOption {
  final String id;
  final String name;
  const _CustomerOption({required this.id, required this.name});
}
