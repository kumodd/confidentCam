import 'package:equatable/equatable.dart';

/// User entity representing the authenticated user.
class User extends Equatable {
  final String id;
  final String? phone;
  final String? email;
  final String? displayName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    this.phone,
    this.email,
    this.displayName,
    required this.createdAt,
    this.updatedAt,
  });

  User copyWith({
    String? id,
    String? phone,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, phone, email, displayName, createdAt, updatedAt];
}
