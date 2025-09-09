import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:detect_care_caregiver_app/features/users/data/users_remote_data_source.dart';
import 'package:flutter/material.dart';

class PatientPickerScreen extends StatefulWidget {
  const PatientPickerScreen({super.key});

  @override
  State<PatientPickerScreen> createState() => _PatientPickerScreenState();
}

class _PatientPickerScreenState extends State<PatientPickerScreen> {
  final _searchController = TextEditingController();
  bool _loading = false;
  List<User> _items = const [];

  Future<void> _load({String? search}) async {
    setState(() => _loading = true);
    try {
      final ds = UsersRemoteDataSource();
      final list = await ds.listUsers(
        role: 'patient',
        search: search,
        limit: 50,
      );
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải bệnh nhân: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn bệnh nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await showSearch(
                context: context,
                delegate: _PatientSearchDelegate(
                  onQuery: (q) => _load(search: q),
                  items: _items,
                  onPick: (u) => Navigator.pop(context, u),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = _items[i];
                final display = u.fullName.isNotEmpty
                    ? u.fullName
                    : (u.phone.isNotEmpty ? u.phone : u.id);
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(display),
                  subtitle: Text('ID: ${u.id}'),
                  onTap: () => Navigator.pop(context, u),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Tìm theo tên/số điện thoại...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _load(search: _searchController.text.trim()),
            ),
          ),
          onSubmitted: (v) => _load(search: v.trim()),
        ),
      ),
    );
  }
}

class _PatientSearchDelegate extends SearchDelegate<User?> {
  final List<User> items;
  final void Function(String) onQuery;
  final void Function(User) onPick;
  _PatientSearchDelegate({
    required this.onQuery,
    required this.items,
    required this.onPick,
  });

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    onQuery(query);
    return const Center(child: Text('Đang tìm...'));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = items
        .where(
          (u) =>
              u.fullName.toLowerCase().contains(query.toLowerCase()) ||
              u.phone.toLowerCase().contains(query.toLowerCase()) ||
              u.id.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    if (filtered.isEmpty) return const Center(child: Text('Không có kết quả'));
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final u = filtered[i];
        final display = u.fullName.isNotEmpty
            ? u.fullName
            : (u.phone.isNotEmpty ? u.phone : u.id);
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(display),
          subtitle: Text('ID: ${u.id}'),
          onTap: () => onPick(u),
        );
      },
    );
  }
}
