import 'package:uuid/uuid.dart';

enum IssueType {
  brokenLight,
  noStreetLight,
  other
}

enum ReportStatus {
  pending,
  inspected,
  resolved
}

class Report {
  final String id;
  final String poleId; // Mocked from QR
  final IssueType issueType;
  final String description;
  final String location;
  final DateTime timestamp;
  ReportStatus status;

  Report({
    String? id,
    required this.poleId,
    required this.issueType,
    required this.description,
    required this.location,
    DateTime? timestamp,
    this.status = ReportStatus.pending,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();
}
