part of 'drag_drop_bloc.dart';

class DragDropState extends Equatable {
  // Danh sách mẫu, chứa tất cả các item có thể có với originalId của chúng
  final List<Item> masterItems;
  final List<ColumnData> columns;
  
  // Level bắt đầu để hiển thị (ví dụ: 1 -> hiển thị level 1 và 2)
  final int displayLevelStart; 

  const DragDropState({
    this.masterItems = const [],
    this.columns = const [],
    this.displayLevelStart = 1,
  });

  ColumnData get sourceColumn =>
      columns.isNotEmpty ? columns.first : const ColumnData(id: 1, title: 'Nguồn');

  DragDropState copyWith({
    List<Item>? masterItems,
    List<ColumnData>? columns,
    int? displayLevelStart,
  }) {
    return DragDropState(
      masterItems: masterItems ?? this.masterItems,
      columns: columns ?? this.columns,
      displayLevelStart: displayLevelStart ?? this.displayLevelStart,
    );
  }

  @override
  List<Object> get props => [masterItems, columns, displayLevelStart];
}