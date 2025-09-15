// lib/bloc/drag_drop_state.dart

part of 'drag_drop_bloc.dart';

class DragDropState extends Equatable {
  final List<ColumnData> columns;
  final List<Connection> connections;
  final bool isViewMode;
  final Set<String> highlightedItemIds;
  final Set<Connection> highlightedConnections;

  const DragDropState({
    this.columns = const [],
    this.connections = const [],
    this.isViewMode = false,
    this.highlightedItemIds = const {},
    this.highlightedConnections = const {},
  });

  ColumnData get sourceColumn => columns.isNotEmpty ? columns.first : const ColumnData(id: 1, title: 'Nguồn');

  DragDropState copyWith({
    List<ColumnData>? columns,
    List<Connection>? connections,
    bool? isViewMode,
    Set<String>? highlightedItemIds,
    Set<Connection>? highlightedConnections,
  }) {
    return DragDropState(
      columns: columns ?? this.columns,
      connections: connections ?? this.connections,
      isViewMode: isViewMode ?? this.isViewMode,
      highlightedItemIds: highlightedItemIds ?? this.highlightedItemIds,
      highlightedConnections: highlightedConnections ?? this.highlightedConnections,
    );
  }

  @override
  List<Object> get props => [columns, connections, isViewMode, highlightedItemIds, highlightedConnections];
}