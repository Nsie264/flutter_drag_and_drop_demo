// lib/bloc/drag_drop_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:drag_and_drop/models/column_data.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

part 'drag_drop_event.dart';
part 'drag_drop_state.dart';

class DragDropBloc extends Bloc<DragDropEvent, DragDropState> {
  final Uuid _uuid = const Uuid();

  final List<Item> _masterTemplateItems = [
    const Item(
      id: '1-00-00-000',
      originalId: '1-00-00-000',
      name: 'Yêu cầu',
      columnId: 0,
    ),
    const Item(
      id: '1-01-00-000',
      originalId: '1-01-00-000',
      name: 'Tạo Yêu cầu',
      columnId: 0,
    ),
    const Item(
      id: '1-02-00-000',
      originalId: '1-02-00-000',
      name: 'Sửa Yêu cầu',
      columnId: 0,
    ),
    const Item(
      id: '1-02-01-000',
      originalId: '1-02-01-000',
      name: 'Lưu thay đổi',
      columnId: 0,
    ),
    const Item(
      id: '2-00-00-000',
      originalId: '2-00-00-000',
      name: 'Phê duyệt',
      columnId: 0,
    ),
    const Item(
      id: '2-01-00-000',
      originalId: '2-01-00-000',
      name: 'Duyệt cấp 1',
      columnId: 0,
    ),
    const Item(
      id: '2-02-00-000',
      originalId: '2-02-00-000',
      name: 'Duyệt cấp 2',
      columnId: 0,
    ),
    const Item(
      id: '2-03-00-000',
      originalId: '2-03-00-000',
      name: 'Duyệt cấp 3',
      columnId: 0,
    ),
    const Item(
      id: '3-00-00-000',
      originalId: '3-00-00-000',
      name: 'Thực thi',
      columnId: 0,
    ),
  ];

  DragDropBloc() : super(const DragDropState()) {
    on<LoadItems>(_onLoadItems);
    on<ItemDropped>(_onItemDropped);
    on<LinkItemsRequested>(_onLinkItemsRequested);
    on<GroupItemsRequested>(_onGroupItemsRequested);
    on<RemoveItem>(_onRemoveItem);
    on<AddNewColumn>(_onAddNewColumn);
    on<RemoveColumn>(_onRemoveColumn);
    on<LevelFilterChanged>(_onLevelFilterChanged);
  }

  // Hàm helper để tìm tất cả con cháu của một item cha (dựa trên originalId)


  void _onLoadItems(LoadItems event, Emitter<DragDropState> emit) {
    final List<Item> initialSourceItems = [];
    final Map<String, String> parentInstanceIds = {};

    // PASS 1: Tạo các item cha (level 1)
    for (final template in _masterTemplateItems) {
      if (template.itemLevel == 1) {
        final newId = _uuid.v4();
        parentInstanceIds[template.originalId] = newId;
        initialSourceItems.add(template.copyWith(id: newId, columnId: 1));
      }
    }

    // PASS 2: Tạo các item con (level 2) và liên kết chúng với cha
    for (final template in _masterTemplateItems) {
      if (template.itemLevel == 2) {
        final parentOriginalId =
            '${template.originalId.split('-')[0]}-00-00-000';
        final parentId = parentInstanceIds[parentOriginalId];
        if (parentId != null) {
          initialSourceItems.add(
            template.copyWith(id: _uuid.v4(), columnId: 1, parentId: parentId),
          );
        }
      }
    }

    final initialColumns = [
      ColumnData(id: 1, title: 'Nguồn', items: initialSourceItems),
      const ColumnData(id: 2, title: 'Cột 2', items: []),
      const ColumnData(id: 3, title: 'Cột 3', items: []),
    ];

    emit(
      state.copyWith(
        masterItems: _masterTemplateItems,
        columns: initialColumns,
      ),
    );
  }

List<Item> _findAllInstanceDescendants(String parentInstanceId, List<Item> itemList) {
    final List<Item> descendants = [];
    final children = itemList.where((item) => item.parentId == parentInstanceId).toList();
    for (final child in children) {
      descendants.add(child);
      descendants.addAll(_findAllInstanceDescendants(child.id, itemList));
    }
    return descendants;
  }

  void _onItemDropped(ItemDropped event, Emitter<DragDropState> emit) {
        final item = event.item;
    final fromColumnId = item.columnId;
    final toColumnId = event.targetColumnId;

    if (fromColumnId >= toColumnId) return;

    List<ColumnData> updatedColumns = List.from(state.columns);
    final fromIndex = updatedColumns.indexWhere((c) => c.id == fromColumnId);
    final toIndex = updatedColumns.indexWhere((c) => c.id == toColumnId);
    if (fromIndex == -1 || toIndex == -1) return;
    

    final targetColumnToCheck = state.columns[toIndex];
    final isAlreadyInTarget = targetColumnToCheck.items.any((i) => i.originalId == item.originalId);

    if (isAlreadyInTarget) {
      debugPrint('BLoC: Bỏ qua ItemDropped vì item "${item.name}" (originalId: ${item.originalId}) đã tồn tại trong cột đích.');
      return; // Kết thúc hàm nếu đã tồn tại
    }

    final sourceColumn = updatedColumns[fromIndex];
    
    
    // ================== LOG BƯỚC 1: KIỂM TRA DỮ LIỆU ĐẦU VÀO ==================
    debugPrint('\n\n--- BƯỚC 1: KIỂM TRA DỮ LIỆU ĐẦU VÀO ---');
    debugPrint('Item được kéo: "${item.name}" (ID: ${item.id.substring(0,8)}...)');
    debugPrint('Toàn bộ item trong CỘT NGUỒN ("${sourceColumn.title}") TRƯỚC KHI XỬ LÝ:');
    for (final i in sourceColumn.items) {
        debugPrint('  - "${i.name}" (ID: ${i.id.substring(0,8)}, ParentID: ${i.parentId?.substring(0,8) ?? 'null'})');
    }

    final descendants = _findAllInstanceDescendants(item.id, sourceColumn.items);
    final List<Item> itemsToProcess = [item, ...descendants];
    
    // ================== LOG BƯỚC 2: KIỂM TRA DANH SÁCH ITEM CẦN XỬ LÝ ==================
    debugPrint('\n--- BƯỚC 2: DANH SÁCH ITEM CẦN XỬ LÝ (itemsToProcess) ---');
    for (final i in itemsToProcess) {
        debugPrint('  - "${i.name}" (ID: ${i.id.substring(0,8)}, ParentID: ${i.parentId?.substring(0,8) ?? 'null'})');
    }

    List<Item> newItemsForTargetColumn;
    
    final Map<String, String> oldIdToNewIdMap = {};
    for (final oldItem in itemsToProcess) {
      oldIdToNewIdMap[oldItem.id] = (fromColumnId == 1) ? oldItem.id : _uuid.v4();
    }

    newItemsForTargetColumn = itemsToProcess.map((oldItem) => oldItem.copyWith(
      id: oldIdToNewIdMap[oldItem.id],
      columnId: toColumnId,
      parentId: oldItem.parentId != null ? oldIdToNewIdMap[oldItem.parentId] : null,
    )).toList();
    
    // ================== LOG BƯỚC 3: KIỂM TRA CÁC ITEM MỚI SẼ ĐƯỢC THÊM VÀO CỘT ĐÍCH ==================
    debugPrint('\n--- BƯỚC 3: CÁC ITEM MỚI CHO CỘT ĐÍCH (newItemsForTargetColumn) ---');
    for (final i in newItemsForTargetColumn) {
        debugPrint('  - "${i.name}" (ID: ${i.id.substring(0,8)}, ParentID: ${i.parentId?.substring(0,8) ?? 'null'})');
    }

    if (fromColumnId == 1) { // Di chuyển từ Nguồn
        final itemIdsToRemove = itemsToProcess.map((i) => i.id).toSet();
        final updatedSourceItems = List<Item>.from(sourceColumn.items)
            ..removeWhere((i) => itemIdsToRemove.contains(i.id));
        updatedColumns[fromIndex] = sourceColumn.copyWith(items: updatedSourceItems);
    } else { // Sao chép từ cột khác
        final itemIdsToProcess = itemsToProcess.map((i) => i.id).toSet();

        final itemsToKeep = sourceColumn.items.where((i) => !itemIdsToProcess.contains(i.id)).toList();
        
        // ================== LOG BƯỚC 4A: KIỂM TRA DANH SÁCH ITEM GIỮ LẠI ==================
        debugPrint('\n--- BƯỚC 4A: DANH SÁCH ITEM GIỮ LẠI (itemsToKeep) ---');
        debugPrint('Số lượng: ${itemsToKeep.length}');

        final List<Item> updatedProcessedItems = [];
        for (int i = 0; i < itemsToProcess.length; i++) {
            final originalItem = itemsToProcess[i];
            final newItem = newItemsForTargetColumn[i];
            updatedProcessedItems.add(originalItem.copyWith(nextItemId: newItem.id));
        }

        // ================== LOG BƯỚC 4B: KIỂM TRA DANH SÁCH ITEM ĐÃ CẬP NHẬT ==================
        debugPrint('\n--- BƯỚC 4B: DANH SÁCH ITEM ĐÃ CẬP NHẬT (updatedProcessedItems) ---');
        for (final i in updatedProcessedItems) {
            debugPrint('  - "${i.name}" (ID: ${i.id.substring(0,8)}, ParentID: ${i.parentId?.substring(0,8) ?? 'null'}, NextID: ${i.nextItemId?.substring(0,8)})');
        }

        final finalSourceItems = [...itemsToKeep, ...updatedProcessedItems];
        
        // ================== LOG BƯỚC 4C: KIỂM TRA DANH SÁCH CUỐI CÙNG CỦA CỘT NGUỒN ==================
        debugPrint('\n--- BƯỚC 4C: DANH SÁCH CUỐI CÙNG CHO CỘT NGUỒN (finalSourceItems) ---');
        for (final i in finalSourceItems) {
            debugPrint('  - "${i.name}" (ID: ${i.id.substring(0,8)}, ParentID: ${i.parentId?.substring(0,8) ?? 'null'})');
        }

        updatedColumns[fromIndex] = sourceColumn.copyWith(items: finalSourceItems);
    }
    
    final targetColumn = updatedColumns[toIndex];
    final List<Item> updatedTargetItems = [
      ...targetColumn.items,
      ...newItemsForTargetColumn,
    ];
    updatedColumns[toIndex] = targetColumn.copyWith(items: updatedTargetItems);
    // ... Khối DEBUG giữ nguyên ...
    final finalTargetColumnState = updatedColumns[toIndex];
    debugPrint('===================================================');
    debugPrint('DEBUG: STATE CỦA CỘT ĐÍCH SAU KHI THẢ ITEM (V3)');
    debugPrint('Cột: "${finalTargetColumnState.title}" (ID: ${finalTargetColumnState.id})');
    debugPrint('Tổng số item trong cột: ${finalTargetColumnState.items.length}');
    debugPrint('--- Chi tiết các item trong CỘT ĐÍCH ---');
    for (final i in finalTargetColumnState.items) {
      final shortId = i.id.substring(0, 8);
      final shortParentId = i.parentId?.substring(0, 8) ?? 'null';
      debugPrint('  - Item: "${i.name}" (level ${i.itemLevel})');
      debugPrint('    ID:       $shortId...');
      debugPrint('    ParentID: $shortParentId...');
    }
    debugPrint('---------------------------------------------------');
    final finalSourceColumnState = updatedColumns[fromIndex];
    debugPrint('DEBUG: STATE CỦA CỘT NGUỒN SAU KHI THẢ ITEM');
    debugPrint('Cột: "${finalSourceColumnState.title}" (ID: ${finalSourceColumnState.id})');
    debugPrint('Tổng số item trong cột: ${finalSourceColumnState.items.length}');
    debugPrint('--- Chi tiết các item trong CỘT NGUỒN ---');
    for (final i in finalSourceColumnState.items) {
      final shortId = i.id.substring(0, 8);
      final shortParentId = i.parentId?.substring(0, 8) ?? 'null';
      final shortNextId = i.nextItemId?.substring(0, 8) ?? 'null';
      debugPrint('  - Item: "${i.name}" (level ${i.itemLevel})');
      debugPrint('    ID:        $shortId...');
      debugPrint('    ParentID:  $shortParentId...');
      debugPrint('    NextItemID: $shortNextId...');
    }
    debugPrint('===================================================');

    emit(state.copyWith(columns: updatedColumns));
  }

  void _onGroupItemsRequested(GroupItemsRequested event, Emitter<DragDropState> emit) {
    final draggedItem = event.draggedItem;
    final targetItem = event.targetItem;
    
    final draggedParentPrefix = draggedItem.originalId.split('-')[0];
    final targetParentPrefix = targetItem.originalId.split('-')[0];

    if (draggedParentPrefix != targetParentPrefix) {
      return; 
    }

    final toColIndex = state.columns.indexWhere((c) => c.id == targetItem.columnId);
    if (toColIndex == -1) return;

    // *** LOGIC KIỂM TRA TRÙNG LẶP MỚI ***
    final targetColumnToCheck = state.columns[toColIndex];
    final isAlreadyInTarget = targetColumnToCheck.items.any((i) => i.originalId == draggedItem.originalId);

    if (isAlreadyInTarget) {
        debugPrint('BLoC: Bỏ qua GroupItemsRequested vì item "${draggedItem.name}" (originalId: ${draggedItem.originalId}) đã tồn tại trong cột đích.');
        return; // Kết thúc hàm nếu đã tồn tại
    }

    final parentTemplate = state.masterItems.firstWhere(
      (item) => item.originalId.startsWith(draggedParentPrefix) && item.itemLevel == 1,
      orElse: () => const Item(id: '', originalId: '', name: '', columnId: -1),
    );

    if (parentTemplate.columnId == -1) return;

    

    List<ColumnData> updatedColumns = List.from(state.columns);
    final fromColIndex = updatedColumns.indexWhere((c) => c.id == draggedItem.columnId);
    // final toColIndex = updatedColumns.indexWhere((c) => c.id == targetItem.columnId);
    if (fromColIndex == -1 || toColIndex == -1) return;

    final fromColumn = updatedColumns[fromColIndex];
    final toColumn = updatedColumns[toColIndex];
    
    final isParentAlreadyInColumn = toColumn.items.any((i) => i.originalId == parentTemplate.originalId);

    // Tạo một bản sao của item được kéo để đặt vào cột đích.
    final draggedItemCopy = draggedItem.copyWith(id: _uuid.v4());

    // Quy tắc: Di chuyển từ Nguồn (Cột 1), Sao chép từ các cột khác.
    if (draggedItem.columnId == 1) {
        // Hành động MOVE: Xóa item gốc khỏi cột nguồn.
        final updatedFromItems = List<Item>.from(fromColumn.items)
          ..removeWhere((i) => i.id == draggedItem.id);
        updatedColumns[fromColIndex] = fromColumn.copyWith(items: updatedFromItems);
    } else {
        // Hành động COPY: Cập nhật item gốc ở cột nguồn để nó có nextItemId.
        final List<Item> updatedFromItems = fromColumn.items.map((item) {
            if (item.id == draggedItem.id) {
                return item.copyWith(nextItemId: draggedItemCopy.id);
            }
            return item;
        }).toList();
        updatedColumns[fromColIndex] = fromColumn.copyWith(items: updatedFromItems);
    }

    // Xử lý Cột Đích
    List<Item> updatedToItems = List<Item>.from(toColumn.items);

    if (isParentAlreadyInColumn) {
      final parentInTarget = toColumn.items.firstWhere((i) => i.originalId == parentTemplate.originalId);
      updatedToItems.add(draggedItemCopy.copyWith(
        columnId: targetItem.columnId,
        parentId: parentInTarget.id,
      ));
    } else {
      final newParentInstance = parentTemplate.copyWith(id: _uuid.v4(), columnId: targetItem.columnId);
      final updatedTargetItem = targetItem.copyWith(parentId: newParentInstance.id);
      final finalDraggedItemCopy = draggedItemCopy.copyWith(columnId: targetItem.columnId, parentId: newParentInstance.id);
      
      updatedToItems
        ..removeWhere((i) => i.id == targetItem.id)
        ..add(newParentInstance)
        ..add(updatedTargetItem)
        ..add(finalDraggedItemCopy);

      final sourceColumnIndex = updatedColumns.indexWhere((c) => c.id == 1);
      if (sourceColumnIndex != -1) {
        final sourceColumn = updatedColumns[sourceColumnIndex];
        if (sourceColumn.items.any((i) => i.originalId == parentTemplate.originalId)) {
            final updatedSourceItems = List<Item>.from(sourceColumn.items)
              ..removeWhere((i) => i.originalId == parentTemplate.originalId);
            updatedColumns[sourceColumnIndex] = sourceColumn.copyWith(items: updatedSourceItems);
        }
      }
    }
    
    updatedColumns[toColIndex] = toColumn.copyWith(items: updatedToItems);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onLinkItemsRequested(
    LinkItemsRequested event,
    Emitter<DragDropState> emit,
  ) {
    List<ColumnData> updatedColumns = [];
    print('--- Bắt đầu xử lý LinkItemsRequested ---');
    for (final column in state.columns) {
      final newItems = column.items.map((item) {
        if (item.id == event.fromItemId) {
          return item.copyWith(nextItemId: event.toItemId);
        }
        return item;
      }).toList();
      updatedColumns.add(column.copyWith(items: newItems));
    }

    emit(state.copyWith(columns: updatedColumns));
  }

  void _onRemoveItem(RemoveItem event, Emitter<DragDropState> emit) {
    // Sẽ cần implement logic này sau
  }

  void _onAddNewColumn(AddNewColumn event, Emitter<DragDropState> emit) {
    if (state.columns.isEmpty) return;

    final newId =
        (state.columns.map((c) => c.id).reduce((a, b) => a > b ? a : b)) + 1;
    final newColumn = ColumnData(
      id: newId,
      title: 'Cột $newId',
      items: const [],
    );

    final updatedColumns = List<ColumnData>.from(state.columns)..add(newColumn);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onRemoveColumn(RemoveColumn event, Emitter<DragDropState> emit) {
    // Sẽ cần implement logic này sau
  }

  void _onLevelFilterChanged(
    LevelFilterChanged event,
    Emitter<DragDropState> emit,
  ) {
    emit(state.copyWith(displayLevelStart: event.newStartLevel));
  }
}
