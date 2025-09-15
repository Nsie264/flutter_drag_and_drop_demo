import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// 1. Định nghĩa State
class DragState extends Equatable {
  final bool isDragging;

  const DragState({this.isDragging = false});

  @override
  List<Object> get props => [isDragging];
}

// 2. Tạo Cubit
class DragCubit extends Cubit<DragState> {
  DragCubit() : super(const DragState());

  void startDragging() {
    print('Cubit: Drag Started');
    emit(const DragState(isDragging: true));
  }

  void endDragging() {
    print('Cubit: Drag Ended');
    emit(const DragState(isDragging: false));
  }
}