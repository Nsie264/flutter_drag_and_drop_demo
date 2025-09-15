import 'package:equatable/equatable.dart';

class Item extends Equatable {
  final String id; // ID duy nhất của instance này
  final String originalId; // ID của item gốc, để biết các item copy từ đâu
  final String name;
  final int columnId; 

  const Item({
    required this.id,
    required this.originalId,
    required this.name,
    required this.columnId,
  });

  Item copyWith({String? id, int? columnId}) {
    return Item(
      id: id ?? this.id,
      originalId: originalId,
      name: name,
      columnId: columnId ?? this.columnId,
    );
  }

  @override
  List<Object?> get props => [id, originalId, name, columnId];
}