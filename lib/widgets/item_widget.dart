// // lib/widgets/item_widget.dart

// import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
// import 'package:drag_and_drop/cubit/drag_cubit.dart';
// import 'package:drag_and_drop/models/item.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// class ItemWidget extends StatefulWidget {
//   final Item item;
//   final GlobalKey itemKey;
//   final Function(String itemId) onConnectionDragStarted;
//   final Function(DragUpdateDetails) onConnectionDragUpdated;
//   final VoidCallback onConnectionDragEnded;
//   final bool isHighlighted;
//   const ItemWidget({
//     super.key,
//     required this.item,
//     required this.itemKey,
//     required this.onConnectionDragStarted,
//     required this.onConnectionDragUpdated,
//     required this.onConnectionDragEnded,
//     this.isHighlighted = false,
//   });

//   @override
//   State<ItemWidget> createState() => _ItemWidgetState();
// }

// class _ItemWidgetState extends State<ItemWidget> {
//   bool _isHovering = false;

//   @override
//   Widget build(BuildContext context) {
//     // <--- THAY ĐỔI 1: Gọi _buildItemContent với key cho widget gốc
//     Widget itemContent = _buildItemContent(context, key: widget.itemKey);

//     if (widget.item.columnId > 1) {
//       itemContent = DragTarget<String>(
//         onWillAcceptWithDetails: (details) {
//           final connectionData = details.data;
//           if (!connectionData.startsWith('connection_')){
//             print('Invalid connection data: $connectionData');
//             return false;
//           }

//           // Phân tích chuỗi dữ liệu mới: 'connection_id_columnId'
//           final parts = connectionData.split('_');
//           if (parts.length < 3) {
//             print('Invalid connection data format: $connectionData');
//             return false;
//           }

//           final fromItemId = parts[1];
//           final fromColumnId = int.tryParse(parts[2]) ?? -1;
//           final toColumnId = widget.item.columnId;

//           // Quy tắc: Không tự nối, và cột đích phải lớn hơn cột nguồn
//           final canAccept =
//               fromItemId != widget.item.id && toColumnId >= fromColumnId;
//           return canAccept;
//         },
//         onAcceptWithDetails: (details) {
//           final connectionData = details.data;
//           final fromItemId = connectionData.split('_')[1];
//           context.read<DragDropBloc>().add(
//             AddConnection(fromItemId: fromItemId, toItemId: widget.item.id),
//           );
//         },
//         builder: (context, candidateData, rejectedData) {
//           return _buildItemContent(
//             context,
//             key: widget.itemKey,
//             isTargetForConnection: candidateData.isNotEmpty,
//           );
//         },
//       );
//     }

//     return MouseRegion(
//       onEnter: (_) {
//         if (!context.read<DragCubit>().state.isDragging) {
//           setState(() => _isHovering = true);
//         }
//       },
//       onExit: (_) => setState(() => _isHovering = false),
//       child: Row(
//         children: [
//           GestureDetector(
//             onDoubleTap: () {
//               if (widget.item.columnId > 1)
//                 context.read<DragDropBloc>().add(
//                   HighlightChain(itemId: widget.item.id),
//                 );
//             },
//             child: Draggable<Item>(
//               data: widget.item,
//               onDragStarted: () => context.read<DragCubit>().startDragging(),
//               onDragEnd: (details) => context.read<DragCubit>().endDragging(),
//               onDraggableCanceled: (v, o) =>
//                   context.read<DragCubit>().endDragging(),
//               feedback: Theme(
//                 data: Theme.of(context), // Cung cấp Theme cho feedback
//                 child: Material(
//                   color: Colors.transparent,

//                   child: _buildItemContent(context, isDragging: true),
//                 ),
//               ),
//               childWhenDragging: Opacity(
//                 opacity: 0.5,
//                 child: _buildItemContent(context, key: widget.itemKey),
//               ),
//               child: itemContent,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildItemContent(
//     BuildContext context, {
//     Key? key,
//     bool isDragging = false,
//     bool isTargetForConnection = false,
//   }) {
//     const double dragHandleSize = 15.0;
//     return Container(
//       color: Colors.transparent,
//       child: Row(
//         children: [
//           Stack(
//             clipBehavior: Clip.none,
//             alignment: Alignment.center,
//             children: [
//               Container(
//                 key: key,
//                 width: 150,
//                 height: 35,
//                 margin: const EdgeInsets.only(top: 4, bottom: 4),
//                 padding: const EdgeInsets.all(8.0),
//                 decoration: BoxDecoration(
//                   color: widget.isHighlighted
//                       ? Colors.red.shade100
//                       : (isTargetForConnection
//                             ? Colors.green.shade100
//                             : Colors.blue.shade100),
//                   borderRadius: BorderRadius.circular(8.0),
//                   border: widget.isHighlighted
//                       ? Border.all(color: Colors.red.shade700, width: 2)
//                       : (isTargetForConnection
//                             ? Border.all(color: Colors.green, width: 2)
//                             : null),
//                 ),
//                 child: Center(
//                   child: Text(
//                     widget.item.name,
//                     style: TextStyle(
//                       color: isDragging ? Colors.grey.shade700 : Colors.black87,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ),
//               if (widget.item.columnId > 1 && !isDragging)
//                 Positioned(
//                   top: 0,
//                   right: 0,
//                   child: InkWell(
//                     onTap: () {
//                       context.read<DragDropBloc>().add(
//                         RemoveItem(item: widget.item),
//                       );
//                     },
//                     customBorder: const CircleBorder(),
//                     child: Container(
//                       padding: const EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.grey.withOpacity(0.5),
//                             blurRadius: 2,
//                           ),
//                         ],
//                       ),
//                       child: Icon(
//                         Icons.close,
//                         size: 14,
//                         color: Colors.red.shade700,
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           if (widget.item.columnId > 1)
//             AnimatedOpacity(
//               opacity: _isHovering && !isDragging ? 1.0 : 0.0,
//               duration: const Duration(milliseconds: 200),
//               child: Draggable<String>(
//                 data: 'connection_${widget.item.id}_${widget.item.columnId}',
//                 onDragStarted: () {
//                   widget.onConnectionDragStarted(widget.item.id);
//                   context.read<DragCubit>().startDragging();
//                 },
//                 onDragUpdate: widget.onConnectionDragUpdated,
//                 onDragEnd: (details) {
//                   widget.onConnectionDragEnded();
//                   context.read<DragCubit>().endDragging();
//                 },
//                 onDraggableCanceled: (v, o) {
//                   widget.onConnectionDragEnded();
//                   context.read<DragCubit>().endDragging();
//                 },
//                 feedback: Container(
//                   width: dragHandleSize,
//                   height: dragHandleSize,
//                   decoration: const BoxDecoration(
//                     color: Colors.blue,
//                     shape: BoxShape.circle,
//                   ),
//                 ),
//                 child: Container(
//                   width: dragHandleSize,
//                   height: dragHandleSize,
//                   decoration: const BoxDecoration(
//                     color: Colors.blue,
//                     shape: BoxShape.circle,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
