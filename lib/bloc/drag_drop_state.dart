part of 'drag_drop_bloc.dart';

class DragDropState extends Equatable {
  // Danh sách mẫu, chứa tất cả các item có thể có với originalId của chúng
  final List<Item> masterItems;
  final List<ColumnData> columns;
  final int? multiSelectActiveColumnId;
  final Set<String> selectedItemIds;
  
  // Level bắt đầu để hiển thị (ví dụ: 1 -> hiển thị level 1 và 2)
  final int displayLevelStart; 

  const DragDropState({
    this.masterItems = const [],
    this.columns = const [],
    this.displayLevelStart = 1,
    this.multiSelectActiveColumnId,
    this.selectedItemIds = const {},
  });

  ColumnData get sourceColumn =>
      columns.isNotEmpty ? columns.first : const ColumnData(id: 1, title: 'Nguồn');

  DragDropState copyWith({
    List<Item>? masterItems,
    List<ColumnData>? columns,
    int? displayLevelStart,
    int? multiSelectActiveColumnId,
    Set<String>? selectedItemIds,
    bool clearMultiSelectColumn = false,
  }) {
    return DragDropState(
      masterItems: masterItems ?? this.masterItems,
      columns: columns ?? this.columns,
      displayLevelStart: displayLevelStart ?? this.displayLevelStart,
      multiSelectActiveColumnId: clearMultiSelectColumn ? null : multiSelectActiveColumnId ?? this.multiSelectActiveColumnId,
      selectedItemIds: selectedItemIds ?? this.selectedItemIds,
    );
  }

  @override
  List<Object?> get props => [masterItems, columns, displayLevelStart, multiSelectActiveColumnId, selectedItemIds];
}