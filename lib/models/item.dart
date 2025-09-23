import 'package:equatable/equatable.dart';

class Item extends Equatable {
  final String id; // ID duy nhất của instance này
  final String originalId; // ID của item gốc, để biết các item copy từ đâu
  final String name;
  final int columnId;
  final String? parentId;
  final String? nextItemId;

  const Item({
    required this.id,
    required this.originalId,
    required this.name,
    required this.columnId,
    this.parentId,
    this.nextItemId,
  });

  Item copyWith({
    String? id,
    int? columnId,
    String? parentId,
    String? nextItemId,

  }) {
    return Item(
      id: id ?? this.id,
      originalId: originalId,
      name: name,
      columnId: columnId ?? this.columnId,
      parentId: parentId ?? this.parentId,
      nextItemId: nextItemId ?? this.nextItemId,
    );
  }

  int get itemLevel {
    // id có dạng xx-yy-zz-ttt (đều là các chữ số nguyên dương)
    // xx-00-00-000 là level 1
    // xx-yy-00-000 là level 2
    // xx-yy-zz-000 là level 3
    // xx-yy-zz-ttt là level 4
    // lưu ý có trường hợp id là xx-00-zz-000 (level 3)
    // kiểm tra từ dưới lên
    final parts = originalId.split('-');
    if (parts.length != 4) return 0;
    if (parts[3] != '000') return 4;
    if (parts[2] != '00') return 3;
    if (parts[1] != '00') return 2;
    return 1;
  }

  bool isParentOf(String otherOriginalId) {
    // lấy tất cả các phần có nghĩa của originalId
    // ví dụ 1-2-00-000 => 1-2
    // ví dụ 1-00-00-000 => 1

    final parts = originalId.split('-');
    if (parts.length != 4) return false;
    final meaningfulParts = parts.takeWhile((part) => part != '00').toList();
    final meaningfulOriginalId = meaningfulParts.join('-');
    return otherOriginalId.startsWith(meaningfulOriginalId);
  }

  bool isChildOf(String otherOriginalId) {
    final parts = otherOriginalId.split('-');
    if (parts.length != 4) return false;
    final meaningfulParts = parts
        .takeWhile((part) => part != '00')
        .toList()
        .join('-');
    return originalId.startsWith(meaningfulParts);
  }

  bool isSiblingOf(String otherOriginalId) {
    final parts = originalId.split('-');
    final otherParts = otherOriginalId.split('-');
    if (parts.length != 4 || otherParts.length != 4) return false;

    // cùng level
    int level = itemLevel;
    if (level !=
        Item(
          id: '',
          originalId: otherOriginalId,
          name: '',
          columnId: 0,
        ).itemLevel) {
      return false;
    }

    // cùng parent
    if (level == 1) {
      return true; // cùng level 1 thì chắc chắn là anh em
    } else {
      final parentParts = parts.sublist(0, level - 1);
      final otherParentParts = otherParts.sublist(0, level - 1);
      return parentParts.join('-') == otherParentParts.join('-');
    }
  }

  @override
  List<Object?> get props => [id, originalId, name, columnId, parentId];
}
