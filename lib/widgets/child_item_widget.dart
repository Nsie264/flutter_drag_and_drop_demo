import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/cubit/drag_cubit.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChildItemWidget extends StatelessWidget {
  final Item item;
  final GlobalKey itemKey; // Thêm GlobalKey để vẽ mũi tên

  const ChildItemWidget({
    super.key,
    required this.item,
    required this.itemKey, // Thêm GlobalKey
  });

  @override
  Widget build(BuildContext context) {
    // DragTarget để nhận item khác thả vào (TẠO LIÊN KẾT)
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        final draggedItem = details.data;
        // Chấp nhận khi:
        // 1. Kéo sang cột sau
        // 2. Không phải là tự thả vào chính mình
        final canAccept =
            item.columnId > draggedItem.columnId &&
            item.id != draggedItem.id &&
            item.itemLevel == draggedItem.itemLevel;
        return canAccept;
      },
      onAcceptWithDetails: (details) {
        // Luôn gửi event GroupItemsRequested khi thả vào một item khác
        context.read<DragDropBloc>().add(
          GroupItemsRequested(draggedItem: details.data, targetItem: item),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isTargetForLink = candidateData.isNotEmpty;
        return Draggable<Item>(
          data: item,
          feedback: Material(color: Colors.transparent, child: _buildBox(context, isDragging: true)),
          childWhenDragging: Opacity(opacity: 0.5, child: _buildBox(context, key: itemKey)),
          onDragStarted: () => context.read<DragCubit>().startDragging(),
          onDragEnd: (_) => context.read<DragCubit>().endDragging(),
          child: _buildBox(
            context,
            isTargetForLink: isTargetForLink,
            key: itemKey,
          ),
        );
      },
    );
  }

  Widget _buildBox(
    BuildContext context, {
    Key? key,
    bool isDragging = false,
    bool isTargetForLink = false,
  }) {
    return Container(
      key: key,
      height: 30,
      width: 120,
      margin: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: isTargetForLink ? Colors.green.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(4.0),
        border: isTargetForLink
            ? Border.all(color: Colors.green, width: 2)
            : null,
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Align(alignment: Alignment.centerLeft, child: Text(item.name)),
    );
  }
}
