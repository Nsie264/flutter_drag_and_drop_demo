import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/widgets/column_widget.dart';
import 'package:drag_and_drop/widgets/line_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DragDropScreen extends StatefulWidget {
  const DragDropScreen({super.key});
  @override
  State<DragDropScreen> createState() => _DragDropScreenState();
}

class _DragDropScreenState extends State<DragDropScreen> {
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey _stackKey = GlobalKey();

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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hierarchical Drag and Drop'),
      ),
      body: BlocBuilder<DragDropBloc, DragDropState>(
        builder: (context, state) {
          if (state.columns.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Tạo danh sách phẳng tất cả các item đang hiển thị
          final allItems = state.columns.expand((col) => col.items).toList();
          
          // Cập nhật danh sách GlobalKey
          for (var item in allItems) {
            _itemKeys.putIfAbsent(item.id, () => GlobalKey());
          }
          _itemKeys.removeWhere((key, value) => !allItems.any((item) => item.id == key));
          
          final sourceColumn = state.sourceColumn;
          final scrollableColumns = state.columns.sublist(1);

          return Column(
            children: [
              Expanded(
                child: Stack(
                  key: _stackKey,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: sourceColumnWidth,
                          child: ColumnWidget(
                            key: ValueKey(sourceColumn.id),
                            width: sourceColumnWidth,
                            columnId: sourceColumn.id,
                            title: sourceColumn.title,
                            items: sourceColumn.items,
                            itemKeys: _itemKeys, // Truyền key xuống
                          ),
                        ),
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              setState(() {}); // Vẽ lại painter khi cuộn
                              return true;
                            },
                            child: Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: ListView.builder(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                itemCount: scrollableColumns.length,
                                itemBuilder: (context, index) {
                                  final column = scrollableColumns[index];
                                  return ColumnWidget(
                                    key: ValueKey(column.id),
                                    width: otherColumnWidth,
                                    columnId: column.id,
                                    title: column.title,
                                    items: column.items,
                                    itemKeys: _itemKeys, // Truyền key xuống
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Lớp vẽ mũi tên
                    IgnorePointer(
                      child: CustomPaint(
                        painter: LineAndArrowPainter(
                          allItems: allItems,
                          itemKeys: _itemKeys,
                          stackKey: _stackKey,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Thêm Cột Mới'),
                  onPressed: () {
                    // context.read<DragDropBloc>().add(AddNewColumn());
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}