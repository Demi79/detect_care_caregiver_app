import 'package:detect_care_caregiver_app/features/auth/providers/auth_provider.dart';
import 'package:detect_care_caregiver_app/features/emergency_contacts/data/emergency_contacts_remote_data_source.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UiEmergencyContact {
  final String id;
  final String name;
  final String relation;
  final String phone;
  final String level;
  final Color levelColor;

  UiEmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    required this.level,
    required this.levelColor,
  });

  UiEmergencyContact copyWith({
    String? id,
    String? name,
    String? relation,
    String? phone,
    String? level,
    Color? levelColor,
  }) => UiEmergencyContact(
    id: id ?? this.id,
    name: name ?? this.name,
    relation: relation ?? this.relation,
    phone: phone ?? this.phone,
    level: level ?? this.level,
    levelColor: levelColor ?? this.levelColor,
  );
}

int _levelToInt(String level) {
  switch (level) {
    case 'Ưu tiên cấp 2':
      return 2;
    default:
      return 1;
  }
}

String _intToLevel(int v) => 'Ưu tiên cấp ${v.clamp(1, 2)}';

Color _colorForLevel(String level) {
  switch (level) {
    case 'Ưu tiên cấp 2':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF06B6D4);
  }
}

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _loading = false;
  final _ds = EmergencyContactsRemoteDataSource();
  final List<UiEmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUserId;
    if (userId == null || userId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final list = await _ds.list(userId);
      if (!mounted) return;
      final ui = list.map((dto) {
        final lv = _intToLevel(dto.alertLevel);
        return UiEmergencyContact(
          id: dto.id,
          name: dto.name,
          relation: dto.relation,
          phone: dto.phone,
          level: lv,
          levelColor: _colorForLevel(lv),
        );
      }).toList();
      setState(() {
        _contacts
          ..clear()
          ..addAll(ui);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tải liên hệ thất bại: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddContactModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddContactModal(
        onSubmit: (dto) async {
          final userId = context.read<AuthProvider>().currentUserId;
          if (userId == null || userId.isEmpty) return;
          try {
            await _ds.create(userId, dto);
            if (!mounted) return;
            Navigator.pop(context);
            await _load();
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Đã thêm liên hệ')));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Thêm thất bại: $e')));
          }
        },
      ),
    );
  }

  void _showEditContactModal(UiEmergencyContact c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditContactModal(
        contact: c,
        onUpdate: (dto) async {
          final userId = context.read<AuthProvider>().currentUserId;
          if (userId == null || userId.isEmpty) return;
          try {
            await _ds.update(userId, c.id, dto);
            if (!mounted) return;
            Navigator.pop(context);
            await _load();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã cập nhật liên hệ')),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Cập nhật thất bại: $e')));
          }
        },
        onDelete: () async {
          final userId = context.read<AuthProvider>().currentUserId;
          if (userId == null || userId.isEmpty) return;
          try {
            await _ds.delete(userId, c.id);
            if (!mounted) return;
            Navigator.pop(context);
            await _load();
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Đã xoá liên hệ')));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Xoá thất bại: $e')));
          }
        },
      ),
    );
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF374151),
              size: 18,
            ),
          ),
        ),
        title: const Text(
          'Emergency Priority',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: IconButton(
              onPressed: _load,
              icon: const Icon(
                Icons.refresh,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              _buildWarningLevels(),
              const SizedBox(height: 28),
              _buildContactsSection(),
              if (_loading) const SizedBox(height: 16),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E7BF0).withValues(alpha: 0.05),
            const Color(0xFF06B6D4).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7BF0), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7BF0).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.emergency, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ưu tiên liên hệ khẩn cấp',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Quản lý danh sách ưu tiên liên hệ trong trường hợp khẩn cấp',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningLevels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cấp độ ưu tiên',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        _buildWarningLevel(
          icon: Icons.info_outline,
          color: const Color(0xFF06B6D4),
          level: 'Ưu tiên cấp 1',
          description: 'Liên hệ nhận thông báo khẩn cấp đầu tiên',
        ),
        const SizedBox(height: 12),
        _buildWarningLevel(
          icon: Icons.warning_amber,
          color: const Color(0xFFF59E0B),
          level: 'Ưu tiên cấp 2',
          description: 'Liên hệ được thông báo tiếp theo',
        ),
      ],
    );
  }

  Widget _buildWarningLevel({
    required IconData icon,
    required Color color,
    required String level,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Thông tin liên hệ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7BF0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2E7BF0).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                '${_contacts.length} liên hệ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7BF0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Quản lý thông tin liên lạc của những người chăm sóc đang tin cậy nhận được cảnh báo.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          _contacts.length,
          (index) => Padding(
            padding: EdgeInsets.only(
              bottom: index < _contacts.length - 1 ? 16 : 0,
            ),
            child: _buildContactCard(_contacts[index]),
          ),
        ),
        const SizedBox(height: 20),
        _buildAddContactButton(),
      ],
    );
  }

  Widget _buildContactCard(UiEmergencyContact c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.levelColor.withValues(alpha: 0.8), c.levelColor],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: c.levelColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.levelColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.levelColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        c.level,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.levelColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  c.relation,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      c.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.edit_outlined,
                color: const Color(0xFF2E7BF0),
                onPressed: () => _showEditContactModal(c),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.phone,
                color: const Color(0xFF10B981),
                onPressed: () => _callNumber(c.phone),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.message_outlined,
                color: const Color(0xFFF59E0B),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 18),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildAddContactButton() {
    final disabled = _contacts.length >= 2;

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: disabled
            ? const LinearGradient(colors: [Colors.grey, Colors.grey])
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E7BF0), Color(0xFF06B6D4)],
              ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7BF0).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton.icon(
        onPressed: disabled ? null : _showAddContactModal,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
        label: Text(
          disabled ? 'Tối đa 2 liên hệ' : 'Thêm người liên hệ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ----------------- Add / Edit modals -----------------

class AddContactModal extends StatefulWidget {
  final Future<void> Function(EmergencyContactDto dto) onSubmit;
  const AddContactModal({super.key, required this.onSubmit});

  @override
  State<AddContactModal> createState() => _AddContactModalState();
}

class _AddContactModalState extends State<AddContactModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relation = TextEditingController();

  String _level = 'Ưu tiên cấp 1';

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BaseContactSheet(
      title: 'Thêm người liên hệ mới',
      nameController: _name,
      phoneController: _phone,
      relationController: _relation,
      level: _level,
      onPickLevel: (lv) => setState(() => _level = lv),
      slideAnimation: _slideAnimation,
      primaryText: 'Thêm liên hệ',
      onPrimary: () async {
        if (!_formKey.currentState!.validate()) return;
        await widget.onSubmit(
          EmergencyContactDto(
            id: '',
            name: _name.text.trim(),
            relation: _relation.text.trim(),
            phone: _phone.text.trim(),
            alertLevel: _levelToInt(_level),
          ),
        );
      },
      formKey: _formKey,
    );
  }
}

class EditContactModal extends StatefulWidget {
  final UiEmergencyContact contact;
  final Future<void> Function(EmergencyContactDto dto) onUpdate;
  final Future<void> Function() onDelete;

  const EditContactModal({
    super.key,
    required this.contact,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<EditContactModal> createState() => _EditContactModalState();
}

class _EditContactModalState extends State<EditContactModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.contact.name,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.contact.phone,
  );
  late final TextEditingController _relation = TextEditingController(
    text: widget.contact.relation,
  );

  late String _level = widget.contact.level;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BaseContactSheet(
      title: 'Sửa người liên hệ',
      nameController: _name,
      phoneController: _phone,
      relationController: _relation,
      level: _level,
      onPickLevel: (lv) => setState(() => _level = lv),
      slideAnimation: _slideAnimation,
      primaryText: 'Lưu thay đổi',
      onPrimary: () async {
        if (!_formKey.currentState!.validate()) return;
        await widget.onUpdate(
          EmergencyContactDto(
            id: widget.contact.id,
            name: _name.text.trim(),
            relation: _relation.text.trim(),
            phone: _phone.text.trim(),
            alertLevel: _levelToInt(_level),
          ),
        );
      },
      secondaryText: 'Xoá',
      onSecondary: widget.onDelete,
      formKey: _formKey,
    );
  }
}

// ---------- shared bottom sheet UI ----------
class _BaseContactSheet extends StatelessWidget {
  final String title;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController relationController;
  final String level;
  final void Function(String) onPickLevel;
  final Animation<Offset> slideAnimation;
  final String primaryText;
  final Future<void> Function() onPrimary;
  final String? secondaryText;
  final Future<void> Function()? onSecondary;
  final GlobalKey<FormState> formKey;

  const _BaseContactSheet({
    required this.title,
    required this.nameController,
    required this.phoneController,
    required this.relationController,
    required this.level,
    required this.onPickLevel,
    required this.slideAnimation,
    required this.primaryText,
    required this.onPrimary,
    this.secondaryText,
    this.onSecondary,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    const levels = ['Ưu tiên cấp 1', 'Ưu tiên cấp 2'];

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return SlideTransition(
                position: slideAnimation,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2E7BF0),
                                    Color(0xFF06B6D4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Thông tin liên hệ',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // form
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _input(
                                  label: 'Tên người liên hệ',
                                  controller: nameController,
                                  icon: Icons.person_outline,
                                  validator: (v) => (v?.isEmpty ?? true)
                                      ? 'Vui lòng nhập tên'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                _input(
                                  label: 'Số điện thoại',
                                  controller: phoneController,
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => (v?.isEmpty ?? true)
                                      ? 'Vui lòng nhập số điện thoại'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                _input(
                                  label: 'Mối quan hệ',
                                  controller: relationController,
                                  icon: Icons.people_outline,
                                  validator: (v) => (v?.isEmpty ?? true)
                                      ? 'Vui lòng nhập mối quan hệ'
                                      : null,
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Cấp độ ưu tiên',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...levels.map(
                                  (lv) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: lv == levels.last ? 0 : 12,
                                    ),
                                    child: GestureDetector(
                                      onTap: () => onPickLevel(lv),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: (level == lv
                                              ? _colorForLevel(
                                                  lv,
                                                ).withValues(alpha: 0.1)
                                              : Colors.white),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: level == lv
                                                ? _colorForLevel(lv)
                                                : const Color(0xFFE2E8F0),
                                            width: level == lv ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _colorForLevel(
                                                  lv,
                                                ).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                level == lv
                                                    ? Icons.radio_button_checked
                                                    : Icons
                                                          .radio_button_unchecked,
                                                color: _colorForLevel(lv),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              lv,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: level == lv
                                                    ? _colorForLevel(lv)
                                                    : const Color(0xFF374151),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    if (onSecondary != null)
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: onSecondary,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFE2E8F0),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            secondaryText!,
                                            style: const TextStyle(
                                              color: Color(0xFFEF4444),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (onSecondary != null)
                                      const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: onPrimary,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          backgroundColor: const Color(
                                            0xFF2E7BF0,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          primaryText,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _input({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E7BF0), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
