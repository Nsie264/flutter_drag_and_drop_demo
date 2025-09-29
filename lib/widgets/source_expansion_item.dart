// lib/widgets/source_expansion_item.dart
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';

// Dùng chung một hàm build cho cả cha và con để thống nhất UI
Widget _buildItemTile(BuildContext context, Item item, {bool isParent = false}) {
  return Container(
    height: isParent ? 45 : 35,
    margin: const EdgeInsets.symmetric(vertical: 2.0),
    padding: EdgeInsets.only(left: isParent ? 12 : 28, right: 12),
    decoration: BoxDecoration(
      color: item.isUsed
          ? Colors.grey.shade300
          : (isParent ? Colors.amber.shade100 : Colors.blue.shade100),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        item.name,
        style: TextStyle(
          fontWeight: isParent ? FontWeight.bold : FontWeight.normal,
          color: item.isUsed ? Colors.grey.shade600 : Colors.black,
          decoration: item.isUsed ? TextDecoration.lineThrough : TextDecoration.none,
        ),
      ),
    ),
  );
}

class SourceExpansionItem extends StatelessWidget {
  final Item item;
  final List<Item> allSourceItems; // Cần tất cả item để tìm con cháu
  final Map<String, GlobalKey> itemKeys;

  const SourceExpansionItem({
    super.key,
    required this.item,
    required this.allSourceItems,
    required this.itemKeys,
  });

  @override
  Widget build(BuildContext context) {
    // Tìm các con trực tiếp của item này
    final children = allSourceItems.where((child) => child.parentId == item.id).toList();

    // Nếu không có con, nó là một item đơn lẻ (Draggable)
    if (children.isEmpty) {
      return Draggable<Item>(
        data: item,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250 - 16), // Giới hạn chiều rộng feedback
            child: _buildItemTile(context, item),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.5, child: _buildItemTile(context, item)),
        child: _buildItemTile(context, item),
      );
    }
    
    // Nếu có con, nó là một ExpansionTile
    return ExpansionTile(
      key: PageStorageKey(item.id), // Giữ trạng thái mở/đóng khi cuộn
      tilePadding: EdgeInsets.zero,
      title: Draggable<Item>(
        data: item,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250 - 16),
            child: _buildItemTile(context, item, isParent: true),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.5, child: _buildItemTile(context, item, isParent: true)),
        child: _buildItemTile(context, item, isParent: true),
      ),
      // Xóa icon mặc định
      trailing: const SizedBox.shrink(), 
      // Xây dựng danh sách con một cách đệ quy
      children: children.map((child) => SourceExpansionItem(
        key: ValueKey(child.id),
        item: child,
        allSourceItems: allSourceItems,
        itemKeys: itemKeys,
      )).toList(),
    );
  }
}