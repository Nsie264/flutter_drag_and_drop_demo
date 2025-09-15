import 'package:drag_and_drop/models/item.dart';
import 'package:equatable/equatable.dart';

class ColumnData extends Equatable {
  final int id;
  final String title;
  final List<Item> items;

  const ColumnData({required this.id, required this.title, this.items = const []});

  ColumnData copyWith({
    int? id,
    String? title,
    List<Item>? items,
  }) {
    return ColumnData(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [id, title, items];
}