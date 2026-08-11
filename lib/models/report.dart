

enum IssueType {
  brokenLight,
  noStreetLight,
  other
}

enum ReportStatus {
  pending,
  inspected,
  resolved,
  approved,
  declined,
  ongoing,
  arrived
}

class Report {
  final String? id;
  final String userId;
  final String poleId; // Mocked from QR
  final IssueType issueType;
  final String description;
  final String location;
  final DateTime timestamp;
  ReportStatus status;
  String? assignedUnit;
  String? managementRemarks;

  Report({
    this.id,
    required this.userId,
    required this.poleId,
    required this.issueType,
    required this.description,
    required this.location,
    DateTime? timestamp,
    this.status = ReportStatus.pending,
    this.assignedUnit,
    this.managementRemarks,
  })  : timestamp = timestamp ?? DateTime.now();

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      userId: json['user_id'],
      poleId: json['pole_id'],
      issueType: IssueType.values.firstWhere((e) => e.name == json['issue_type'], orElse: () => IssueType.other),
      description: json['description'],
      location: json['location'],
      timestamp: DateTime.parse(json['created_at']),
      status: ReportStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReportStatus.pending,
      ),
      assignedUnit: json['assigned_unit'],
      managementRemarks: json['management_remarks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'pole_id': poleId,
      'issue_type': issueType.name,
      'description': description,
      'location': location,
      'status': status.name,
      'assigned_unit': assignedUnit,
      'management_remarks': managementRemarks,
    };
  }
}
