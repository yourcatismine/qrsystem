class QrCode {
  final String id;
  final String poleId;
  final DateTime createdAt;

  QrCode({
    required this.id,
    required this.poleId,
    required this.createdAt,
  });

  factory QrCode.fromJson(Map<String, dynamic> json) {
    return QrCode(
      id: json['id'],
      poleId: json['pole_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pole_id': poleId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
