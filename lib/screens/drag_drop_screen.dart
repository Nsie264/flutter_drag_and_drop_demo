// lib/screens/drag_drop_screen.dart

import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/cubit/drag_cubit.dart';
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

  Offset? _dragLineStart;
  Offset? _dragLineEnd;


  static const double sourceColumnWidth = 250.0;
  static const double otherColumnWidth = 200.0;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    context.read<DragCubit>(); 
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onConnectionDragStarted(String itemId) {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    final itemKey = _itemKeys[itemId]!;
    final itemBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (itemBox == null) return;
    final globalStartPosition = itemBox.localToGlobal(Offset(itemBox.size.width, itemBox.size.height / 2));
    final localStartPosition = stackBox.globalToLocal(globalStartPosition);
    setState(() {
      final shiftedStartPosition = Offset(localStartPosition.dx + 5, localStartPosition.dy);
      _dragLineStart = shiftedStartPosition;
      _dragLineEnd = shiftedStartPosition;
    });
  }

  void _onConnectionDragUpdated(DragUpdateDetails details) {

    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    setState(() {
      _dragLineEnd = stackBox.globalToLocal(details.globalPosition);
    });
  }

  void _onConnectionDragEnded() {
    setState(() {
      _dragLineStart = null;
      _dragLineEnd = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dynamic Drag and Drop'),
      ),
      body: BlocBuilder<DragDropBloc, DragDropState>(
        builder: (context, state) {
          if (state.columns.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = state.columns.expand((col) => col.items).toList();
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
                            width: sourceColumnWidth,
                            columnId: sourceColumn.id,
                            title: sourceColumn.title,
                            items: sourceColumn.items,
                            itemKeys: _itemKeys,
                            onConnectionDragStarted: _onConnectionDragStarted,
                            onConnectionDragUpdated: _onConnectionDragUpdated,
                            onConnectionDragEnded: _onConnectionDragEnded,
                            highlightedItemIds: state.highlightedItemIds,
                          ),
                        ),
                        
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (scrollNotification) {
                              setState(() {});
                              return true;
                            },
                            child: Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true, 
                              trackVisibility: true,
                              thickness: 8.0,
                              radius: const Radius.circular(4.0),
                              child: ListView.builder(
                                controller: _scrollController,
                                
                                scrollDirection: Axis.horizontal,
                                itemCount: scrollableColumns.length,
                                itemBuilder: (context, index) {
                                  final column = scrollableColumns[index];
                                  return ColumnWidget(
                                    width: otherColumnWidth,
                                    columnId: column.id,
                                    title: column.title,
                                    items: column.items,
                                    itemKeys: _itemKeys,
                                    onConnectionDragStarted: _onConnectionDragStarted,
                                    onConnectionDragUpdated: _onConnectionDragUpdated,
                                    onConnectionDragEnded: _onConnectionDragEnded,
                                    highlightedItemIds: state.highlightedItemIds,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    Positioned(
                      left: sourceColumnWidth, 
                      top: 0,
                      right: 0, // Kéo dài đến hết cạnh phải
                      bottom: 0, // Kéo dài đến hết cạnh dưới
                      child: ClipRect(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: LineAndArrowPainter(
                              connections: state.connections,
                              itemKeys: _itemKeys,
                              stackKey: _stackKey,
                              dragLineStart: _dragLineStart,
                              dragLineEnd: _dragLineEnd,
                              // Truyền offset cố định vào painter
                              clipOffset: const Offset(sourceColumnWidth, 0),
                              highlightedConnections: state.highlightedConnections,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                // ... (nút thêm cột không đổi)
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Thêm Cột Mới'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    context.read<DragDropBloc>().add(AddNewColumn());
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