import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/setup_flow_manager.dart';
import '../models/setup_step.dart';
import '../../patient/data/medical_info_remote_data_source.dart';
import '../../patient/models/medical_info.dart';
import '../../auth/data/auth_storage.dart';

class PatientProfileSetupStep extends StatefulWidget {
  const PatientProfileSetupStep({super.key});

  @override
  State<PatientProfileSetupStep> createState() =>
      _PatientProfileSetupStepState();
}

class _PatientProfileSetupStepState extends State<PatientProfileSetupStep>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _medicalNotesController = TextEditingController();

  bool _isFormValid = false;
  bool _isSaving = false;
  final List<String> _medicalConditions = [];
  final List<String> _allergies = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _setupFormListeners();
  }

  void _setupFormListeners() {
    void validateForm() {
      setState(() {
        _isFormValid =
            _nameController.text.trim().isNotEmpty &&
            _dobController.text.trim().isNotEmpty;
      });
    }

    _nameController.addListener(validateForm);
    _dobController.addListener(validateForm);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildBasicInfoSection(),
                const SizedBox(height: 24),
                _buildContactInfoSection(),
                const SizedBox(height: 24),
                _buildMedicalInfoSection(),
                const SizedBox(height: 32),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add_outlined, size: 32, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin bệnh nhân',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thiết lập hồ sơ cho người cần chăm sóc',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSection(
      title: 'Thông tin cơ bản',
      icon: Icons.badge_outlined,
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Họ và tên *',
          hint: 'Nhập họ tên đầy đủ',
          icon: Icons.person_outline,
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Vui lòng nhập họ tên';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                controller: _dobController,
                label: 'Ngày sinh *',
                hint: 'dd/MM/yyyy',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSection(
      title: 'Thông tin liên hệ',
      icon: Icons.contact_phone_outlined,
      children: [
        _buildTextField(
          controller: _phoneController,
          label: 'Số điện thoại',
          hint: 'Nhập số điện thoại',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _addressController,
          label: 'Địa chỉ',
          hint: 'Nhập địa chỉ hiện tại',
          icon: Icons.location_on_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emergencyContactController,
          label: 'Liên hệ khẩn cấp',
          hint: 'Số điện thoại người thân',
          icon: Icons.emergency_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildMedicalInfoSection() {
    return _buildSection(
      title: 'Thông tin y tế',
      icon: Icons.medical_services_outlined,
      children: [
        _buildTextField(
          controller: _medicalNotesController,
          label: 'Ghi chú y tế',
          hint: 'Tình trạng sức khỏe, thuốc đang dùng...',
          icon: Icons.notes_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildChipSection(
          title: 'Tình trạng bệnh lý',
          items: _medicalConditions,
          onAdd: _addMedicalCondition,
          onRemove: (item) => setState(() => _medicalConditions.remove(item)),
          placeholder: 'Thêm tình trạng bệnh lý',
        ),
        const SizedBox(height: 16),
        _buildChipSection(
          title: 'Dị ứng',
          items: _allergies,
          onAdd: _addAllergy,
          onRemove: (item) => setState(() => _allergies.remove(item)),
          placeholder: 'Thêm dị ứng',
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          controller.text =
              '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}';
        }
      },
      validator: (value) {
        if (value?.trim().isEmpty ?? true) {
          return 'Vui lòng chọn ngày sinh';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          Icons.calendar_today_outlined,
          color: Colors.grey.shade600,
        ),
        suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildChipSection({
    required String title,
    required List<String> items,
    required VoidCallback onAdd,
    required ValueChanged<String> onRemove,
    required String placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF374151),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Thêm'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: Text(
              placeholder,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Chip(
                label: Text(item),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => onRemove(item),
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                deleteIconColor: const Color(0xFF10B981),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isFormValid && !_isSaving) ? _savePatientProfile : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSaving ? Colors.grey : const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _isSaving ? 'Đang lưu...' : 'Lưu thông tin bệnh nhân',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _addMedicalCondition() {
    _showAddItemDialog(
      title: 'Thêm tình trạng bệnh lý',
      hint: 'Nhập tình trạng bệnh lý',
      onAdd: (value) {
        setState(() {
          _medicalConditions.add(value);
        });
      },
    );
  }

  void _addAllergy() {
    _showAddItemDialog(
      title: 'Thêm dị ứng',
      hint: 'Nhập tên chất gây dị ứng',
      onAdd: (value) {
        setState(() {
          _allergies.add(value);
        });
      },
    );
  }

  void _showAddItemDialog({
    required String title,
    required String hint,
    required ValueChanged<String> onAdd,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  onAdd(value);
                  Navigator.pop(context);
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
  }

  void _savePatientProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      try {
        // Get user ID
        final userId = await AuthStorage.getUserId();
        debugPrint('🔍 [PatientProfile] Checking user authentication...');
        debugPrint('🔍 [PatientProfile] Retrieved userId: $userId');

        if (userId == null || userId.trim().isEmpty) {
          debugPrint('❌ [PatientProfile] No user ID found in storage');

          // Check access token as well
          final accessToken = await AuthStorage.getAccessToken();
          debugPrint(
            '🔍 [PatientProfile] Access token exists: ${accessToken != null}',
          );
          if (accessToken != null) {
            debugPrint(
              '🔍 [PatientProfile] Access token length: ${accessToken.length}',
            );
            debugPrint(
              '🔍 [PatientProfile] Access token preview: ${accessToken.length > 20 ? accessToken.substring(0, 20) : accessToken}...',
            );
          }

          // Show error and don't proceed
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Không tìm thấy thông tin người dùng. Vui lòng đăng nhập lại.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Double check access token
        final accessToken = await AuthStorage.getAccessToken();
        if (accessToken == null || accessToken.trim().isEmpty) {
          debugPrint('❌ [PatientProfile] No access token found');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        debugPrint('✅ [PatientProfile] Authentication verified');
        debugPrint('✅ [PatientProfile] User ID: $userId');
        debugPrint(
          '✅ [PatientProfile] Access token length: ${accessToken.length}',
        );

        // Create patient info from form data
        final patientInfo = PatientInfo(
          name: _nameController.text.trim(),
          dob: _dobController.text.trim(),
          allergies: _allergies.isNotEmpty ? _allergies : null,
          chronicDiseases: _medicalConditions.isNotEmpty
              ? _medicalConditions
              : null,
        );

        debugPrint(
          '📝 [PatientProfile] Created patient info: ${patientInfo.name}',
        );
        debugPrint('📝 [PatientProfile] DOB: ${patientInfo.dob}');
        debugPrint('📝 [PatientProfile] Allergies: ${patientInfo.allergies}');
        debugPrint(
          '📝 [PatientProfile] Medical Conditions: ${patientInfo.chronicDiseases}',
        );

        // Create patient record from medical notes
        final patientRecord = PatientRecord(
          conditions: _medicalConditions,
          medications: [], // Not collected in setup
          history: _medicalNotesController.text.trim().isNotEmpty
              ? [_medicalNotesController.text.trim()]
              : [],
        );

        debugPrint(
          '📋 [PatientProfile] Created patient record with ${patientRecord.conditions.length} conditions',
        );
        debugPrint(
          '📋 [PatientProfile] Medical history entries: ${patientRecord.history.length}',
        );

        // Save patient profile to backend
        debugPrint('🌐 [PatientProfile] Attempting to save to backend...');
        final medicalApi = MedicalInfoRemoteDataSource();
        await medicalApi.upsertMedicalInfo(
          userId,
          patient: patientInfo,
          record: patientRecord,
        );

        debugPrint(
          '✅ [PatientProfile] Successfully saved patient profile to backend',
        );

        // Save emergency contact if provided
        if (_emergencyContactController.text.trim().isNotEmpty) {
          debugPrint('📞 [PatientProfile] Saving emergency contact...');
          await medicalApi.addContact(
            userId,
            name: _emergencyContactController.text.trim(),
            relation: 'Liên hệ khẩn cấp', // Default relation
            phone: _phoneController.text.trim(),
          );
          debugPrint('✅ [PatientProfile] Emergency contact saved successfully');
        }

        // Mark step as completed
        debugPrint('✅ [PatientProfile] Marking setup step as completed...');
        final ctx = context;
        final setupManager = ctx.read<SetupFlowManager>();
        setupManager.completeStep(SetupStepType.patientProfile);

        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu thông tin bệnh nhân thành công'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ [PatientProfile] Error saving patient profile: $e');
        debugPrint('❌ [PatientProfile] Error type: ${e.runtimeType}');
        if (e is Exception) {
          debugPrint('❌ [PatientProfile] Exception details: ${e.toString()}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi lưu thông tin: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }
}
