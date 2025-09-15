// lib/bloc/drag_drop_event.dart

part of 'drag_drop_bloc.dart';

abstract class DragDropEvent extends Equatable {
  const DragDropEvent();
  @override
  List<Object> get props => [];
}

class LoadItems extends DragDropEvent {}

class ItemDropped extends DragDropEvent {
  final Item item;
  final int targetColumnId;
  const ItemDropped({required this.item, required this.targetColumnId});
  @override
  List<Object> get props => [item, targetColumnId];
}

class RemoveItem extends DragDropEvent {
  final Item item;
  const RemoveItem({required this.item});
  @override
  List<Object> get props => [item];
}

class AddConnection extends DragDropEvent {
  final String fromItemId;
  final String toItemId;
  const AddConnection({required this.fromItemId, required this.toItemId});
  @override
  List<Object> get props => [fromItemId, toItemId];
}

class AddNewColumn extends DragDropEvent {}

class RemoveColumn extends DragDropEvent {
  final int columnId;
  const RemoveColumn({required this.columnId});
  @override
  List<Object> get props => [columnId];
}

// Events mới cho Phase 3
class ToggleViewMode extends DragDropEvent {}

class HighlightChain extends DragDropEvent {
  final String itemId;
  const HighlightChain({required this.itemId});
  @override
  List<Object> get props => [itemId];
}

class ClearHighlight extends DragDropEvent {}