import 'dart:typed_data';

import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/services/excel_parser.dart';
import 'package:drag_and_drop/widgets/column_widget.dart';
import 'package:drag_and_drop/widgets/line_painter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DragDropScreen extends StatefulWidget {
  const DragDropScreen({super.key});
  @override
  State<DragDropScreen> createState() => _DragDropScreenState();
}

class _DragDropScreenState extends State<DragDropScreen> {
  final Map<String, GlobalKey> _itemKeys = {};
  // Key này bây giờ chỉ dành cho khu vực cuộn
  final GlobalKey _scrollableAreaKey = GlobalKey();

  static const double sourceColumnWidth = 250.0;
  static const double otherColumnWidth = 200.0;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    context.read<DragDropBloc>().add(LoadItems());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, // Rất quan trọng để đọc file trên web
      );

      if (result != null && result.files.single.bytes != null) {
        Uint8List fileBytes = result.files.single.bytes!;
        
        // Gọi service để phân tích
        final parser = ExcelDataParser();
        final newMasterItems = parser.parseItemsFromExcel(fileBytes);

        if (mounted) {
          // Gửi event mới đến BLoC
          context.read<DragDropBloc>().add(LoadItemsFromData(newMasterItems: newMasterItems));
        }
      } else {
        // Người dùng đã hủy việc chọn file
      }
    } catch (e) {
      // Xử lý lỗi (ví dụ: hiển thị SnackBar)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xử lý file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hierarchical Drag and Drop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Tải lên file Excel',
            onPressed: _pickAndProcessFile,
          ),
        ],
      ),
      body: BlocBuilder<DragDropBloc, DragDropState>(
        builder: (context, state) {
          if (state.columns.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = state.columns.expand((col) => col.items).toList();
          
          _itemKeys.removeWhere((key, value) => !allItems.any((item) => item.id == key));
          for (var item in allItems) {
            _itemKeys.putIfAbsent(item.id, () => GlobalKey());
          }
          
          final sourceColumn = state.sourceColumn;
          final scrollableColumns = state.columns.sublist(1);

          return Column(
            children: [
              // 1. UI BỘ LỌC
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  children: [
                    const Text('Góc nhìn Cột Nguồn:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: state.displayLevelStart,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Level 1 & 2')),
                          DropdownMenuItem(value: 2, child: Text('Level 2 & 3')),
                          DropdownMenuItem(value: 3, child: Text('Level 3 & 4')),
                        ],
                        onChanged: (newValue) {
                          if (newValue != null) {
                            context.read<DragDropBloc>().add(LevelFilterChanged(newStartLevel: newValue));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),

              // 2. PHẦN CÒN LẠI CỦA MÀN HÌNH - TÁI CẤU TRÚC
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cột nguồn cố định (nằm ngoài Stack vẽ)
                    SizedBox(
                      width: sourceColumnWidth,
                      child: ColumnWidget(
                        key: ValueKey(sourceColumn.id),
                        width: sourceColumnWidth,
                        columnId: sourceColumn.id,
                        title: sourceColumn.title,
                        items: sourceColumn.items,
                        itemKeys: _itemKeys,
                        displayLevelStart: state.displayLevelStart,
                      ),
                    ),
                    // Khu vực các cột có thể cuộn VÀ vẽ mũi tên
                    Expanded(
                      key: _scrollableAreaKey, // Gán key cho khu vực này
                      child: ClipRect(
                        child: Stack(
                          children: [
                            // Lớp nội dung cuộn
                            NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                setState(() {}); // Trigger vẽ lại khi cuộn
                                return true;
                              },
                              child: Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  scrollDirection: Axis.horizontal,
                                  itemCount: scrollableColumns.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == scrollableColumns.length) {
                                      return Container(
                                        width: otherColumnWidth,
                                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Center(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.add_box_outlined),
                                            label: const Text('Thêm Cột'),
                                            onPressed: () {
                                              context.read<DragDropBloc>().add(AddNewColumn());
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final column = scrollableColumns[index];
                                    return ColumnWidget(
                                      key: ValueKey(column.id),
                                      width: otherColumnWidth,
                                      columnId: column.id,
                                      title: column.title,
                                      items: column.items,
                                      itemKeys: _itemKeys,
                                      displayLevelStart: state.displayLevelStart,
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Lớp vẽ mũi tên, là anh em với lớp cuộn
                            IgnorePointer(
                              child: CustomPaint(
                                painter: LineAndArrowPainter(
                                  allItems: allItems,
                                  itemKeys: _itemKeys,
                                  stackKey: _scrollableAreaKey,
                                  // scrollController: _scrollController,
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}