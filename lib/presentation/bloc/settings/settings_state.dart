import 'package:equatable/equatable.dart';

import '../../../domain/entities/settings.dart';

/// Settings BLoC States
abstract class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoadSuccess extends SettingsState {
  final Settings settings;
  const SettingsLoadSuccess(this.settings);
  @override
  List<Object?> get props => [settings];
}

class SettingsUpdating extends SettingsState {
  const SettingsUpdating();
}

class SettingsNotificationError extends SettingsState {
  final Settings settings;
  const SettingsNotificationError(this.settings);
  @override
  List<Object?> get props => [settings];
}

class SettingsError extends SettingsState {
  final String message;
  const SettingsError(this.message);
  @override
  List<Object?> get props => [message];
}
