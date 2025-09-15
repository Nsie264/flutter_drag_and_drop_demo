// lib/bloc/drag_drop_bloc.dart

import 'dart:collection';

import 'package:bloc/bloc.dart';
import 'package:drag_and_drop/models/column_data.dart';
import 'package:drag_and_drop/models/connection.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

part 'drag_drop_event.dart';
part 'drag_drop_state.dart';

class DragDropBloc extends Bloc<DragDropEvent, DragDropState> {
  final Uuid _uuid = const Uuid();

  DragDropBloc() : super(const DragDropState()) {
    on<LoadItems>(_onLoadItems);
    on<ItemDropped>(_onItemDropped);
    on<RemoveItem>(_onRemoveItem);
    on<AddConnection>(_onAddConnection);
    on<AddNewColumn>(_onAddNewColumn);
    on<RemoveColumn>(_onRemoveColumn);
    on<ToggleViewMode>(_onToggleViewMode);
    on<HighlightChain>(_onHighlightChain);
    on<ClearHighlight>(_onClearHighlight);
  }

  Map<String, Set> _calculateHighlightChain(String startItemId, List<Connection> connections) {
    final itemsToHighlight = <String>{};
    final connectionsToHighlight = <Connection>{};
    final queue = Queue<String>();
    final visited = <String>{};

    queue.add(startItemId);
    visited.add(startItemId);

    while (queue.isNotEmpty) {
      final currentItemId = queue.removeFirst();
      itemsToHighlight.add(currentItemId);

      for (final connection in connections) {
        if (connection.fromItemId == currentItemId) {
          connectionsToHighlight.add(connection);
          if (!visited.contains(connection.toItemId)) {
            visited.add(connection.toItemId);
            queue.add(connection.toItemId);
          }
        }
        if (connection.toItemId == currentItemId) {
          connectionsToHighlight.add(connection);
          if (!visited.contains(connection.fromItemId)) {
            visited.add(connection.fromItemId);
            queue.add(connection.fromItemId);
          }
        }
      }
    }
    return {'items': itemsToHighlight, 'connections': connectionsToHighlight};
  }

  void _onLoadItems(LoadItems event, Emitter<DragDropState> emit) {
    final initialItems = List.generate(5, (index) {
      final id = _uuid.v4();
      return Item(id: id, originalId: id, name: 'Item ${index + 1}', columnId: 1);
    });
    
    final initialColumns = [
      ColumnData(id: 1, title: 'Nguồn', items: initialItems),
      const ColumnData(id: 2, title: 'Cột 2'),
      const ColumnData(id: 3, title: 'Cột 3'),
    ];

    emit(state.copyWith(columns: initialColumns, connections: []));
  }

  void _onItemDropped(ItemDropped event, Emitter<DragDropState> emit) {
    final item = event.item;
    final fromColumnId = item.columnId;
    final toColumnId = event.targetColumnId;
    if (fromColumnId == toColumnId) return;

    List<ColumnData> updatedColumns = List.from(state.columns);
    List<Connection> updatedConnections = List.from(state.connections);
    Set<String> updatedHighlightedItemIds = Set.from(state.highlightedItemIds);
    Set<Connection> updatedHighlightedConnections = Set.from(state.highlightedConnections);

    int fromIndex = updatedColumns.indexWhere((col) => col.id == fromColumnId);
    int toIndex = updatedColumns.indexWhere((col) => col.id == toColumnId);
    if (fromIndex == -1 || toIndex == -1) return;

    // Kiểm tra xem item được kéo có đang được highlight không.
    final bool wasHighlighted = state.highlightedItemIds.contains(item.id);

    // TRƯỜNG HỢP 1: HÀNH ĐỘNG SAO CHÉP (COPY)
    if (fromColumnId > 1 && toColumnId > fromColumnId) {
      final newItem = item.copyWith(id: _uuid.v4(), columnId: toColumnId);
      final newConnection = Connection(fromItemId: item.id, toItemId: newItem.id);
      
      final targetColumn = updatedColumns[toIndex];
      updatedColumns[toIndex] = targetColumn.copyWith(items: List.from(targetColumn.items)..add(newItem));
      updatedConnections.add(newConnection);

      // Nếu item gốc được highlight, tự động highlight item mới và kết nối mới.
      if (wasHighlighted) {
        updatedHighlightedItemIds.add(newItem.id);
        updatedHighlightedConnections.add(newConnection);
      }
    } else { // TRƯỜNG HỢP 2: HÀNH ĐỘNG DI CHUYỂN (MOVE)
      final sourceColumn = updatedColumns[fromIndex];
      final targetColumn = updatedColumns[toIndex];
      
      final updatedSourceItems = List<Item>.from(sourceColumn.items)..removeWhere((i) => i.id == item.id);
      updatedColumns[fromIndex] = sourceColumn.copyWith(items: updatedSourceItems);
      
      final updatedTargetItems = List<Item>.from(targetColumn.items)..add(item.copyWith(columnId: toColumnId));
      updatedColumns[toIndex] = targetColumn.copyWith(items: updatedTargetItems);
    }
    
    emit(state.copyWith(
      columns: updatedColumns, 
      connections: updatedConnections,
      highlightedItemIds: updatedHighlightedItemIds,
      highlightedConnections: updatedHighlightedConnections,
    ));
  }
  
  void _onRemoveItem(RemoveItem event, Emitter<DragDropState> emit) {
    final itemToRemove = event.item;
    
    final bool wasHighlighted = state.highlightedItemIds.contains(itemToRemove.id);

    List<ColumnData> updatedColumns = List.from(state.columns);
    List<Connection> updatedConnections = List.from(state.connections)
      ..removeWhere((c) => c.fromItemId == itemToRemove.id || c.toItemId == itemToRemove.id);

    int columnIndex = updatedColumns.indexWhere((col) => col.id == itemToRemove.columnId);
    if (columnIndex == -1) return;

    // Bước 1: Xóa item khỏi cột hiện tại của nó
    final column = updatedColumns[columnIndex];
    final updatedItems = List<Item>.from(column.items)..removeWhere((i) => i.id == itemToRemove.id);
    updatedColumns[columnIndex] = column.copyWith(items: updatedItems);

    // Bước 2: Kiểm tra xem có cần trả item về nguồn không
    final otherInstancesExist = updatedColumns.skip(1).any((col) => col.items.any((i) => i.originalId == itemToRemove.originalId));
                              
    if (!otherInstancesExist) {
      final sourceColumn = state.sourceColumn;
      final isAlreadyInSource = sourceColumn.items.any((i) => i.originalId == itemToRemove.originalId);
      if (!isAlreadyInSource) {
        final originalItem = Item(
          id: itemToRemove.originalId, 
          originalId: itemToRemove.originalId, 
          name: itemToRemove.name, 
          columnId: 1
        );
        // Cập nhật danh sách item của cột nguồn một cách an toàn
        final currentSourceItems = List<Item>.from(updatedColumns[0].items);
        currentSourceItems.add(originalItem);
        updatedColumns[0] = updatedColumns[0].copyWith(items: currentSourceItems);
      }
    }
    // *** KẾT THÚC LOGIC CŨ ***

    // Bước 3: Xử lý highlight
    if (wasHighlighted) {
      // Xóa toàn bộ highlight nếu item bị xóa là một phần của chuỗi
      emit(state.copyWith(
        columns: updatedColumns, 
        connections: updatedConnections,
        highlightedItemIds: {},
        highlightedConnections: {},
      ));
    } else {
      // Nếu không, chỉ cập nhật cột và kết nối
      emit(state.copyWith(columns: updatedColumns, connections: updatedConnections));
    }
  }
  
  void _onAddConnection(AddConnection event, Emitter<DragDropState> emit) {
    // ... (logic từ câu trả lời trước, không đổi)
    final newConnections = List<Connection>.from(state.connections);
    if (newConnections.any((c) => c.fromItemId == event.fromItemId && c.toItemId == event.toItemId)) {
      return;
    }
    
    newConnections.add(Connection(fromItemId: event.fromItemId, toItemId: event.toItemId));
    
    final bool chainAffected = state.highlightedItemIds.contains(event.fromItemId) || 
                               state.highlightedItemIds.contains(event.toItemId);
    
    if (chainAffected) {
      final highlights = _calculateHighlightChain(event.fromItemId, newConnections);
      emit(state.copyWith(
        connections: newConnections,
        highlightedItemIds: highlights['items'] as Set<String>,
        highlightedConnections: highlights['connections'] as Set<Connection>,
      ));
    } else {
      emit(state.copyWith(connections: newConnections));
    }
  }
  void _onAddNewColumn(AddNewColumn event, Emitter<DragDropState> emit) {
    if (state.columns.isEmpty) return;
    
    final newId = (state.columns.map((c) => c.id).reduce((a, b) => a > b ? a : b)) + 1;
    final newColumn = ColumnData(id: newId, title: 'Cột $newId');
    
    final updatedColumns = List<ColumnData>.from(state.columns)..add(newColumn);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onRemoveColumn(RemoveColumn event, Emitter<DragDropState> emit) {
    if (event.columnId <= 1) return;

    List<ColumnData> updatedColumns = List.from(state.columns);
    int removeIndex = updatedColumns.indexWhere((col) => col.id == event.columnId);
    if (removeIndex == -1) return;

    final columnToRemove = updatedColumns[removeIndex];
    final itemsToReturn = columnToRemove.items;
    
    List<Connection> updatedConnections = List<Connection>.from(state.connections);
    final itemIdsToRemove = itemsToReturn.map((item) => item.id).toSet();
    updatedConnections.removeWhere((conn) => itemIdsToRemove.contains(conn.fromItemId) || itemIdsToRemove.contains(conn.toItemId));

    final sourceColumn = state.sourceColumn;
    final updatedSourceItems = List<Item>.from(sourceColumn.items);

    for (var item in itemsToReturn) {
      final otherInstancesExist = updatedColumns.where((c) => c.id != event.columnId && c.id > 1)
                                                .any((c) => c.items.any((i) => i.originalId == item.originalId));

      if (!otherInstancesExist && !updatedSourceItems.any((sourceItem) => sourceItem.originalId == item.originalId)) {
        updatedSourceItems.add(
          Item(id: item.originalId, originalId: item.originalId, name: item.name, columnId: 1)
        );
      }
    }
    
    updatedColumns[0] = sourceColumn.copyWith(items: updatedSourceItems);
    updatedColumns.removeAt(removeIndex);
    
    emit(state.copyWith(columns: updatedColumns, connections: updatedConnections));
  }

  void _onToggleViewMode(ToggleViewMode event, Emitter<DragDropState> emit) {
    emit(state.copyWith(
      isViewMode: !state.isViewMode,
      highlightedItemIds: {},
      highlightedConnections: {},
    ));
  }

  void _onClearHighlight(ClearHighlight event, Emitter<DragDropState> emit) {
    emit(state.copyWith(
      highlightedItemIds: {},
      highlightedConnections: {},
    ));
  }

  void _onHighlightChain(HighlightChain event, Emitter<DragDropState> emit) {
    if (state.highlightedItemIds.contains(event.itemId)) {
      add(ClearHighlight());
      return;
    }
    final highlights = _calculateHighlightChain(event.itemId, state.connections);
    emit(state.copyWith(
      highlightedItemIds: highlights['items'] as Set<String>,
      highlightedConnections: highlights['connections'] as Set<Connection>,
    ));
  }

}