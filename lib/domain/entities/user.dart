import 'package:equatable/equatable.dart';

/// User entity representing the authenticated user.
class User extends Equatable {
  final String id;
  final String? phone;
  final String? displayName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.phone,
    this.displayName,
    required this.createdAt,
    this.updatedAt,
  });

  User copyWith({
    String? id,
    String? phone,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, phone, displayName, createdAt, updatedAt];
}
