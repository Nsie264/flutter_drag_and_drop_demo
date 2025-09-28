// lib/widgets/group_container_widget.dart

import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/workflow_item_widget.dart';
import 'package:flutter/material.dart';

class GroupContainerWidget extends StatelessWidget {
  final Item parentInfo; // Item mẫu của cha để lấy tên
  final List<Item> childItems;
  final Map<String, GlobalKey> itemKeys;

  const GroupContainerWidget({
    super.key,
    required this.parentInfo,
    required this.childItems,
    required this.itemKeys,
  });

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              parentInfo.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
          // Dùng Column thay vì ListView để tránh lỗi cuộn lồng nhau
          Column(
            children: childItems.map((item) {
              return WorkflowItemWidget(
                key: ValueKey(item.id),
                item: item,
                itemKey: itemKeys[item.id]!,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}