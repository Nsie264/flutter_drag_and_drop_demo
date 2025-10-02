import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/workflow_item_widget.dart';
import 'package:flutter/material.dart';
class GroupContainerWidget extends StatelessWidget {
  final Item parentInfo;
  final List<Item> childItems;
  final Map<String, GlobalKey> itemKeys;
  final bool isMultiSelectModeActive; // NEW


  const GroupContainerWidget({
    super.key,
    required this.parentInfo,
    required this.childItems,
    required this.itemKeys,
    required this.isMultiSelectModeActive,
  });

  @override
  Widget build(BuildContext context) {
    // Tìm các item con "khả dụng" để kéo
    final availableChildren = childItems.where((i) => i.nextItemId == null).toList();
    // Nếu không có item nào khả dụng, không cho phép kéo
    final bool canDrag = availableChildren.isNotEmpty;
    // Lấy item đầu tiên làm "đại diện"
    final representativeItem = canDrag ? availableChildren.first : null;

    final header = Container(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        parentInfo.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: canDrag ? Colors.black54 : Colors.grey.shade400,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nếu có thể kéo, bọc header bằng Draggable
          if (canDrag && representativeItem != null)
            Draggable<Item>(
              // Dữ liệu mang theo là item đại diện, nhưng với dragMode = group
              data: representativeItem.copyWith(dragMode: DragMode.group),
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2)),
                    ],
                  ),
                  child: Text(
                    'Kéo nhóm: ${parentInfo.name} (${availableChildren.length} items)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.5, child: header),
              child: header,
            )
          else
            // Nếu không, chỉ hiển thị header bình thường
            header,
          
          Column(
            children: childItems.map((item) {
              return WorkflowItemWidget(
                key: ValueKey(item.id),
                item: item,
                itemKey: itemKeys[item.id]!,

                isMultiSelectModeActive: isMultiSelectModeActive, 
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}