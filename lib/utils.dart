import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'foodchoose.dart';
import 'resultfood.dart';
import 'nextStage.dart';

// 페이지 이동 위젯 반환 함수
Widget getNextPageWidget(int pageNumber, String gameId) {
  switch (pageNumber) {
    case 1:
      return FoodChoosePage(gameId: gameId);
    case 2:
      return ResultPage(gameId: gameId);
    case 3:
      return NextstagePage(gameId: gameId);
    default:
      return const Center(child: Text('잘못된 페이지 번호'));
  }
}

// Firestore에 페이지 상태 업데이트
Future<void> updatePageStatus(String gameId, String myUid, int pageNumber) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    await firestore.collection('games').doc(gameId).update({
      'pageStatus.$myUid': pageNumber,
    });
    print('페이지 상태 업데이트 성공: $myUid -> $pageNumber');
  } catch (error) {
    print('페이지 상태 업데이트 실패: $error');
  }
}
