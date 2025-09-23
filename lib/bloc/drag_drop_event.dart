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

// Mới: Xử lý việc tạo liên kết khi thả item A lên item B
class LinkItemsRequested extends DragDropEvent {
  final String fromItemId;
  final String toItemId;

  const LinkItemsRequested({required this.fromItemId, required this.toItemId});

  @override
  List<Object> get props => [fromItemId, toItemId];
}

// Thay đổi: Xử lý việc xóa một item (và các con của nó)
class RemoveItem extends DragDropEvent {
  final Item itemToRemove;

  const RemoveItem({required this.itemToRemove});

  @override
  List<Object> get props => [itemToRemove];
}

// Giữ nguyên: Thêm cột mới
class AddNewColumn extends DragDropEvent {}

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

class GroupItemsRequested extends DragDropEvent {
  final Item draggedItem; // Item con đang được kéo
  final Item targetItem;  // Item con mà nó được thả vào

  const GroupItemsRequested({required this.draggedItem, required this.targetItem});

  @override
  List<Object> get props => [draggedItem, targetItem];
}