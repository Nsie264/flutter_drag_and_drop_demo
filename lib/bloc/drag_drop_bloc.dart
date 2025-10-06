// lib/bloc/drag_drop_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:drag_and_drop/models/column_data.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

part 'drag_drop_event.dart';
part 'drag_drop_state.dart';

enum _MergeScenario { mergeIntoExisting, upgradeParent, createNew }

class DragDropBloc extends Bloc<DragDropEvent, DragDropState> {
  final Uuid _uuid = const Uuid();

  final List<Item> _defaultMasterTemplateItems = [
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
    on<MergeItemsRequested>(_onMergeItemsRequested);
    on<RemoveWorkflowItem>(_onRemoveWorkflowItem);
    on<LevelFilterChanged>(_onLevelFilterChanged);
    on<LoadItemsFromData>(_onLoadItemsFromData);
    on<UpgradeToPlaceholderRequested>(_onUpgradeToPlaceholderRequested);

    on<GroupDropped>(_onGroupDropped);
    on<MergeGroupRequested>(_onMergeGroupRequested);

    on<ToggleMultiSelectMode>(_onToggleMultiSelectMode);
    on<ItemSelectionChanged>(_onItemSelectionChanged);
    on<MultiSelectionDropped>(_onMultiSelectionDropped);

    on<AddNewColumn>(_onAddNewColumn);
    on<RemoveColumn>(_onRemoveColumn);

    on<HighlightChainRequested>(_onHighlightChainRequested);
  }

  void _onHighlightChainRequested(HighlightChainRequested event, Emitter<DragDropState> emit) {
    // Logic tắt highlight: Nếu item được click đã có trong chuỗi, xóa highlight.
    if (state.highlightedItemIds.contains(event.itemId)) {
      emit(state.copyWith(highlightedItemIds: {}));
      return;
    }

    final allItems = state.columns.expand((col) => col.items).toList();
    final Map<String, Item> itemsById = {for (var item in allItems) item.id: item};
    
    // --- BƯỚC 1: Xây dựng bản đồ các kết nối ngược (N-to-1) ---
    // Key: ID của item đích (toItem)
    // Value: Danh sách các ID của item nguồn (fromItem) trỏ đến nó.
    // Điều này cực kỳ quan trọng để xử lý trường hợp nhiều item con trỏ vào một placeholder.
    final Map<String, List<String>> previousItemsMap = {};
    for (final item in allItems) {
      if (item.nextItemId != null) {
        // Nếu key chưa tồn tại, tạo một list mới.
        // Nếu đã tồn tại, thêm id của item hiện tại vào list.
        previousItemsMap.putIfAbsent(item.nextItemId!, () => []).add(item.id);
      }
    }

    // --- BƯỚC 2: Thuật toán duyệt đồ thị (BFS) để tìm tất cả các nút kết nối ---
    final Set<String> visitedIds = {}; // Các ID đã duyệt để tránh lặp vô hạn
    final List<String> queue = [event.itemId]; // Hàng đợi bắt đầu với item được click
    visitedIds.add(event.itemId);

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0); // Lấy item đầu tiên từ hàng đợi
      final currentItem = itemsById[currentId];

      if (currentItem == null) continue;

      // 1. Duyệt xuôi dòng (Forward traversal)
      if (currentItem.nextItemId != null && !visitedIds.contains(currentItem.nextItemId!)) {
        visitedIds.add(currentItem.nextItemId!);
        queue.add(currentItem.nextItemId!);
      }

      // 2. Duyệt ngược dòng (Backward traversal) - Sử dụng bản đồ đã tạo
      // Điều này sẽ tự động xử lý trường hợp "hội tụ" vào placeholder.
      if (previousItemsMap.containsKey(currentId)) {
        for (final prevId in previousItemsMap[currentId]!) {
          if (!visitedIds.contains(prevId)) {
            visitedIds.add(prevId);
            queue.add(prevId);
          }
        }
      }
    }

    // Cập nhật state với toàn bộ đồ thị con đã được duyệt
    emit(state.copyWith(highlightedItemIds: visitedIds));
  }

  void _performMultiItemMerge(
    List<Item> itemsToMerge,
    Item targetItem,
    Emitter<DragDropState> emit,
  ) {
    if (itemsToMerge.isEmpty) return;

    final commonParentOriginalId = itemsToMerge.first.potentialParentOriginalId;
    final toColumnId = targetItem.columnId;

    debugPrint('\n\n\x1B[35m--- START [_performMultiItemMerge] --- \x1B[0m');
    debugPrint(
      '  \x1B[33mMerging ${itemsToMerge.length} items into Target:\x1B[0m "${targetItem.name}" (ID: ${targetItem.id.substring(0, 8)}) in Col $toColumnId',
    );
    debugPrint('  Common Parent Original ID: $commonParentOriginalId');

    List<ColumnData> updatedColumns = List.from(state.columns);
    final toColIndex = updatedColumns.indexWhere((c) => c.id == toColumnId);
    if (toColIndex == -1) return;

    final originalIdsToLink = itemsToMerge.map((i) => i.originalId).toSet();

    // =================================================================
    // KỊCH BẢN 1: Thả vào một "cha đại diện" (placeholder) đã tồn tại
    // =================================================================
    if (targetItem.isGroupPlaceholder &&
        targetItem.originalId == commonParentOriginalId) {
      debugPrint(
        '  \x1B[36mSCENARIO 1: Merging into an existing Placeholder.\x1B[0m',
      );

      // 1. Cập nhật placeholder ở cột đích
      var toColumn = updatedColumns[toColIndex];
      final updatedLinkedIds = {
        ...targetItem.linkedChildrenOriginalIds,
        ...originalIdsToLink,
      }.toList();
      final updatedPlaceholder = targetItem.copyWith(
        linkedChildrenOriginalIds: updatedLinkedIds,
      );

      final updatedToItems = toColumn.items
          .map((i) => i.id == targetItem.id ? updatedPlaceholder : i)
          .toList();
      updatedColumns[toColIndex] = toColumn.copyWith(items: updatedToItems);

      // 2. Cập nhật nextItemId cho TẤT CẢ các item nguồn
      final sourceItemIdsToUpdate = itemsToMerge.map((i) => i.id).toSet();
      for (var i = 0; i < updatedColumns.length; i++) {
        updatedColumns[i] = updatedColumns[i].copyWith(
          items: updatedColumns[i].items.map((item) {
            if (sourceItemIdsToUpdate.contains(item.id)) {
              return item.copyWith(nextItemId: targetItem.id);
            }
            return item;
          }).toList(),
        );
      }
    }
    // =================================================================
    // KỊCH BẢN 2: Thả vào một item "cha" để nâng cấp thành placeholder
    // =================================================================
    else if (!targetItem.isGroupPlaceholder &&
        targetItem.originalId == commonParentOriginalId) {
      debugPrint(
        '  \x1B[36mSCENARIO 2: Upgrading a Parent item to a Placeholder.\x1B[0m',
      );

      // 1. Đánh dấu cha ở Cột Nguồn là đã sử dụng
      updatedColumns = _markSourceItemAsUsed(
        targetItem.originalId,
        updatedColumns,
      );

      // 2. Nâng cấp item cha ở cột đích
      var toColumn = updatedColumns[toColIndex];
      final upgradedPlaceholder = targetItem.copyWith(
        isGroupPlaceholder: true,
        linkedChildrenOriginalIds: {
          ...targetItem.linkedChildrenOriginalIds,
          ...originalIdsToLink,
        }.toList(),
      );

      final updatedToItems = toColumn.items
          .map((i) => i.id == targetItem.id ? upgradedPlaceholder : i)
          .toList();
      updatedColumns[toColIndex] = toColumn.copyWith(items: updatedToItems);

      // 3. Cập nhật nextItemId cho TẤT CẢ các item nguồn
      final sourceItemIdsToUpdate = itemsToMerge.map((i) => i.id).toSet();
      for (var i = 0; i < updatedColumns.length; i++) {
        updatedColumns[i] = updatedColumns[i].copyWith(
          items: updatedColumns[i].items.map((item) {
            if (sourceItemIdsToUpdate.contains(item.id)) {
              return item.copyWith(nextItemId: targetItem.id);
            }
            return item;
          }).toList(),
        );
      }
    }
    // =================================================================
    // KỊCH BẢN 3: Thả vào một item "anh em" để "triệu hồi" placeholder
    // =================================================================
    else if (!targetItem.isGroupPlaceholder &&
        targetItem.potentialParentOriginalId == commonParentOriginalId) {
      debugPrint(
        '  \x1B[36mSCENARIO 3: Dropping onto a sibling item to summon a Placeholder.\x1B[0m',
      );

      final actualParentTemplate = _findActualParent(
        itemsToMerge.first,
        state.masterItems,
      );
      if (actualParentTemplate == null) return;

      // 1. Đánh dấu cha ở Cột Nguồn là đã sử dụng
      updatedColumns = _markSourceItemAsUsed(
        actualParentTemplate.originalId,
        updatedColumns,
      );

      // 2. Tạo placeholder mới
      final newPlaceholderId = _uuid.v4();
      final newPlaceholder = Item(
        id: newPlaceholderId,
        originalId: actualParentTemplate.originalId,
        name: actualParentTemplate.name,
        columnId: toColumnId,
        isGroupPlaceholder: true,
        linkedChildrenOriginalIds: {
          ...originalIdsToLink,
          targetItem.originalId,
        }.toList(),
      );

      // 3. Cập nhật cột đích: Xóa item đích, thêm placeholder
      var toColumn = updatedColumns[toColIndex];
      var updatedToItems = List<Item>.from(toColumn.items)
        ..removeWhere((i) => i.id == targetItem.id)
        ..add(newPlaceholder);
      updatedColumns[toColIndex] = toColumn.copyWith(items: updatedToItems);

      // 4. Tìm tất cả các ID nguồn cần cập nhật (của các item được kéo VÀ của item đích)
      final allSourceIdsToUpdate = itemsToMerge.map((i) => i.id).toSet();
      // Tìm nguồn của targetItem
      final allItems = updatedColumns.expand((col) => col.items).toList();
      final sourceOfTarget = allItems.firstWhere(
        (item) => item.nextItemId == targetItem.id,
        orElse: () => targetItem,
      );
      allSourceIdsToUpdate.add(sourceOfTarget.id);

      // 5. Cập nhật nextItemId cho TẤT CẢ các item nguồn liên quan
      for (var i = 0; i < updatedColumns.length; i++) {
        updatedColumns[i] = updatedColumns[i].copyWith(
          items: updatedColumns[i].items.map((item) {
            if (allSourceIdsToUpdate.contains(item.id)) {
              return item.copyWith(nextItemId: newPlaceholderId);
            }
            return item;
          }).toList(),
        );
      }
    } else {
      debugPrint('  \x1B[31mSCENARIO FAILED: Drop condition not met.\x1B[0m');
      return; // Không làm gì nếu không khớp kịch bản nào
    }

    _logAllColumnsState('PerformMultiItemMerge', updatedColumns);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onToggleMultiSelectMode(
    ToggleMultiSelectMode event,
    Emitter<DragDropState> emit,
  ) {
    // Nếu nhấn vào cột đã active -> tắt chế độ
    if (state.multiSelectActiveColumnId == event.columnId) {
      emit(
        state.copyWith(
          clearMultiSelectColumn: true, // Dùng flag để reset về null
          selectedItemIds: {}, // Xóa hết các item đã chọn
        ),
      );
    } else {
      // Nếu nhấn vào cột mới -> kích hoạt nó
      emit(
        state.copyWith(
          multiSelectActiveColumnId: event.columnId,
          selectedItemIds: {}, // Xóa lựa chọn cũ khi chuyển cột
        ),
      );
    }
  }

  void _onItemSelectionChanged(
    ItemSelectionChanged event,
    Emitter<DragDropState> emit,
  ) {
    final updatedSelection = Set<String>.from(state.selectedItemIds);
    if (event.isSelected) {
      updatedSelection.add(event.itemId);
    } else {
      updatedSelection.remove(event.itemId);
    }
    emit(state.copyWith(selectedItemIds: updatedSelection));
  }

  void _handleMultiDropToColumn(
    List<Item> itemsToDrop,
    int targetColumnId,
    Emitter<DragDropState> emit,
  ) {
    if (itemsToDrop.isEmpty) return;

    final fromColumnId = itemsToDrop.first.columnId;

    // Logic chặn cơ bản
    if (fromColumnId >= targetColumnId || fromColumnId == 0) {
      return;
    }

    List<ColumnData> updatedColumns = List.from(state.columns);
    final fromIndex = updatedColumns.indexWhere((c) => c.id == fromColumnId);
    final toIndex = updatedColumns.indexWhere((c) => c.id == targetColumnId);

    if (fromIndex == -1 || toIndex == -1) return;

    var sourceColumn = updatedColumns[fromIndex];
    var targetColumn = updatedColumns[toIndex];

    // Logic chống trùng lặp: Lấy tất cả originalId của các item sẽ được thêm vào
    final originalIdsToDrop = itemsToDrop.map((i) => i.originalId).toSet();
    // Nếu BẤT KỲ item nào đã tồn tại trong cột đích -> hủy toàn bộ hành động
    if (targetColumn.items.any(
      (item) => originalIdsToDrop.contains(item.originalId),
    )) {
      debugPrint(
        'BLoC: Bỏ qua MultiDrop vì có ít nhất một item đã tồn tại trong cột đích.',
      );
      return;
    }

    // Khai báo các biến sẽ được sử dụng
    List<Item> newItemsForTarget = [];

    // =======================================================================
    // KỊCH BẢN 1: KÉO TỪ CỘT NGUỒN (DI CHUYỂN LOGIC)
    // =======================================================================
    if (fromColumnId == 1) {
      final idsToMarkAsUsed = itemsToDrop.map((item) => item.id).toSet();

      // 1. Tạo các bản sao mới cho cột đích
      newItemsForTarget = itemsToDrop
          .map(
            (itemToClone) => itemToClone.copyWith(
              id: _uuid.v4(),
              columnId: targetColumnId,
              parentId: null,
              setNextItemIdToNull: true,
              isUsed: false, // Item ở cột làm việc không bao giờ "isUsed"
            ),
          )
          .toList();

      // 2. Cập nhật cột nguồn: Đánh dấu các item đã được kéo là "isUsed"
      final updatedSourceItems = sourceColumn.items.map((sourceItem) {
        if (idsToMarkAsUsed.contains(sourceItem.id)) {
          return sourceItem.copyWith(isUsed: true);
        }
        return sourceItem;
      }).toList();
      sourceColumn = sourceColumn.copyWith(items: updatedSourceItems);
    }
    // =======================================================================
    // KỊCH BẢN 2: KÉO TỪ CỘT LÀM VIỆC (SAO CHÉP VÀ VẼ MŨI TÊN)
    // =======================================================================
    else {
      final Map<String, String> oldIdToNewIdMap = {};

      // 1. Tạo các bản sao mới và map id cũ -> id mới
      for (final itemToClone in itemsToDrop) {
        final newItem = itemToClone.copyWith(
          id: _uuid.v4(),
          columnId: targetColumnId,
          parentId: null,
          setNextItemIdToNull: true,
          isGroupPlaceholder: false,
          linkedChildrenOriginalIds: [],
        );
        newItemsForTarget.add(newItem);
        oldIdToNewIdMap[itemToClone.id] = newItem.id;
      }

      // 2. Cập nhật cột nguồn: Cập nhật nextItemId cho các item gốc để vẽ mũi tên
      final updatedSourceItems = sourceColumn.items.map((item) {
        if (oldIdToNewIdMap.containsKey(item.id)) {
          return item.copyWith(nextItemId: oldIdToNewIdMap[item.id]);
        }
        return item;
      }).toList();
      sourceColumn = sourceColumn.copyWith(items: updatedSourceItems);
    }

    // Cập nhật cột đích: Thêm tất cả các item mới đã tạo
    final updatedTargetItems = List<Item>.from(targetColumn.items)
      ..addAll(newItemsForTarget);
    targetColumn = targetColumn.copyWith(items: updatedTargetItems);

    // Cập nhật danh sách cột và emit state mới
    updatedColumns[fromIndex] = sourceColumn;
    updatedColumns[toIndex] = targetColumn;

    _logAllColumnsState('MultiDropToColumn', updatedColumns);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onMultiSelectionDropped(
    MultiSelectionDropped event,
    Emitter<DragDropState> emit,
  ) {
    if (state.selectedItemIds.isEmpty) return;

    // Lấy danh sách các đối tượng Item đầy đủ từ ID đã chọn
    final List<Item> selectedItems = [];
    final allItems = state.columns.expand((col) => col.items).toList();
    for (String id in state.selectedItemIds) {
      // Dùng firstWhereOrNull từ collection package để an toàn hơn
      final item = allItems.firstWhere((i) => i.id == id);
      selectedItems.add(item);
    }

    if (selectedItems.isEmpty) return;

    final fromColumnId = selectedItems.first.columnId;

    // --- LOGIC PHÂN LOẠI VÀ GỌI HÀM HELPER ---

    // Kịch bản 1: Kéo từ Cột Nguồn (chỉ có thể thả vào nền cột)
    if (fromColumnId == 1) {
      if (event.targetItem == null) {
        _handleMultiDropToColumn(selectedItems, event.targetColumnId, emit);
      }
    }
    // Kịch bản 2: Kéo từ cột làm việc
    else {
      final firstParentId = selectedItems.first.potentialParentOriginalId;
      // Kiểm tra xem tất cả có cùng cha và cha đó có tồn tại không
      final bool areAllSiblings =
          firstParentId != null &&
          selectedItems.every(
            (item) => item.potentialParentOriginalId == firstParentId,
          );

      // 2a: Nhóm đồng nhất (cùng cha)
      if (areAllSiblings) {
        // Nếu thả vào nền cột
        if (event.targetItem == null) {
          _handleMultiDropToColumn(selectedItems, event.targetColumnId, emit);
        } else {
          _performMultiItemMerge(selectedItems, event.targetItem!, emit);
        }
      }
      // 2b: Nhóm không đồng nhất (khác cha)
      else {
        // Chỉ cho phép thả vào nền cột
        if (event.targetItem == null) {
          _handleMultiDropToColumn(selectedItems, event.targetColumnId, emit);
        }
        // Nếu thả vào item khác -> không làm gì cả
      }
    }

    // Luôn luôn dọn dẹp state chọn nhiều sau khi thả
    emit(state.copyWith(clearMultiSelectColumn: true, selectedItemIds: {}));
  }

  List<ColumnData> _markSourceItemAsUsed(
    String originalIdToMark,
    List<ColumnData> currentColumns,
  ) {
    var columns = List<ColumnData>.from(currentColumns);
    final sourceColIndex = columns.indexWhere((c) => c.id == 1);
    if (sourceColIndex == -1) return columns;

    var sourceColumn = columns[sourceColIndex];
    bool itemFoundAndMarked = false;

    final updatedSourceItems = sourceColumn.items.map((item) {
      if (item.originalId == originalIdToMark && !item.isUsed) {
        debugPrint(
          '    - Marking source item "${item.name}" (Original ID: $originalIdToMark) as used.',
        );
        itemFoundAndMarked = true;
        return item.copyWith(isUsed: true);
      }
      return item;
    }).toList();

    if (itemFoundAndMarked) {
      columns[sourceColIndex] = sourceColumn.copyWith(
        items: updatedSourceItems,
      );
    }
    return columns;
  }

  void _onGroupDropped(GroupDropped event, Emitter<DragDropState> emit) {
    final representativeItem = event.representativeItem;
    final fromColumnId = representativeItem.columnId;
    final toColumnId = event.targetColumnId;
    final parentOriginalId = representativeItem.potentialParentOriginalId;

    if (parentOriginalId == null || fromColumnId >= toColumnId) return;

    List<ColumnData> updatedColumns = List.from(state.columns);
    final fromIndex = updatedColumns.indexWhere((c) => c.id == fromColumnId);
    final toIndex = updatedColumns.indexWhere((c) => c.id == toColumnId);
    if (fromIndex == -1 || toIndex == -1) return;

    var sourceColumn = updatedColumns[fromIndex];
    var targetColumn = updatedColumns[toIndex];

    // 1. Tìm tất cả các item "anh em" khả dụng trong cột nguồn
    final itemsToMove = sourceColumn.items
        .where(
          (item) =>
              item.potentialParentOriginalId == parentOriginalId &&
              item.nextItemId == null,
        )
        .toList();

    if (itemsToMove.isEmpty) return;

    // Chống trùng lặp
    final originalIdsToMove = itemsToMove.map((i) => i.originalId).toSet();
    if (targetColumn.items.any(
      (i) => originalIdsToMove.contains(i.originalId),
    )) {
      return;
    }

    // 2. Tạo các bản sao mới và map id cũ -> id mới
    final Map<String, String> oldIdToNewIdMap = {};
    final List<Item> newItemsForTarget = [];

    for (final itemToClone in itemsToMove) {
      final newItem = itemToClone.copyWith(
        id: _uuid.v4(),
        columnId: toColumnId,
        parentId: null,
        setNextItemIdToNull: true,
      );
      newItemsForTarget.add(newItem);
      oldIdToNewIdMap[itemToClone.id] = newItem.id;
    }

    // 3. Cập nhật nextItemId cho các item gốc
    final updatedSourceItems = sourceColumn.items.map((item) {
      if (oldIdToNewIdMap.containsKey(item.id)) {
        return item.copyWith(nextItemId: oldIdToNewIdMap[item.id]);
      }
      return item;
    }).toList();

    sourceColumn = sourceColumn.copyWith(items: updatedSourceItems);

    // 4. Thêm các bản sao vào cột đích
    final updatedTargetItems = List<Item>.from(targetColumn.items)
      ..addAll(newItemsForTarget);
    targetColumn = targetColumn.copyWith(items: updatedTargetItems);

    // Cập nhật state
    updatedColumns[fromIndex] = sourceColumn;
    updatedColumns[toIndex] = targetColumn;
    _logAllColumnsState('GroupDropped', updatedColumns);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onMergeGroupRequested(
    MergeGroupRequested event,
    Emitter<DragDropState> emit,
  ) {
    final representativeItem = event.representativeItem;
    final targetItem = event.targetItem;
    final fromColumnId = representativeItem.columnId;
    final toColumnId = targetItem.columnId;
    final parentOriginalId = representativeItem.potentialParentOriginalId;

    // --- LOG BẮT ĐẦU ---
    debugPrint(
      '\n\n\x1B[35m================= START [_onMergeGroupRequested] =================\x1B[0m',
    );
    debugPrint('  \x1B[33m[1. DỮ LIỆU ĐẦU VÀO]\x1B[0m');
    debugPrint(
      '  - Group (Rep): "\x1B[36m${representativeItem.name}\x1B[0m" (ID: ${representativeItem.id.substring(0, 8)}) từ Cột $fromColumnId',
    );
    debugPrint(
      '  - Target Item: "\x1B[36m${targetItem.name}\x1B[0m" (ID: ${targetItem.id.substring(0, 8)}) tại Cột $toColumnId',
    );
    debugPrint('  - Parent Original ID chung: $parentOriginalId');

    if (parentOriginalId == null) {
      debugPrint(
        '\x1B[31m  LỖI: Không tìm thấy parentOriginalId. Dừng xử lý.\x1B[0m',
      );
      return;
    }

    List<ColumnData> updatedColumns = List.from(state.columns);
    final fromColIndex = updatedColumns.indexWhere((c) => c.id == fromColumnId);
    final toIndex = updatedColumns.indexWhere((c) => c.id == toColumnId);
    if (fromColIndex == -1 || toIndex == -1) return;

    var sourceColumn = updatedColumns[fromColIndex];
    var targetColumn = updatedColumns[toIndex];

    debugPrint(
      '\n  \x1B[33m[2. TÌM KIẾM ITEM NGUỒN TRONG CỘT $fromColumnId]\x1B[0m',
    );
    final itemsToMove = sourceColumn.items
        .where(
          (item) =>
              item.potentialParentOriginalId == parentOriginalId &&
              item.nextItemId == null,
        )
        .toList();

    if (itemsToMove.isEmpty) {
      debugPrint(
        '  \x1B[31mCẢNH BÁO: Không tìm thấy item nào khả dụng (chưa có nextItemId) trong group. Dừng xử lý.\x1B[0m',
      );
      return;
    }

    final originalIdsToMove = itemsToMove.map((i) => i.originalId).toList();
    debugPrint(
      '  \x1B[32m-> Tìm thấy ${itemsToMove.length} item khả dụng:\x1B[0m',
    );
    for (final item in itemsToMove) {
      debugPrint(
        '    - "\x1B[36m${item.name}\x1B[0m" (ID: ${item.id.substring(0, 8)}, nextItemId: ${item.nextItemId})',
      );
    }

    // =========================================================================
    // BƯỚC 3: PHÂN LOẠI KỊCH BẢN VÀ XỬ LÝ MỤC TIÊU
    // =========================================================================
    debugPrint('\n  \x1B[33m[3. PHÂN TÍCH KỊCH BẢN & XỬ LÝ CỘT ĐÍCH]\x1B[0m');
    String finalPlaceholderId;
    _MergeScenario scenario;
    String? targetSiblingSourceId;

    // KỊCH BẢN 1: Thả vào "cha đại diện" (placeholder) đã có
    if (targetItem.isGroupPlaceholder) {
      scenario = _MergeScenario.mergeIntoExisting;
      debugPrint('  \x1B[36mKỊCH BẢN 1: Gộp vào Placeholder đã có.\x1B[0m');
      finalPlaceholderId = targetItem.id;

      final originalLinkedIds = targetItem.linkedChildrenOriginalIds;
      final updatedLinkedIds = {
        ...originalLinkedIds,
        ...originalIdsToMove,
      }.toList();

      debugPrint('  - ID Placeholder: ${finalPlaceholderId.substring(0, 8)}');
      debugPrint('  - Linked IDs cũ: $originalLinkedIds');
      debugPrint('  - Linked IDs mới: $updatedLinkedIds');

      final updatedPlaceholder = targetItem.copyWith(
        linkedChildrenOriginalIds: updatedLinkedIds,
      );

      targetColumn = targetColumn.copyWith(
        items: targetColumn.items
            .map((i) => i.id == targetItem.id ? updatedPlaceholder : i)
            .toList(),
      );
    }
    // KỊCH BẢN 2: Thả vào "cha thường" để nâng cấp
    else if (targetItem.originalId == parentOriginalId) {
      scenario = _MergeScenario.upgradeParent;
      debugPrint(
        '  \x1B[36mKỊCH BẢN 2: Nâng cấp Item cha thành Placeholder.\x1B[0m',
      );
      finalPlaceholderId = targetItem.id;

      // *** LOGIC MỚI: ĐÁNH DẤU CHA Ở NGUỒN LÀ ĐÃ SỬ DỤNG ***
      updatedColumns = _markSourceItemAsUsed(
        targetItem.originalId,
        updatedColumns,
      );
      // ******************************************************

      final originalLinkedIds = targetItem.linkedChildrenOriginalIds;
      final updatedLinkedIds = {
        ...originalLinkedIds,
        ...originalIdsToMove,
      }.toList();

      debugPrint('  - Nâng cấp Item ID: ${finalPlaceholderId.substring(0, 8)}');
      debugPrint('  - Linked IDs cũ: $originalLinkedIds');
      debugPrint('  - Linked IDs mới: $updatedLinkedIds');

      final upgradedPlaceholder = targetItem.copyWith(
        isGroupPlaceholder: true,
        linkedChildrenOriginalIds: updatedLinkedIds,
      );

      targetColumn = targetColumn.copyWith(
        items: targetColumn.items
            .map((i) => i.id == targetItem.id ? upgradedPlaceholder : i)
            .toList(),
      );
    }
    // KỊCH BẢN 3: Thả vào "anh em" để tạo placeholder mới
    else {
      scenario = _MergeScenario.createNew;
      debugPrint(
        '  \x1B[36mKỊCH BẢN 3: Tạo Placeholder mới từ các "anh em".\x1B[0m',
      );

      final allItemsInWorkflow = updatedColumns
          .expand((col) => col.items)
          .toList();
      try {
        final sourceOfTarget = allItemsInWorkflow.firstWhere(
          (item) => item.nextItemId == targetItem.id,
        );
        targetSiblingSourceId = sourceOfTarget.id;
        debugPrint(
          '  - Tìm thấy nguồn của item đích: "\x1B[36m${sourceOfTarget.name}\x1B[0m" (ID: ${targetSiblingSourceId!.substring(0, 8)})',
        );
      } catch (e) {
        targetSiblingSourceId = targetItem.id;
        debugPrint(
          '  - Không tìm thấy nguồn, item đích tự là nguồn. (ID: ${targetSiblingSourceId!.substring(0, 8)})',
        );
      }

      final actualParentTemplate = _findActualParent(
        representativeItem,
        state.masterItems,
      );
      if (actualParentTemplate == null) return;

      final newPlaceholderId = _uuid.v4();
      finalPlaceholderId = newPlaceholderId;

      final allLinkedIds = {
        targetItem.originalId,
        ...originalIdsToMove,
      }.toList();

      debugPrint(
        '  - Tên cha chung: "\x1B[36m${actualParentTemplate.name}\x1B[0m"',
      );
      debugPrint(
        '  \x1B[32m- Tạo Placeholder MỚI ID: ${newPlaceholderId.substring(0, 8)}\x1B[0m',
      );
      debugPrint(
        '  - Xóa item đích: "\x1B[36m${targetItem.name}\x1B[0m" (ID: ${targetItem.id.substring(0, 8)})',
      );
      debugPrint('  - Tất cả ID được link: $allLinkedIds');

      final newPlaceholder = Item(
        id: newPlaceholderId,
        originalId: actualParentTemplate.originalId,
        name: actualParentTemplate.name,
        columnId: toColumnId,
        isGroupPlaceholder: true,
        linkedChildrenOriginalIds: allLinkedIds,
      );

      // *** LOGIC MỚI: ĐÁNH DẤU CHA Ở NGUỒN LÀ ĐÃ SỬ DỤNG ***
      updatedColumns = _markSourceItemAsUsed(
        actualParentTemplate.originalId,
        updatedColumns,
      );
      // ******************************************************

      targetColumn = targetColumn.copyWith(
        items: (List<Item>.from(targetColumn.items)
          ..removeWhere((i) => i.id == targetItem.id)
          ..add(newPlaceholder)),
      );
    }

    updatedColumns[toIndex] = targetColumn;

    // =========================================================================
    // BƯỚC 4: CẬP NHẬT nextItemId CHO TẤT CẢ CÁC ITEM NGUỒN
    // =========================================================================
    debugPrint(
      '\n  \x1B[33m[4. CẬP NHẬT nextItemId CHO CÁC ITEM NGUỒN]\x1B[0m',
    );
    debugPrint(
      '  - Tất cả sẽ trỏ tới ID: ${finalPlaceholderId.substring(0, 8)}',
    );

    final sourceItemIdsToUpdate = itemsToMove.map((i) => i.id).toSet();

    for (var i = 0; i < updatedColumns.length; i++) {
      bool columnWasUpdated = false;
      final List<Item> itemsAfterUpdate = updatedColumns[i].items.map((item) {
        String oldNextId = item.nextItemId?.substring(0, 8) ?? 'null';

        if (sourceItemIdsToUpdate.contains(item.id)) {
          columnWasUpdated = true;
          debugPrint(
            '  \x1B[32m-> Cập nhật Group Item:\x1B[0m "\x1B[36m${item.name}\x1B[0m" (ID: ${item.id.substring(0, 8)}). nextItemId: $oldNextId -> ${finalPlaceholderId.substring(0, 8)}',
          );
          return item.copyWith(nextItemId: finalPlaceholderId);
        }

        if (scenario == _MergeScenario.createNew &&
            targetSiblingSourceId == item.id) {
          columnWasUpdated = true;
          debugPrint(
            '  \x1B[32m-> Cập nhật Target Sibling Source:\x1B[0m "\x1B[36m${item.name}\x1B[0m" (ID: ${item.id.substring(0, 8)}). nextItemId: $oldNextId -> ${finalPlaceholderId.substring(0, 8)}',
          );
          return item.copyWith(nextItemId: finalPlaceholderId);
        }
        return item;
      }).toList();

      if (columnWasUpdated) {
        updatedColumns[i] = updatedColumns[i].copyWith(items: itemsAfterUpdate);
      }
    }

    // =========================================================================
    // BƯỚC 5: HOÀN TẤT VÀ EMIT STATE
    // =========================================================================
    debugPrint('\n  \x1B[33m[5. HOÀN TẤT]\x1B[0m');
    debugPrint(
      '\x1B[35m================= END [_onMergeGroupRequested] =================\x1B[0m\n',
    );
    _logAllColumnsState('MergeGroupRequested', updatedColumns);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _logAllColumnsState(String eventName, List<ColumnData> columns) {
    debugPrint(
      '\n\n\x1B[34m================= STATE UPDATED after [$eventName] =================\x1B[0m',
    );
    for (final column in columns) {
      debugPrint(
        '\x1B[32m--- Cột: "${column.title}" (ID: ${column.id}) | Số item: ${column.items.length} ---\x1B[0m',
      );
      if (column.items.isEmpty) {
        debugPrint('  (Trống)');
        continue;
      }
      for (final item in column.items) {
        final shortId = item.id.substring(0, 8);
        final shortParentId = item.parentId?.substring(0, 8) ?? 'null';
        final shortNextId = item.nextItemId?.substring(0, 8) ?? 'null';
        String itemType = item.isGroupPlaceholder
            ? '\x1B[33m(Placeholder)\x1B[0m'
            : '(Item)';

        debugPrint(
          '  - \x1B[36m"${item.name}"\x1B[0m Cấp ${item.itemLevel} $itemType',
        );
        debugPrint('    ID:        $shortId');
        debugPrint('    ParentID:  $shortParentId');
        debugPrint('    NextID:    $shortNextId');
        if (item.isGroupPlaceholder) {
          debugPrint(
            '    \x1B[33mLinkedChildren: ${item.linkedChildrenOriginalIds.length} -> ${item.linkedChildrenOriginalIds}\x1B[0m',
          );
        }
      }
    }
    debugPrint(
      '\x1B[34m========================= END STATE LOG =========================\x1B[0m\n',
    );
  }

  // ============== CÁC HÀM HELPER MỚI ==============

  /// Tìm cha thực sự của một item, áp dụng logic "tìm cha lùi".
  Item? _findActualParent(Item child, List<Item> masterList) {
    String? potentialParentId = child.potentialParentOriginalId;
    if (potentialParentId == null) return null;

    // Lặp để tìm tổ tiên gần nhất
    while (potentialParentId != null) {
      final parentIndex = masterList.indexWhere(
        (item) => item.originalId == potentialParentId,
      );
      if (parentIndex != -1) {
        return masterList[parentIndex]; // Tìm thấy
      }

      // Nếu không tìm thấy, thử tìm "ông"
      final grandParentId = Item(
        id: '',
        originalId: potentialParentId,
        name: '',
        columnId: 0,
      ).potentialParentOriginalId;
      potentialParentId = grandParentId;
    }
    return null; // Không tìm thấy tổ tiên nào
  }

  /// Lấy danh sách originalId của TẤT CẢ các con trực tiếp của một item cha.
  List<String> _getDirectChildrenOriginalIds(
    Item parent,
    List<Item> masterList,
  ) {
    return masterList
        .where((item) {
          if (item.originalId == parent.originalId) {
            return false;
          } // Bỏ qua chính nó
          final actualParent = _findActualParent(item, masterList);
          return actualParent?.originalId == parent.originalId;
        })
        .map((child) => child.originalId)
        .toList();
  }

  /// Kiểm tra xem một item cha đại diện đã hoàn chỉnh chưa.
  bool isGroupComplete(Item placeholder, List<Item> masterList) {
    if (!placeholder.isGroupPlaceholder) return true;

    final allChildrenIds = _getDirectChildrenOriginalIds(
      placeholder,
      masterList,
    );
    if (allChildrenIds.isEmpty) {
      return true;
    } // Cha không có con thì luôn hoàn chỉnh

    final linkedIds = placeholder.linkedChildrenOriginalIds.toSet();
    return listEquals(linkedIds.toList()..sort(), allChildrenIds..sort());
  }

  /// Tìm và đánh dấu một item và tất cả các tổ tiên của nó trong Cột Nguồn là isUsed: false.
  List<ColumnData> _revertIsUsedInSource(
    String originalIdToRevert,
    List<ColumnData> currentColumns,
  ) {
    var columns = List<ColumnData>.from(currentColumns);
    final sourceColIndex = columns.indexWhere((c) => c.id == 1);
    if (sourceColIndex == -1) return columns;

    var sourceColumn = columns[sourceColIndex];

    final itemToRevert = sourceColumn.items.firstWhere(
      (item) => item.originalId == originalIdToRevert,
      orElse: () => const Item(id: '-1', originalId: '', name: '', columnId: 0),
    );

    if (itemToRevert.id == '-1') return columns;

    final Set<String> idsToRevert = {itemToRevert.id};
    String? currentParentId = itemToRevert.parentId;

    // Lấy danh sách tất cả các item trong các cột làm việc để kiểm tra tham chiếu
    final workingItems = columns
        .where((c) => c.id > 1)
        .expand((c) => c.items)
        .toList();

    while (currentParentId != null) {
      final parent = sourceColumn.items.firstWhere(
        (item) => item.id == currentParentId,
        orElse: () =>
            const Item(id: '-1', originalId: '', name: '', columnId: 0),
      );

      if (parent.id != '-1') {
        // === LOGIC SỬA LỖI QUAN TRỌNG ===
        // Chỉ hồi sinh cha nếu không còn bản sao nào của nó trong các cột làm việc.
        final bool parentHasInstanceInWorkflow = workingItems.any(
          (item) => item.originalId == parent.originalId,
        );

        if (!parentHasInstanceInWorkflow) {
          idsToRevert.add(parent.id);
          currentParentId = parent.parentId;
        } else {
          // Nếu cha vẫn còn được sử dụng, dừng việc hồi sinh chuỗi
          debugPrint(
            '  Parent "${parent.name}" still has instances in workflow. Stopping revert chain.',
          );
          currentParentId = null;
        }
      } else {
        currentParentId = null;
      }
    }

    debugPrint('  Reverting isUsed status for IDs: $idsToRevert');

    final revertedSourceItems = sourceColumn.items.map((item) {
      if (idsToRevert.contains(item.id)) {
        return item.copyWith(isUsed: false);
      }
      return item;
    }).toList();

    columns[sourceColIndex] = sourceColumn.copyWith(items: revertedSourceItems);
    return columns;
  }

  // ===============================================

  void _onLoadItems(LoadItems event, Emitter<DragDropState> emit) {
    // Khi khởi động, dùng dữ liệu mock mặc định
    _initializeStateWithMasterItems(_defaultMasterTemplateItems, emit);
  }

  void _onLoadItemsFromData(
    LoadItemsFromData event,
    Emitter<DragDropState> emit,
  ) {
    // Khi có dữ liệu từ file, dùng dữ liệu mới
    _initializeStateWithMasterItems(event.newMasterItems, emit);
  }

  List<Item> findAllInstanceDescendants(
    String parentInstanceId,
    List<Item> itemList,
  ) {
    final List<Item> descendants = [];
    final children = itemList
        .where((item) => item.parentId == parentInstanceId)
        .toList();
    for (final child in children) {
      descendants.add(child);
      descendants.addAll(findAllInstanceDescendants(child.id, itemList));
    }
    return descendants;
  }

  void _initializeStateWithMasterItems(
    List<Item> masterItems,
    Emitter<DragDropState> emit,
  ) {
    final List<Item> initialSourceItems = [];
    final Map<String, String> instanceIdMap = {};

    final sortedTemplates = List<Item>.from(masterItems)
      ..sort((a, b) => a.originalId.compareTo(b.originalId));

    for (final template in sortedTemplates) {
      final newId = _uuid.v4();
      instanceIdMap[template.originalId] = newId;

      String? parentInstanceId;
      final actualParent = _findActualParent(template, sortedTemplates);
      if (actualParent != null) {
        parentInstanceId = instanceIdMap[actualParent.originalId];
      }

      initialSourceItems.add(
        template.copyWith(id: newId, columnId: 1, parentId: parentInstanceId),
      );
    }

    final initialColumns = [
      ColumnData(id: 1, title: 'Chi tiết nguồn', items: initialSourceItems),
      const ColumnData(id: 2, title: 'Tổ A - Trạm 1', items: []),
      const ColumnData(id: 3, title: 'Tổ B - Trạm 2', items: []),
    ];

    emit(state.copyWith(masterItems: masterItems, columns: initialColumns));
  }

  void _onRemoveWorkflowItem(
    RemoveWorkflowItem event,
    Emitter<DragDropState> emit,
  ) {
    final itemToRemove = event.itemToRemove;
    final columnId = itemToRemove.columnId;

    if (columnId <= 1) return;

    debugPrint('\n--- START [_onRemoveWorkflowItem] ---');
    debugPrint(
      '  Item to remove: "${itemToRemove.name}" (Original ID: ${itemToRemove.originalId}) from Col $columnId',
    );

    List<ColumnData> updatedColumns = List.from(state.columns);

    // ================================================================
    // BƯỚC 1: DỌN DẸP LIÊN KẾT NGƯỢC (nextItemId)
    // Phần này không đổi và đã đúng
    // ================================================================
    debugPrint('  1. Cleaning up backward links (nextItemId)...');
    for (var i = 0; i < updatedColumns.length; i++) {
      bool columnWasUpdated = false;
      final List<Item> cleanedItems = updatedColumns[i].items.map((item) {
        if (item.nextItemId == itemToRemove.id) {
          debugPrint(
            '    - Found link from "${item.name}" (ID: ${item.id.substring(0, 8)}). Resetting its nextItemId.',
          );
          columnWasUpdated = true;
          return item.copyWith(setNextItemIdToNull: true);
        }
        return item;
      }).toList();
      if (columnWasUpdated) {
        updatedColumns[i] = updatedColumns[i].copyWith(items: cleanedItems);
      }
    }

    // ================================================================
    // BƯỚC 1.5: CẬP NHẬT PLACEHOLDER CHA (LOGIC MỚI)
    // Tìm xem item sắp bị xóa có đang được liên kết bởi một placeholder nào không.
    // ================================================================
    debugPrint('  1.5. Updating parent placeholder if exists...');
    final itemToRemoveOriginalId = itemToRemove.originalId;
    bool placeholderUpdated = false;

    for (var i = 0; i < updatedColumns.length; i++) {
      final List<Item>
      itemsAfterPlaceholderUpdate = updatedColumns[i].items.map((item) {
        // Kiểm tra xem item có phải là placeholder và có chứa con sắp bị xóa không
        if (item.isGroupPlaceholder &&
            item.linkedChildrenOriginalIds.contains(itemToRemoveOriginalId)) {
          debugPrint(
            '    - Found parent placeholder "${item.name}" (ID: ${item.id.substring(0, 8)})',
          );

          final updatedLinks = List<String>.from(item.linkedChildrenOriginalIds)
            ..remove(itemToRemoveOriginalId);

          debugPrint(
            '    - Removing child. Linked IDs: ${item.linkedChildrenOriginalIds} -> $updatedLinks',
          );
          placeholderUpdated = true;

          // Nếu placeholder hết con và không phải là item gốc (tức là nó được tạo ra từ việc gộp nhóm),
          // nó nên bị xóa đi. Tuy nhiên, logic này có thể phức tạp.
          // Tạm thời, chúng ta chỉ cập nhật danh sách con.
          return item.copyWith(linkedChildrenOriginalIds: updatedLinks);
        }
        return item;
      }).toList();

      if (placeholderUpdated) {
        updatedColumns[i] = updatedColumns[i].copyWith(
          items: itemsAfterPlaceholderUpdate,
        );
        break; // Giả sử một item con chỉ có thể thuộc 1 placeholder trong workflow
      }
    }
    if (!placeholderUpdated) {
      debugPrint('    - No parent placeholder found for this item.');
    }

    // ================================================================
    // BƯỚC 2: XÓA ITEM VÀ CÁC CON CHÁU CỤC BỘ
    // Phần này không đổi
    // ================================================================
    debugPrint('  2. Removing item instance from Col $columnId...');
    final targetColIndex = updatedColumns.indexWhere((c) => c.id == columnId);
    if (targetColIndex != -1) {
      var targetColumn = updatedColumns[targetColIndex];

      // Lưu ý: Logic tìm con cháu cục bộ (findAllInstanceDescendants) không cần thiết ở đây
      // vì chúng ta đang xử lý việc xóa một item đơn lẻ (không phải placeholder).
      // Nếu xóa placeholder thì logic này mới cần thiết.
      // Để đơn giản và đúng với yêu cầu, ta chỉ xóa chính item đó.

      final idsToDelete = {itemToRemove.id};

      final remainingItems = targetColumn.items
          .where((item) => !idsToDelete.contains(item.id))
          .toList();
      updatedColumns[targetColIndex] = targetColumn.copyWith(
        items: remainingItems,
      );
    }

    // ================================================================
    // BƯỚC 3: LOGIC HỒI SINH
    // ================================================================
    debugPrint('  3. Checking if the removed item was the last instance...');
    final originalIdToCheck = itemToRemove.originalId;

    bool instanceExists = false;
    for (final col in updatedColumns) {
      if (col.id > 1) {
        if (col.items.any((item) => item.originalId == originalIdToCheck)) {
          instanceExists = true;
          break;
        }
      }
    }

    if (!instanceExists) {
      debugPrint(
        '    - Yes, it was the last instance. Reverting isUsed status in source column.',
      );
      updatedColumns = _revertIsUsedInSource(originalIdToCheck, updatedColumns);
    } else {
      debugPrint('    - No, other instances still exist.');
    }

    _logAllColumnsState('RemoveWorkflowItem', updatedColumns);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onItemDropped(ItemDropped event, Emitter<DragDropState> emit) {
    final item = event.item;
    final fromColumnId = item.columnId;
    final toColumnId = event.targetColumnId;

    debugPrint(
      '\n\n\x1B[35m--- START [_onItemDropped] (Final Parent Logic) ---\x1B[0m',
    );
    debugPrint(
      '  Item Kéo: "${item.name}" (Vai trò khi kéo: ${item.dragRole})',
    );

    // Logic chặn kéo item đã dùng vẫn đúng
    if (fromColumnId >= toColumnId ||
        fromColumnId == 0 ||
        (item.columnId == 1 && item.isUsed)) {
      return;
    }

    List<ColumnData> updatedColumns = List.from(state.columns);
    final fromIndex = updatedColumns.indexWhere((c) => c.id == fromColumnId);
    final toIndex = updatedColumns.indexWhere((c) => c.id == toColumnId);
    if (fromIndex == -1 || toIndex == -1) return;

    var sourceColumn = updatedColumns[fromIndex];
    var targetColumn = updatedColumns[toIndex];

    if (fromColumnId == 1) {
      // KÉO TỪ CỘT NGUỒN

      List<Item> itemsToProcess;
      Set<String> idsToMarkAsUsed;

      if (item.dragRole == DragRole.parent) {
        final directChildren = sourceColumn.items
            .where((child) => child.parentId == item.id && !child.isUsed)
            .toList();

        // KỊCH BẢN 1A: Kéo PARENT và nó VẪN CÓ CON để phân phát
        if (directChildren.isNotEmpty) {
          debugPrint(
            '  \x1B[36m-> Kịch bản 1A: Kéo PARENT có con -> Phân phát con.\x1B[0m',
          );
          itemsToProcess = directChildren;
          idsToMarkAsUsed = directChildren.map((d) => d.id).toSet();
        }
        // KỊCH BẢN 1B: Kéo PARENT nhưng nó ĐÃ HẾT CON
        else {
          debugPrint(
            '  \x1B[36m-> Kịch bản 1B: Kéo PARENT rỗng -> Di chuyển chính nó.\x1B[0m',
          );
          itemsToProcess = [item];
          idsToMarkAsUsed = {item.id};
        }
      } else {
        // item.dragRole == DragRole.child
        debugPrint(
          '  \x1B[36m-> Kịch bản 2: Kéo với vai trò CHILD, chỉ chuyển CHÍNH NÓ.\x1B[0m',
        );
        itemsToProcess = [item];
        idsToMarkAsUsed = {item.id};
      }

      if (itemsToProcess.isEmpty) {
        return;
      }

      // ... (phần còn lại của hàm không đổi và đã chính xác)
      final originalIdsToProcess = itemsToProcess
          .map((i) => i.originalId)
          .toSet();
      if (targetColumn.items.any(
        (i) => originalIdsToProcess.contains(i.originalId),
      )) {
        return;
      }

      final updatedSourceItems = sourceColumn.items.map((sourceItem) {
        if (idsToMarkAsUsed.contains(sourceItem.id)) {
          return sourceItem.copyWith(isUsed: true);
        }
        return sourceItem;
      }).toList();
      sourceColumn = sourceColumn.copyWith(items: updatedSourceItems);

      final newItemsForTarget = itemsToProcess
          .map(
            (itemToClone) => itemToClone.copyWith(
              id: _uuid.v4(),
              columnId: toColumnId,
              parentId: null,
              setNextItemIdToNull: true,
              isUsed: false,
            ),
          )
          .toList();

      final updatedTargetItems = List<Item>.from(targetColumn.items)
        ..addAll(newItemsForTarget);
      targetColumn = targetColumn.copyWith(items: updatedTargetItems);
    } else {
      // KÉO TỪ CÁC CỘT KHÁC (logic "SAO CHÉP")
      // Logic chống trùng lặp
      if (targetColumn.items.any((i) => i.originalId == item.originalId)) {
        debugPrint(
          'BLoC: Bỏ qua ItemDropped vì item đã tồn tại trong cột đích.',
        );
        return;
      }

      // Tạo bản sao với ID mới
      final newItem = item.copyWith(
        id: _uuid.v4(),
        columnId: toColumnId,
        parentId: null,
        setNextItemIdToNull: true,
        isGroupPlaceholder: false,
        linkedChildrenOriginalIds: [],
      );

      // Cập nhật item gốc để vẽ mũi tên
      final updatedSourceItems = sourceColumn.items.map((i) {
        if (i.id == item.id) {
          return i.copyWith(nextItemId: newItem.id);
        }
        return i;
      }).toList();
      sourceColumn = sourceColumn.copyWith(items: updatedSourceItems);

      // Thêm bản sao vào cột đích
      final updatedTargetItems = List<Item>.from(targetColumn.items)
        ..add(newItem);
      targetColumn = targetColumn.copyWith(items: updatedTargetItems);
    }

    // Cập nhật danh sách cột và emit state mới
    updatedColumns[fromIndex] = sourceColumn;
    updatedColumns[toIndex] = targetColumn;

    _logAllColumnsState('ItemDropped', updatedColumns);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onMergeItemsRequested(
    MergeItemsRequested event,
    Emitter<DragDropState> emit,
  ) {
    final draggedItem = event.draggedItem;
    final targetItem = event.targetItem;
    final toColumnId = targetItem.columnId;

    debugPrint('\n\n\x1B[35m--- START [_onMergeItemsRequested] --- \x1B[0m');
    debugPrint(
      '  \x1B[33mDragged:\x1B[0m "${draggedItem.name}" (ID: ${draggedItem.id.substring(0, 8)}) from Col ${draggedItem.columnId}',
    );
    debugPrint(
      '  \x1B[33mTarget:\x1B[0m  "${targetItem.name}" (ID: ${targetItem.id.substring(0, 8)}) in Col ${targetItem.columnId}',
    );

    List<ColumnData> updatedColumns = List.from(state.columns);
    final toColIndex = updatedColumns.indexWhere((c) => c.id == toColumnId);
    if (toColIndex == -1) return;

    // Kịch bản 1: Thả vào một item "cha đại diện" (placeholder) đã tồn tại
    if (targetItem.isGroupPlaceholder) {
      debugPrint(
        '  \x1B[36mSCENARIO 1: Dropping onto an existing Placeholder.\x1B[0m',
      );
      // Tìm và cập nhật cột đích (toColumn)
      var toColumn = updatedColumns[toColIndex];
      final placeholderInTarget = targetItem;
      final updatedLinkedIds = {
        ...placeholderInTarget.linkedChildrenOriginalIds,
        draggedItem.originalId,
      }.toList(); // Dùng Set để tránh trùng lặp

      final updatedPlaceholder = placeholderInTarget.copyWith(
        linkedChildrenOriginalIds: updatedLinkedIds,
      );
      final updatedToItems = toColumn.items
          .map((i) => i.id == updatedPlaceholder.id ? updatedPlaceholder : i)
          .toList();
      updatedColumns[toColIndex] = toColumn.copyWith(items: updatedToItems);

      // Tìm và cập nhật cột nguồn (fromColumn) để vẽ mũi tên
      for (var i = 0; i < updatedColumns.length; i++) {
        if (updatedColumns[i].id == draggedItem.columnId) {
          final updatedFromItems = updatedColumns[i].items.map((item) {
            if (item.id == draggedItem.id) {
              return item.copyWith(nextItemId: updatedPlaceholder.id);
            }
            return item;
          }).toList();
          updatedColumns[i] = updatedColumns[i].copyWith(
            items: updatedFromItems,
          );
          break;
        }
      }

      // Kịch bản 2: Thả vào một item con "anh em" để tạo ra cha đại diện
    } else {
      debugPrint(
        '  \x1B[36mSCENARIO 2: Dropping onto a sibling item to create a Placeholder.\x1B[0m',
      );
      final actualParentTemplate = _findActualParent(
        draggedItem,
        state.masterItems,
      );
      if (actualParentTemplate == null) return;
      debugPrint('  Found common parent: "${actualParentTemplate.name}"');

      // *** LOGIC MỚI: ĐÁNH DẤU CHA Ở NGUỒN LÀ ĐÃ SỬ DỤNG ***
      // Vì chúng ta sắp "triệu hồi" cha làm placeholder, ta cần đánh dấu nó ở nguồn.
      updatedColumns = _markSourceItemAsUsed(
        actualParentTemplate.originalId,
        updatedColumns,
      );
      // ******************************************************

      // 1. Tạo item cha đại diện mới
      final newPlaceholderId = _uuid.v4();
      final newPlaceholder = Item(
        id: newPlaceholderId,
        originalId: actualParentTemplate.originalId,
        name: actualParentTemplate.name,
        columnId: toColumnId,
        isGroupPlaceholder: true,
        linkedChildrenOriginalIds: {
          draggedItem.originalId,
          targetItem.originalId,
        }.toList(),
      );
      debugPrint(
        '  1. Created new Placeholder with ID: ${newPlaceholderId.substring(0, 8)}',
      );

      // 2. Cập nhật cột đích (toColumn): Xóa targetItem, thêm placeholder
      var toColumn = updatedColumns[toColIndex];
      var updatedToItems = List<Item>.from(toColumn.items)
        ..removeWhere((i) => i.id == targetItem.id)
        ..add(newPlaceholder);
      updatedColumns[toColIndex] = toColumn.copyWith(items: updatedToItems);
      debugPrint('  2. Updated target column (ID ${toColumn.id})');

      // 3. Xác định ID của các item gốc cần được cập nhật
      final String draggedItemSourceId = draggedItem.id;
      String targetItemSourceId = targetItem.id; // Mặc định
      final allItems = updatedColumns.expand((col) => col.items).toList();
      try {
        final source = allItems.firstWhere(
          (item) => item.nextItemId == targetItem.id,
        );
        targetItemSourceId = source.id;
      } catch (e) {
        // Không tìm thấy, nghĩa là targetItem tự là nguồn
      }

      debugPrint(
        '  3. Found source IDs to update: Dragged=${draggedItemSourceId.substring(0, 8)}, Target=${targetItemSourceId.substring(0, 8)}',
      );

      // 4. Duyệt qua tất cả các cột và cập nhật tất cả các item gốc
      debugPrint('  4. Updating source items...');
      for (var i = 0; i < updatedColumns.length; i++) {
        bool columnWasUpdated = false;
        final List<Item> itemsAfterUpdate = updatedColumns[i].items.map((item) {
          if (item.id == draggedItemSourceId) {
            debugPrint(
              '    - Updating dragged source in Col ${updatedColumns[i].id}',
            );
            columnWasUpdated = true;
            return item.copyWith(nextItemId: newPlaceholderId);
          }
          if (item.id == targetItemSourceId) {
            debugPrint(
              '    - Updating target source in Col ${updatedColumns[i].id}',
            );
            columnWasUpdated = true;
            return item.copyWith(nextItemId: newPlaceholderId);
          }
          return item;
        }).toList();

        if (columnWasUpdated) {
          updatedColumns[i] = updatedColumns[i].copyWith(
            items: itemsAfterUpdate,
          );
        }
      }
    }

    debugPrint('\x1B[35m--- END [_onMergeItemsRequested] --- \x1B[0m');
    _logAllColumnsState('MergeItemsRequested', updatedColumns);

    emit(state.copyWith(columns: updatedColumns));
  }

  void _onAddNewColumn(AddNewColumn event, Emitter<DragDropState> emit) {
    if (state.columns.isEmpty) return;

    final newId =
        (state.columns.map((c) => c.id).reduce((a, b) => a > b ? a : b)) + 1;
    final newColumn = ColumnData(
      id: newId,
      title: event.title,
      items: const [],
    );

    final updatedColumns = List<ColumnData>.from(state.columns)..add(newColumn);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onUpgradeToPlaceholderRequested(
    UpgradeToPlaceholderRequested event,
    Emitter<DragDropState> emit,
  ) {
    final childItem = event.childItem;
    final parentTargetItem = event.parentTargetItem;
    final targetColumnId = parentTargetItem.columnId;

    debugPrint(
      '\n\n\x1B[35m--- START [_onUpgradeToPlaceholderRequested] ---\x1B[0m',
    );
    debugPrint('  Child: "${childItem.name}" from Col ${childItem.columnId}');
    debugPrint(
      '  Parent Target: "${parentTargetItem.name}" in Col $targetColumnId',
    );

    List<ColumnData> updatedColumns = List.from(state.columns);
    final targetColIndex = updatedColumns.indexWhere(
      (c) => c.id == targetColumnId,
    );
    if (targetColIndex == -1) return;

    // Vì parentTargetItem sắp được nâng cấp thành placeholder, ta cần đánh dấu nó ở nguồn.
    updatedColumns = _markSourceItemAsUsed(
      parentTargetItem.originalId,
      updatedColumns,
    );
    // ******************************************************

    // 1. "Nâng cấp" item cha trong cột đích
    var targetColumn = updatedColumns[targetColIndex];
    final upgradedParent = parentTargetItem.copyWith(
      isGroupPlaceholder: true,
      // Thêm con mới vào danh sách liên kết
      linkedChildrenOriginalIds: [
        ...parentTargetItem
            .linkedChildrenOriginalIds, // Giữ lại các con cũ nếu có
        childItem.originalId,
      ],
    );

    // Thay thế item cha cũ bằng phiên bản đã nâng cấp
    final updatedTargetItems = targetColumn.items.map((item) {
      if (item.id == parentTargetItem.id) {
        return upgradedParent;
      }
      return item;
    }).toList();
    updatedColumns[targetColIndex] = targetColumn.copyWith(
      items: updatedTargetItems,
    );
    debugPrint(
      '  1. Upgraded "${parentTargetItem.name}" to a placeholder in Col $targetColumnId',
    );

    // 2. Cập nhật `nextItemId` cho item con gốc
    debugPrint('  2. Updating source of child item...');
    for (var i = 0; i < updatedColumns.length; i++) {
      // Chỉ cần tìm trong cột nguồn của childItem là đủ
      if (updatedColumns[i].id == childItem.columnId) {
        final updatedSourceItems = updatedColumns[i].items.map((item) {
          if (item.id == childItem.id) {
            debugPrint(
              '    - Found and updated child source "${item.name}". Setting nextItemId to ${upgradedParent.id.substring(0, 8)}',
            );
            return item.copyWith(nextItemId: upgradedParent.id);
          }
          return item;
        }).toList();
        updatedColumns[i] = updatedColumns[i].copyWith(
          items: updatedSourceItems,
        );
        break; // Đã tìm thấy và cập nhật, thoát vòng lặp
      }
    }

    _logAllColumnsState('UpgradeToPlaceholderRequested', updatedColumns);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onRemoveColumn(RemoveColumn event, Emitter<DragDropState> emit) {
    final columnIdToRemove = event.columnId;
    if (columnIdToRemove <= 1) return;

    debugPrint('\n--- START [_onRemoveColumn] ---');
    debugPrint('  Column to remove: ID $columnIdToRemove');

    List<ColumnData> updatedColumns = List.from(state.columns);
    final columnToRemoveIndex = updatedColumns.indexWhere(
      (c) => c.id == columnIdToRemove,
    );
    if (columnToRemoveIndex == -1) return;

    final columnToRemove = updatedColumns[columnToRemoveIndex];
    final itemsInColumn = List<Item>.from(columnToRemove.items);

    // ================================================================
    // BƯỚC 1: Dọn dẹp liên kết ngược (nextItemId)
    // (Không thay đổi)
    // ================================================================
    debugPrint(
      '  1. Cleaning up all backward links (nextItemId) pointing to this column...',
    );
    final idsInColumnToRemove = itemsInColumn.map((i) => i.id).toSet();
    if (idsInColumnToRemove.isNotEmpty) {
      for (var i = 0; i < updatedColumns.length; i++) {
        if (i == columnToRemoveIndex) continue;

        bool columnWasUpdated = false;
        final List<Item> cleanedItems = updatedColumns[i].items.map((item) {
          if (item.nextItemId != null &&
              idsInColumnToRemove.contains(item.nextItemId)) {
            debugPrint(
              '    - Found link from "${item.name}" (in Col ${updatedColumns[i].id}). Resetting nextItemId.',
            );
            columnWasUpdated = true;
            return item.copyWith(setNextItemIdToNull: true);
          }
          return item;
        }).toList();
        if (columnWasUpdated) {
          updatedColumns[i] = updatedColumns[i].copyWith(items: cleanedItems);
        }
      }
    }

    // ================================================================
    // BƯỚC 1.5: CẬP NHẬT PLACEHOLDER CHA (LOGIC MỚI)
    // ================================================================
    debugPrint('  1.5. Updating parent placeholders...');
    final originalIdsInColumnToRemove = itemsInColumn
        .map((i) => i.originalId)
        .toSet();
    if (originalIdsInColumnToRemove.isNotEmpty) {
      for (var i = 0; i < updatedColumns.length; i++) {
        // Không cần kiểm tra cột sắp bị xóa, vì placeholder không thể tự chứa con
        if (i == columnToRemoveIndex) continue;

        bool wasUpdated = false;
        final List<Item> updatedItems = updatedColumns[i].items.map((item) {
          if (item.isGroupPlaceholder) {
            final originalLinks = item.linkedChildrenOriginalIds.toSet();
            // Tìm những originalId chung giữa placeholder và cột bị xóa
            final commonIds = originalLinks.intersection(
              originalIdsInColumnToRemove,
            );

            if (commonIds.isNotEmpty) {
              final newLinks = originalLinks.difference(commonIds).toList();
              debugPrint(
                '    - Placeholder "${item.name}" (in Col ${item.columnId}) is losing children: $commonIds',
              );
              debugPrint('    - New links: $newLinks');
              wasUpdated = true;
              return item.copyWith(linkedChildrenOriginalIds: newLinks);
            }
          }
          return item;
        }).toList();

        if (wasUpdated) {
          updatedColumns[i] = updatedColumns[i].copyWith(items: updatedItems);
        }
      }
    }

    // ================================================================
    // BƯỚC 2: Hồi sinh item nguồn
    // (Không thay đổi)
    // ================================================================
    debugPrint('  2. Reviving items in source column...');
    final allOtherWorkingItems = updatedColumns
        .where((c) => c.id > 1 && c.id != columnIdToRemove)
        .expand((c) => c.items)
        .toList();

    for (final item in itemsInColumn) {
      final originalId = item.originalId;
      final bool instanceExistsElsewhere = allOtherWorkingItems.any(
        (i) => i.originalId == originalId,
      );

      if (!instanceExistsElsewhere) {
        debugPrint(
          '    - Item "${item.name}" was the last instance. Reviving in source.',
        );
        updatedColumns = _revertIsUsedInSource(originalId, updatedColumns);
      }
    }

    // ================================================================
    // BƯỚC 3: Xóa cột
    // (Không thay đổi)
    // ================================================================
    debugPrint('  3. Removing column ID $columnIdToRemove from state.');
    updatedColumns.removeAt(columnToRemoveIndex);

    _logAllColumnsState('RemoveColumn', updatedColumns);
    emit(state.copyWith(columns: updatedColumns));
  }

  void _onLevelFilterChanged(
    LevelFilterChanged event,
    Emitter<DragDropState> emit,
  ) {
    emit(state.copyWith(displayLevelStart: event.newStartLevel));
  }
}
