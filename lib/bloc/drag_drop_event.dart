part of 'drag_drop_bloc.dart';

abstract class DragDropEvent extends Equatable {
  const DragDropEvent();

  @override
  List<Object> get props => [];
}

// Giữ nguyên: Khởi tạo dữ liệu ban đầu
class LoadItems extends DragDropEvent {}

// Thay đổi: Xử lý việc thả item vào một cột mới
class ItemDropped extends DragDropEvent {
  final Item item;
  final int targetColumnId;

  const ItemDropped({required this.item, required this.targetColumnId});

  @override
  List<Object> get props => [item, targetColumnId];
}

// Giữ nguyên: Xóa cột
class RemoveColumn extends DragDropEvent {
  final int columnId;

  const RemoveColumn({required this.columnId});

  @override
  List<Object> get props => [columnId];
}

// Mới: Xử lý khi người dùng thay đổi bộ lọc level
class LevelFilterChanged extends DragDropEvent {
  final int newStartLevel;

  const LevelFilterChanged({required this.newStartLevel});

  @override
  List<Object> get props => [newStartLevel];
}

class MergeItemsRequested extends DragDropEvent {
  final Item draggedItem; // Item đang được kéo
  final Item targetItem; // Item (con hoặc cha đại diện) được thả vào

  const MergeItemsRequested({
    required this.draggedItem,
    required this.targetItem,
  });

  @override
  List<Object> get props => [draggedItem, targetItem];
}

class RemoveWorkflowItem extends DragDropEvent {
  final Item itemToRemove;

  const RemoveWorkflowItem({required this.itemToRemove});

  @override
  List<Object> get props => [itemToRemove];
}

class LoadItemsFromData extends DragDropEvent {
  final List<Item> newMasterItems;

  const LoadItemsFromData({required this.newMasterItems});

  @override
  List<Object> get props => [newMasterItems];
}

class UpgradeToPlaceholderRequested extends DragDropEvent {
  final Item childItem; // Item con đang được kéo
  final Item parentTargetItem; // Item cha (dạng thường) được thả vào

  const UpgradeToPlaceholderRequested({
    required this.childItem,
    required this.parentTargetItem,
  });

  @override
  List<Object> get props => [childItem, parentTargetItem];
}

// Event khi thả một group vào nền cột
class GroupDropped extends DragDropEvent {
  final Item representativeItem;
  final int targetColumnId;

  const GroupDropped({
    required this.representativeItem,
    required this.targetColumnId,
  });

  @override
  List<Object> get props => [representativeItem, targetColumnId];
}

// Event khi thả một group vào một item khác (để gộp)
class MergeGroupRequested extends DragDropEvent {
  final Item representativeItem;
  final Item targetItem;

  const MergeGroupRequested({
    required this.representativeItem,
    required this.targetItem,
  });

  @override
  List<Object> get props => [representativeItem, targetItem];
}

class AddNewColumn extends DragDropEvent {
  final String title; // <-- THÊM THAM SỐ

  const AddNewColumn({required this.title}); // <-- CẬP NHẬT CONSTRUCTOR

  @override
  List<Object> get props => [title]; // <-- CẬP NHẬT PROPS
}

// Bật/tắt chế độ chọn nhiều cho một cột
class ToggleMultiSelectMode extends DragDropEvent {
  final int columnId;
  const ToggleMultiSelectMode({required this.columnId});
  @override
  List<Object> get props => [columnId];
}

// Chọn hoặc bỏ chọn một item
class ItemSelectionChanged extends DragDropEvent {
  final String itemId;
  final bool isSelected;
  const ItemSelectionChanged({required this.itemId, required this.isSelected});
  @override
  List<Object> get props => [itemId, isSelected];
}

// Thả một nhóm item đã được chọn
class MultiSelectionDropped extends DragDropEvent {
  final int targetColumnId;
  final Item? targetItem; // Item được thả vào (nếu có)
  final Item representativeItem; // Một item đại diện để lấy thông tin cột nguồn

  const MultiSelectionDropped({
    required this.targetColumnId,
    this.targetItem,
    required this.representativeItem,
  });

  @override
  List<Object> get props {
    // 1. Sửa kiểu trả về thành List<Object>
    // 2. Sử dụng "collection if" để chỉ thêm targetItem vào danh sách nếu nó không phải là null
    return [
      targetColumnId,
      if (targetItem != null)
        targetItem!, // Dấu ! để xác nhận với Dart là nó không null ở đây
      representativeItem,
    ];
  }
}

// NEW: Event được gửi khi người dùng double click vào một item.
class HighlightChainRequested extends DragDropEvent {
  final String itemId;

  const HighlightChainRequested({required this.itemId});

  @override
  List<Object> get props => [itemId];
}
