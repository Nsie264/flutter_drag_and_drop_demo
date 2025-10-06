import 'dart:typed_data';
import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/services/excel_exporter_service.dart';
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
  // Key cho toàn bộ khu vực `Expanded` cha
  final GlobalKey _paintAreaKey = GlobalKey();

  final GlobalKey _customPaintAreaKey = GlobalKey();

  static const double sourceColumnWidth = 250.0;
  static const double otherColumnWidth = 200.0;

  late final ScrollController _workingAreaHorizontalScrollController;
  late final ScrollController _workingAreaVerticalScrollController;

  @override
  void initState() {
    super.initState();
    _workingAreaHorizontalScrollController = ScrollController();
    _workingAreaVerticalScrollController = ScrollController();
    context.read<DragDropBloc>().add(LoadItems());
  }

  @override
  void dispose() {
    _workingAreaHorizontalScrollController.dispose();
    _workingAreaVerticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _exportData() async {
    // Hiển thị loading indicator (tùy chọn)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang chuẩn bị file Excel...')),
    );

    try {
      final exporter = ExcelExporterService();
      final columns = context.read<DragDropBloc>().state.columns;
      await exporter.exportWorkflow(columns);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File đã sẵn sàng để tải xuống.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xuất file thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddColumnDialog() async {
    String? selectedTeam = 'A'; // Giá trị mặc định
    String? selectedStation = '1';
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thêm Cột Mới'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown cho Tổ
                DropdownButtonFormField<String>(
                  value: selectedTeam,
                  decoration: const InputDecoration(labelText: 'Chọn Tổ'),
                  items: ['A', 'B', 'C'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text('Tổ $value'),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    selectedTeam = newValue;
                  },
                ),
                const SizedBox(height: 16),
                // Dropdown cho Trạm
                DropdownButtonFormField<String>(
                  value: selectedStation,
                  decoration: const InputDecoration(labelText: 'Chọn Trạm'),
                  items: ['1', '2', '3'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text('Trạm $value'),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    selectedStation = newValue;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hủy'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Thêm'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(
                    context,
                  ).pop({'team': selectedTeam!, 'station': selectedStation!});
                }
              },
            ),
          ],
        );
      },
    );

    // Xử lý kết quả từ Dialog
    if (result != null &&
        result.containsKey('team') &&
        result.containsKey('station')) {
      final title = 'Tổ ${result['team']} - Trạm ${result['station']}';
      // Gửi event đến BLoC với title mới
      if (mounted) {
        context.read<DragDropBloc>().add(AddNewColumn(title: title));
      }
    }
  }

  Future<void> _pickAndProcessFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        Uint8List fileBytes = result.files.single.bytes!;
        final parser = ExcelDataParser();
        final newMasterItems = parser.parseItemsFromExcel(fileBytes);
        if (mounted) {
          context.read<DragDropBloc>().add(
            LoadItemsFromData(newMasterItems: newMasterItems),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xử lý file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hierarchical Drag and Drop')),
      body: BlocBuilder<DragDropBloc, DragDropState>(
        builder: (context, state) {
          if (state.columns.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = state.columns.expand((col) => col.items).toList();
          _itemKeys.removeWhere(
            (key, value) => !allItems.any((item) => item.id == key),
          );
          for (var item in allItems) {
            _itemKeys.putIfAbsent(item.id, () => GlobalKey());
          }
          final sourceColumn = state.sourceColumn;
          final scrollableColumns = state.columns.sublist(1);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Bộ lọc Cột Nguồn:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: state.displayLevelStart,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Cấp 1 & 2')),
                          DropdownMenuItem(value: 2, child: Text('Cấp 2 & 3')),
                          DropdownMenuItem(value: 3, child: Text('Cấp 3 & 4')),
                        ],
                        onChanged: (newValue) {
                          if (newValue != null) {
                            context.read<DragDropBloc>().add(
                              LevelFilterChanged(newStartLevel: newValue),
                            );
                          }
                        },
                      ),
                    ),
                    Spacer(),
                    ElevatedButton.icon
                    (
                      icon: const Icon(Icons.upload_file),
                      onPressed: _pickAndProcessFile,
                      label: Text('Tải lên file Excel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Xuất Excel'),
                      onPressed: state.isExportEnabled ? _exportData : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isExportEnabled
                            ? Colors.green
                            : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                key: _paintAreaKey,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    setState(() {});
                    return true;
                  },
                  child: Row(
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
                          itemKeys: _itemKeys,
                          displayLevelStart: state.displayLevelStart,
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ClipRect(
                              key: _customPaintAreaKey,
                              child: Stack(
                                children: [
                                  Scrollbar(
                                    controller:
                                        _workingAreaVerticalScrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller:
                                          _workingAreaVerticalScrollController,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight,
                                        ),
                                        child: Scrollbar(
                                          controller:
                                              _workingAreaHorizontalScrollController,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            controller:
                                                _workingAreaHorizontalScrollController,
                                            scrollDirection: Axis.horizontal,
                                            child: IntrinsicHeight(
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  ...scrollableColumns.map((
                                                    column,
                                                  ) {
                                                    return ColumnWidget(
                                                      key: ValueKey(column.id),
                                                      width: otherColumnWidth,
                                                      columnId: column.id,
                                                      title: column.title,
                                                      items: column.items,
                                                      itemKeys: _itemKeys,
                                                      displayLevelStart: state
                                                          .displayLevelStart,
                                                    );
                                                  }),
                                                  Container(
                                                    width: otherColumnWidth,
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 8.0,
                                                        ),
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(
                                                        Icons.add_box_outlined,
                                                      ),
                                                      label: const Text(
                                                        'Thêm Cột',
                                                      ),
                                                      onPressed:
                                                          _showAddColumnDialog,
                                                      style: ElevatedButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 24,
                                                              vertical: 16,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: LineAndArrowPainter(
                                          allItems: allItems,
                                          itemKeys: _itemKeys,
                                          stackKey: _customPaintAreaKey,
                                          highlightedItemIds:
                                              state.highlightedItemIds,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
