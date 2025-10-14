import 'package:detect_care_caregiver_app/features/assignments/screens/assignments_constants.dart';
import 'package:detect_care_caregiver_app/features/auth/models/user.dart';
import 'package:flutter/material.dart';

class SearchResultsList extends StatelessWidget {
  final List<User> searchResults;
  final Function(User) onAssign;

  const SearchResultsList({
    super.key,
    required this.searchResults,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    if (searchResults.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AssignmentsConstants.lightBlue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: AssignmentsConstants.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kết quả tìm kiếm (${searchResults.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AssignmentsConstants.darkBlue,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: 240,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: searchResults.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, i) {
                    final u = searchResults[i];
                    final title = u.fullName.isNotEmpty
                        ? u.fullName
                        : (u.username.isNotEmpty ? u.username : u.id);
                    final subtitle = [
                      if (u.email.isNotEmpty) u.email,
                      if (u.role.isNotEmpty) 'Role: ${u.role}',
                    ].join(' • ');

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AssignmentsConstants.accentBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AssignmentsConstants.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: AssignmentsConstants.primaryBlue,
                        ),
                      ),
                      onTap: () => onAssign(u),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
