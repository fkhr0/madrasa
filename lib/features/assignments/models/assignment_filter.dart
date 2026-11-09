import 'assignment_model.dart';
import '../../../core/l10n/language.dart';

/// The chips at the top of the Assignments page.
enum AssignmentFilter {
  all,
  pending,
  submitted,
  graded;

  String get label {
    switch (this) {
      case AssignmentFilter.all:
        return tr('All');
      case AssignmentFilter.pending:
        return tr('To do');
      case AssignmentFilter.submitted:
        return tr('Submitted');
      case AssignmentFilter.graded:
        return tr('Graded');
    }
  }

  bool matches(AssignmentModel assignment) {
    switch (this) {
      case AssignmentFilter.all:
        return true;
      case AssignmentFilter.pending:
        return assignment.status == AssignmentStatus.pending;
      case AssignmentFilter.submitted:
        return assignment.status == AssignmentStatus.submitted;
      case AssignmentFilter.graded:
        return assignment.status == AssignmentStatus.graded;
    }
  }
}
