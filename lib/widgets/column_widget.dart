import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/group_container_widget.dart';
import 'package:drag_and_drop/widgets/workflow_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';

// Widget helper để render một ô item trong Cột Nguồn
Widget _buildSourceItemTile(BuildContext context, Item item, {required DragRole role}) {
  final bool isParentRole = role == DragRole.parent;
  
  return Draggable<Item>(
    data: item.copyWith(dragRole: role), 
    feedback: Material(
      color: Colors.transparent,
      child: Theme(
        data: Theme.of(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250 - 32),
          child: Container(
            height: isParentRole ? 45 : 35,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: item.isUsed
                  ? Colors.grey.shade300
                  : (isParentRole ? Colors.amber.shade100 : Colors.blue.shade100),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2)),
              ]
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.name,
                style: TextStyle(
                  fontWeight: isParentRole ? FontWeight.bold : FontWeight.normal,
                  color: item.isUsed ? Colors.grey.shade600 : Colors.black,
                  decoration: item.isUsed ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    childWhenDragging: Opacity(
      opacity: 0.5,
      child: Container(
        height: isParentRole ? 45 : 35,
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: item.isUsed ? Colors.grey.shade300 : (isParentRole ? Colors.amber.shade100 : Colors.blue.shade100),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.name,
            style: TextStyle(
              fontWeight: isParentRole ? FontWeight.bold : FontWeight.normal,
              color: item.isUsed ? Colors.grey.shade600 : Colors.black,
              decoration: item.isUsed ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ),
      ),
    ),
    child: Container(
      height: isParentRole ? 45 : 35,
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: item.isUsed ? Colors.grey.shade300 : (isParentRole ? Colors.amber.shade100 : Colors.blue.shade100),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          item.name,
          style: TextStyle(
            fontWeight: isParentRole ? FontWeight.bold : FontWeight.normal,
            color: item.isUsed ? Colors.grey.shade600 : Colors.black,
            decoration: item.isUsed ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
      ),
    ),
  );
}

class ColumnWidget extends StatelessWidget {
  final int columnId;
  final String title;
  final double width;
  final List<Item> items;
  final Map<String, GlobalKey> itemKeys;
  final int displayLevelStart;
  final ScrollController? scrollController;

  const ColumnWidget({
    super.key,
    required this.columnId,
    required this.title,
    required this.width,
    required this.items,
    required this.itemKeys,
    required this.displayLevelStart,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        final item = details.data;
        bool isAlreadyInTarget = false;
        if(item.columnId == 1 && item.dragRole == DragRole.parent){
          final sourceItems = context.read<DragDropBloc>().state.sourceColumn.items;
          final childrenToMove = sourceItems.where((child) => child.parentId == item.id && !child.isUsed);
          final originalIdsToMove = childrenToMove.map((c) => c.originalId).toSet();
          isAlreadyInTarget = items.any((i) => originalIdsToMove.contains(i.originalId));
        } else {
          isAlreadyInTarget = items.any((i) => i.originalId == item.originalId);
        }
        return columnId > item.columnId && !isAlreadyInTarget;
      },
      onAcceptWithDetails: (details) {
        final draggedItem = details.data;
        // PHÂN LUỒNG LOGIC TẠI ĐÂY
        if (draggedItem.dragMode == DragMode.group) {
          context.read<DragDropBloc>().add(GroupDropped(
            representativeItem: draggedItem,
            targetColumnId: columnId,
          ));
        } else {
          // Logic cũ cho item đơn
          context.read<DragDropBloc>().add(ItemDropped(
            item: draggedItem,
            targetColumnId: columnId,
          ));
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return Container(
          width: width,
          margin: const EdgeInsets.all(8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: isTarget ? Colors.lightGreen.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isTarget ? Colors.green : Colors.transparent, width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (columnId > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () {},
                        splashRadius: 20,
                      )
                  ],
                ),
              ),
              if (columnId == 1)
                Expanded(child: _buildSourceColumnContent(context))
              else
                _buildWorkflowColumnContent(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceColumnContent(BuildContext context) {
    final sortedItems = List<Item>.from(items);
    sortedItems.sort((a, b) {
      if (a.isUsed && !b.isUsed) return 1;
      if (!a.isUsed && b.isUsed) return -1;
      return a.originalId.compareTo(b.originalId);
    });
    final visibleItems = sortedItems.where((item) => item.itemLevel >= displayLevelStart && item.itemLevel <= displayLevelStart + 1).toList();
    final visibleItemsById = {for (var item in visibleItems) item.id: item};
    final List<Item> rootItemsToRender = [];
    for (final item in visibleItems) {
      if (item.itemLevel == displayLevelStart || (item.parentId == null || !visibleItemsById.containsKey(item.parentId))) {
        rootItemsToRender.add(item);
      }
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: rootItemsToRender.length,
      itemBuilder: (context, index) {
        final rootItem = rootItemsToRender[index];
        if (rootItem.itemLevel == displayLevelStart) {
          final childrenInView = visibleItems.where((child) => child.parentId == rootItem.id).toList();
          final isParentDisabled = rootItem.isUsed;
          
          if (childrenInView.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: isParentDisabled 
                ? IgnorePointer(child: _buildSourceItemTile(context, rootItem, role: DragRole.parent))
                : _buildSourceItemTile(context, rootItem, role: DragRole.parent),
            );
          }
          
          return ExpansionTile(
            key: PageStorageKey(rootItem.id),
            tilePadding: EdgeInsets.zero,
            title: isParentDisabled 
              ? IgnorePointer(child: _buildSourceItemTile(context, rootItem, role: DragRole.parent))
              : _buildSourceItemTile(context, rootItem, role: DragRole.parent),
            initiallyExpanded: false,
            childrenPadding: const EdgeInsets.only(left: 16),
            children: childrenInView.map((childItem) {
              return _buildSourceItemTile(context, childItem, role: DragRole.child);
            }).toList(),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: _buildSourceItemTile(context, rootItem, role: DragRole.child),
          );
        }
      },
    );
  }

  Widget _buildWorkflowColumnContent(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Kéo item vào đây', style: TextStyle(color: Colors.grey)));
    }
    final masterItems = context.read<DragDropBloc>().state.masterItems;
    final placeholders = items.where((i) => i.isGroupPlaceholder).toList();
    final childrenItems = items.where((i) => !i.isGroupPlaceholder && i.potentialParentOriginalId != null).toList();
    final orphanItems = items.where((i) => !i.isGroupPlaceholder && i.potentialParentOriginalId == null).toList();
    final groupedChildren = groupBy<Item, String>(childrenItems, (item) => item.potentialParentOriginalId!);
    List<Widget> widgetsToRender = [];
    widgetsToRender.addAll(orphanItems.map((item) => WorkflowItemWidget(
      key: ValueKey(item.id), item: item, itemKey: itemKeys[item.id]!,
    )));
    widgetsToRender.addAll(placeholders.map((item) {
      final isComplete = context.read<DragDropBloc>().isGroupComplete(item, masterItems);
      return WorkflowItemWidget(
        key: ValueKey(item.id), item: item, itemKey: itemKeys[item.id]!, isComplete: isComplete,
      );
    }));
    groupedChildren.forEach((parentId, children) {
        final parentInfo = masterItems.firstWhereOrNull((m) => m.originalId == parentId);
        if (parentInfo != null) {
          widgetsToRender.add(GroupContainerWidget(
            key: ValueKey(parentId), parentInfo: parentInfo, childItems: children, itemKeys: itemKeys,
          ));
        }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgetsToRender,
    );
  }
}