import 'package:flutter/material.dart';
import 'package:detect_care_caregiver_app/features/assignments/data/assignments_remote_data_source.dart';

class AssignmentListItem extends StatelessWidget {
  final Assignment assignment;
  final int index;
  final void Function(Assignment, int) onEditPermissions;
  final void Function(Assignment) onUnassign;

  const AssignmentListItem({
    super.key,
    required this.assignment,
    required this.index,
    required this.onEditPermissions,
    required this.onUnassign,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(assignment.caregiverName ?? assignment.caregiverId),
      subtitle: Text(assignment.caregiverPhone ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onEditPermissions(assignment, index),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () => onUnassign(assignment),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
