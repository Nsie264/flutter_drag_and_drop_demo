import 'package:equatable/equatable.dart';

class Connection extends Equatable {
  final String fromItemId;
  final String toItemId;

  const Connection({required this.fromItemId, required this.toItemId});

  @override
  List<Object?> get props => [fromItemId, toItemId];
}