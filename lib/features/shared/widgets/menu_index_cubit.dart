import 'package:flutter_bloc/flutter_bloc.dart';

class MenuIndexState {
  final int index;
  MenuIndexState({this.index = 0});
  MenuIndexState copyWith({int? index}) =>
      MenuIndexState(index: index ?? this.index);
}

class MenuIndexCubit extends Cubit<MenuIndexState> {
  MenuIndexCubit() : super(MenuIndexState());
  void setIndex(int index) => emit(state.copyWith(index: index));
}
