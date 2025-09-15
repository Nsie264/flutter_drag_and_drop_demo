// lib/bloc/drag_drop_state.dart

part of 'drag_drop_bloc.dart';

class DragDropState extends Equatable {
  // Thay thế các list riêng lẻ bằng một list các cột
  final List<ColumnData> columns;
  final List<Connection> connections;

  const DragDropState({
    this.columns = const [],
    this.connections = const [],
  });

  // Tìm cột nguồn (luôn là cột đầu tiên)
  ColumnData get sourceColumn => columns.isNotEmpty ? columns.first : const ColumnData(id: 1, title: 'Nguồn');

  DragDropState copyWith({
    List<ColumnData>? columns,
    List<Connection>? connections,
  }) {
    return DragDropState(
      columns: columns ?? this.columns,
      connections: connections ?? this.connections,
    );
  }

  @override
  List<Object> get props => [columns, connections];
}