import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/cubit/drag_cubit.dart';
import 'package:drag_and_drop/screens/drag_drop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Drag and Drop Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => DragDropBloc()..add(LoadItems()),
          ),
          BlocProvider(
            create: (context) => DragCubit(),
          ),
        ],
        child: const DragDropScreen(),
      ),
    );
  }
}
