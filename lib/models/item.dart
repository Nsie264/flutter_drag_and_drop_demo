import 'package:equatable/equatable.dart';

enum DragRole { parent, child }
enum DragMode { single, group }
class Item extends Equatable {
  final String id;
  final String originalId;
  final String name;
  final int columnId;
  final String? parentId;
  final String? nextItemId;
  final bool isGroupPlaceholder;
  final List<String> linkedChildrenOriginalIds;
  final bool isUsed;
  final DragRole dragRole;
  final DragMode dragMode;

  const Item({
    required this.id,
    required this.originalId,
    required this.name,
    required this.columnId,
    this.parentId,
    this.nextItemId,
    this.isGroupPlaceholder = false,
    this.linkedChildrenOriginalIds = const [],
    this.isUsed = false,
    this.dragRole = DragRole.child,
    this.dragMode = DragMode.single,
  });

  // Getter để tính toán level từ originalId
  int get itemLevel {
    final parts = originalId.split('-');

    // Thêm một bước kiểm tra để đảm bảo định dạng ID luôn đúng
    if (parts.length != 4) {
      // Trả về một giá trị mặc định hoặc ném ra lỗi nếu ID không hợp lệ
      // Trả về 0 hoặc 1 là một lựa chọn an toàn.
      return 1; 
    }

    // Kiểm tra ngược từ cuối lên.
    // Nếu phần tử cuối cùng (chi tiết nhất) khác không, nó là level 4.
    if (parts[3] != '000') {
      return 4;
    }

    // Nếu không, kiểm tra phần tử áp chót.
    if (parts[2] != '00') {
      return 3;
    }

    // Tiếp tục kiểm tra ngược lên.
    if (parts[1] != '00') {
      return 2;
    }

    // Nếu tất cả các phần trên đều là "không", nó là level 1.
    return 1;
  }

  // --- GETTER originalParentId ĐƯỢC CẬP NHẬT VỚI LOGIC "TÌM CHA LÙI" ---
  /// Tìm originalId của cha.
  /// Ví dụ: '1-02-01-000' (cấp 3) -> cha là '1-02-00-000' (cấp 2).
  /// LƯU Ý QUAN TRỌNG: Getter này chỉ xác định ID cha tiềm năng dựa trên cấu trúc chuỗi.
  /// Nó không đảm bảo item cha đó thực sự tồn tại trong danh sách dữ liệu gốc.
  String? get potentialParentOriginalId {
    final parts = originalId.split('-');
    switch (itemLevel) {
      case 2:
        return '${parts[0]}-00-00-000';
      case 3:
        return '${parts[0]}-${parts[1]}-00-000';
      case 4:
        return '${parts[0]}-${parts[1]}-${parts[2]}-000';
      default:
        return null;
    }
  }
  // --------------------------------------------------------------------

  bool isParentOf(String childOriginalId) {
    // Logic này có thể sẽ cần được xem xét lại khi triển khai BLoC
    if (itemLevel >= 4) return false;
    final parentPrefix = originalId.substring(0, (itemLevel * 3));
    return childOriginalId.startsWith(parentPrefix) && itemLevel < 4;
  }

  Item copyWith({
    String? id,
    String? originalId,
    String? name,
    int? columnId,
    String? parentId,
    String? nextItemId,
    bool? isGroupPlaceholder,
    List<String>? linkedChildrenOriginalIds,
    bool setParentIdToNull = false,
    bool setNextItemIdToNull = false,
    bool? isUsed,
    DragRole? dragRole,
    DragMode? dragMode,
  }) {
    return Item(
      id: id ?? this.id,
      originalId: originalId ?? this.originalId,
      name: name ?? this.name,
      columnId: columnId ?? this.columnId,
      parentId: setParentIdToNull ? null : (parentId ?? this.parentId),
      nextItemId: setNextItemIdToNull ? null : (nextItemId ?? this.nextItemId),
      isGroupPlaceholder: isGroupPlaceholder ?? this.isGroupPlaceholder,
      linkedChildrenOriginalIds: linkedChildrenOriginalIds ?? this.linkedChildrenOriginalIds,
      isUsed: isUsed ?? this.isUsed,
      dragRole: dragRole ?? this.dragRole,
      dragMode: dragMode ?? this.dragMode,
    );
  }

  @override
  List<Object?> get props => [
        id,
        originalId,
        name,
        columnId,
        parentId,
        nextItemId,
        isGroupPlaceholder,
        linkedChildrenOriginalIds,
        isUsed,
        dragMode,
      ];
}