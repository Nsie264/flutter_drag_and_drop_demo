import 'package:drag_and_drop/cubit/drag_cubit.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/child_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drag_and_drop/bloc/drag_drop_bloc.dart'; // Thêm import này
class ParentItemWidget extends StatelessWidget {
  final Item parentItem;
  final List<Item> childItems;
  final Map<String, GlobalKey> itemKeys;
  final bool isDraggable; // THÊM THUỘC TÍNH MỚI

  const ParentItemWidget({
    super.key,
    required this.parentItem,
    required this.childItems,
    required this.itemKeys,
    this.isDraggable = true, // Mặc định là có thể kéo
  });

  @override
  Widget build(BuildContext context) {
    final parentKey = itemKeys[parentItem.id]!;

    // NẾU KHÔNG THỂ KÉO, RENDER MỘT WIDGET ĐƠN GIẢN
    if (!isDraggable) {
      return _buildBox(context, key: parentKey, isDisabled: true);
    }
    
    // NẾU CÓ THỂ KÉO, RENDER WIDGET Draggable/DragTarget NHƯ CŨ
    return DragTarget<Item>(
      // ... (logic DragTarget giữ nguyên)
      builder: (context, candidateData, rejectedData) {
        final isTargetForLink = candidateData.isNotEmpty;
        return Draggable<Item>(
          data: parentItem,
          feedback: Material(
            color: Colors.transparent,
            child: Theme(
              data: Theme.of(context),
              child: _buildBox(context, isDragging: true, forFeedback: true),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.5, child: _buildBox(context, key: parentKey)),
          onDragStarted: () => context.read<DragCubit>().startDragging(),
          onDragEnd: (_) => context.read<DragCubit>().endDragging(),
          onDraggableCanceled: (_, __) => context.read<DragCubit>().endDragging(),
          child: _buildBox(context, isTargetForLink: isTargetForLink, key: parentKey),
        );
      },
    );
  }

  // Sửa đổi _buildBox để xử lý trạng thái isDisabled
  Widget _buildBox(BuildContext context, {Key? key, bool isDragging = false, bool isTargetForLink = false, bool forFeedback = false, bool isDisabled = false}) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8.0),
      // width: 150, // Bỏ width cố định để nó tự co giãn theo cột
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade300 : (isTargetForLink ? Colors.green.shade100 : Colors.amber.shade100),
        borderRadius: BorderRadius.circular(8.0),
        border: isTargetForLink ? Border.all(color: Colors.green, width: 2) : null,
        boxShadow: isDragging ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            parentItem.name, 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDisabled ? Colors.grey.shade600 : Colors.black, // Màu chữ khi bị vô hiệu hóa
            )
          ),
          if (childItems.isNotEmpty && !forFeedback) ...[
            const SizedBox(height: 4),
            Column(
              children: childItems.map((child) {
                final childKey = itemKeys[child.id]!;
                return ChildItemWidget(
                  key: ValueKey(child.id),
                  item: child,
                  itemKey: childKey
                );
              }).toList(),
            ),
          ]
        ],
      ),
    );
  }
}