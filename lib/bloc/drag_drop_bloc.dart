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

    on<GroupDropped>(_onGroupDropped); // <-- Thêm handler mới
    on<MergeGroupRequested>(_onMergeGroupRequested); // <-- Thêm handler mới

    on<AddNewColumn>(_onAddNewColumn);
    on<RemoveColumn>(_onRemoveColumn);
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
    // ... (Phần log đầu vào và tìm item nguồn không đổi)
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
    String?
    targetSiblingSourceId; // <-- THAY ĐỔI 1: Biến lưu ID của item gốc cần cập nhật

    // ... (Kịch bản 1 và 2 không thay đổi)
    if (targetItem.isGroupPlaceholder) {
      scenario = _MergeScenario.mergeIntoExisting;
      debugPrint('  \x1B[36mKỊCH BẢN 1: Gộp vào Placeholder đã có.\x1B[0m');
      finalPlaceholderId = targetItem.id;
      // ...
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
    } else if (targetItem.originalId == parentOriginalId) {
      scenario = _MergeScenario.upgradeParent;
      debugPrint(
        '  \x1B[36mKỊCH BẢN 2: Nâng cấp Item cha thành Placeholder.\x1B[0m',
      );
      finalPlaceholderId = targetItem.id;
      // ...
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

      // <-- THAY ĐỔI 2: Tìm nguồn của target item TRƯỚC KHI xóa nó
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
        // Nếu không có nguồn (ví dụ: nó được kéo từ Cột Nguồn), ID của nó chính là nguồn
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

        // Cập nhật cho các item trong group được kéo
        if (sourceItemIdsToUpdate.contains(item.id)) {
          columnWasUpdated = true;
          debugPrint(
            '  \x1B[32m-> Cập nhật Group Item:\x1B[0m "\x1B[36m${item.name}\x1B[0m" (ID: ${item.id.substring(0, 8)}). nextItemId: $oldNextId -> ${finalPlaceholderId.substring(0, 8)}',
          );
          return item.copyWith(nextItemId: finalPlaceholderId);
        }

        // <-- THAY ĐỔI 3: Sử dụng ID đã lưu để cập nhật đúng item
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

    // ... (Phần log cuối và emit state không đổi)
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
      ColumnData(id: 1, title: 'Nguồn', items: initialSourceItems),
      const ColumnData(id: 2, title: 'Cột 2', items: []),
      const ColumnData(id: 3, title: 'Cột 3', items: []),
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
      '  Item to remove: "${itemToRemove.name}" (ID: ${itemToRemove.id.substring(0, 8)}) from Col $columnId',
    );

    List<ColumnData> updatedColumns = List.from(state.columns);

    // 1. Dọn dẹp các liên kết ngược (không đổi)
    debugPrint('  1. Cleaning up backward links...');
    for (var i = 0; i < updatedColumns.length; i++) {
      bool columnWasUpdated = false;
      final List<Item> cleanedItems = updatedColumns[i].items.map((item) {
        if (item.nextItemId == itemToRemove.id) {
          debugPrint(
            '    - Found link from "${item.name}". Resetting nextItemId.',
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

    // 2. Xóa item và các con cháu của nó (không đổi)
    debugPrint('  2. Removing item and its descendants from Col $columnId...');
    final targetColIndex = updatedColumns.indexWhere((c) => c.id == columnId);
    if (targetColIndex != -1) {
      var targetColumn = updatedColumns[targetColIndex];
      final descendantsInColumn = findAllInstanceDescendants(
        itemToRemove.id,
        targetColumn.items,
      );
      final idsToDelete = {
        itemToRemove.id,
        ...descendantsInColumn.map((d) => d.id),
      };
      final remainingItems = targetColumn.items
          .where((item) => !idsToDelete.contains(item.id))
          .toList();
      updatedColumns[targetColIndex] = targetColumn.copyWith(
        items: remainingItems,
      );
    }

    // ================ LOGIC MỚI: KIỂM TRA VÀ HỒI SINH ================
    debugPrint('  3. Checking if the removed item was the last instance...');
    final originalIdToCheck = itemToRemove.originalId;

    // Quét tất cả các cột làm việc để xem còn bản sao nào không
    bool instanceExists = false;
    for (final col in updatedColumns) {
      if (col.id > 1) {
        // Chỉ kiểm tra các cột làm việc
        if (col.items.any((item) => item.originalId == originalIdToCheck)) {
          instanceExists = true;
          break; // Tìm thấy một bản sao, không cần kiểm tra thêm
        }
      }
    }

    if (!instanceExists) {
      debugPrint(
        '    - Yes, it was the last instance. Reverting isUsed status in source column.',
      );
      // Nếu không còn bản sao nào, gọi hàm hồi sinh
      updatedColumns = _revertIsUsedInSource(originalIdToCheck, updatedColumns);
    } else {
      debugPrint('    - No, other instances still exist.');
    }
    // =================================================================

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

    debugPrint(
      '\n\n\x1B[35m--- START [_onMergeItemsRequested] (FIXED) --- \x1B[0m',
    );
    debugPrint(
      '  \x1B[33mDragged:\x1B[0m "${draggedItem.name}" (ID: ${draggedItem.id.substring(0, 8)}) from Col ${draggedItem.columnId}',
    );
    debugPrint(
      '  \x1B[33mTarget:\x1B[0m  "${targetItem.name}" (ID: ${targetItem.id.substring(0, 8)}) in Col ${targetItem.columnId}',
    );

    List<ColumnData> updatedColumns = List.from(state.columns);
    final toColIndex = updatedColumns.indexWhere((c) => c.id == toColumnId);
    if (toColIndex == -1) return;

    // Kịch bản 1: Thả vào một item "cha đại diện" đã tồn tại
    if (targetItem.isGroupPlaceholder) {
      debugPrint(
        '  \x1B[36mSCENARIO 1: Dropping onto an existing Placeholder.\x1B[0m',
      );
      // Tìm và cập nhật cột đích (toColumn)
      var toColumn = updatedColumns[toColIndex];
      final placeholderInTarget = targetItem;
      final updatedLinkedIds = List<String>.from(
        placeholderInTarget.linkedChildrenOriginalIds,
      );
      if (!updatedLinkedIds.contains(draggedItem.originalId)) {
        updatedLinkedIds.add(draggedItem.originalId);
      }
      final updatedPlaceholder = placeholderInTarget.copyWith(
        linkedChildrenOriginalIds: updatedLinkedIds,
      );
      final updatedToItems = toColumn.items
          .map((i) => i.id == updatedPlaceholder.id ? updatedPlaceholder : i)
          .toList();
      updatedColumns[toColIndex] = toColumn.copyWith(items: updatedToItems);

      // Tìm và cập nhật cột nguồn (fromColumn)
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
          break; // Đã tìm thấy và cập nhật, thoát vòng lặp
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
      String draggedItemSourceId =
          draggedItem.id; // Luôn là chính nó vì nó được kéo trực tiếp
      String targetItemOriginalSourceId =
          targetItem.id; // Có thể là chính nó hoặc item đã tạo ra nó

      for (final col in state.columns) {
        for (final item in col.items) {
          if (item.nextItemId == targetItem.id) {
            targetItemOriginalSourceId = item.id;
            debugPrint(
              '  3a. Found original source of targetItem: "${item.name}" (ID: ${item.id.substring(0, 8)})',
            );
            break;
          }
        }
        if (targetItemOriginalSourceId != targetItem.id) break;
      }

      // 4. Duyệt qua tất cả các cột một lần duy nhất và cập nhật tất cả các item gốc
      debugPrint(
        '  4. Updating source items... (Dragged Source ID: ${draggedItemSourceId.substring(0, 8)}, Target Source ID: ${targetItemOriginalSourceId.substring(0, 8)})',
      );
      for (var i = 0; i < updatedColumns.length; i++) {
        bool columnWasUpdated = false;
        final List<Item> itemsAfterUpdate = updatedColumns[i].items.map((item) {
          // === LOGIC SỬA LỖI QUAN TRỌNG ===
          // Chỉ tạo mũi tên (cập nhật nextItemId) nếu item gốc không nằm ở Cột Nguồn
          if (item.id == draggedItemSourceId && item.columnId > 1) {
            debugPrint(
              '    - Updating dragged source in Col ${updatedColumns[i].id}',
            );
            columnWasUpdated = true;
            return item.copyWith(nextItemId: newPlaceholderId);
          }
          if (item.id == targetItemOriginalSourceId && item.columnId > 1) {
            debugPrint(
              '    - Updating target source in Col ${updatedColumns[i].id}',
            );
            columnWasUpdated = true;
            return item.copyWith(nextItemId: newPlaceholderId);
          }
          // ===============================

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
      title: 'Cột $newId',
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
    // (Logic này có thể được tách ra thành hàm helper để tái sử dụng)
    debugPrint('  2. Updating source of child item...');
    for (var i = 0; i < updatedColumns.length; i++) {
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
        break;
      }
    }

    _logAllColumnsState('UpgradeToPlaceholderRequested', updatedColumns);
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
