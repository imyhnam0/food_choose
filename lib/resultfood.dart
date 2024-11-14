import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';


class ResultPage extends StatefulWidget {
  final List<String> foods;

  const ResultPage({super.key, required this.foods});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  Map<String, int> votes = {};
  List<String> currentSelection = [];
  int stage = 5; // 단계별 음식 개수 (5 -> 3 -> 1)

  @override
  void initState() {
    super.initState();
    currentSelection = widget.foods.expand((food) => food.split(',')).map((e) => e.trim()).toList();
    currentSelection = currentSelection.toSet().toList(); // 중복 제거
  }

  void resetVotes() {
    votes = {for (var food in currentSelection) food: 0};
  }

  void showResultsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('투표 결과'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: votes.entries.map((entry) {
              return Text('${entry.key}: ${entry.value}표');
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void filterTopFoods() {
    final sortedFoods = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final filtered = sortedFoods.where((entry) => entry.value > 0).toList();

    if (filtered.length <= stage) {
      currentSelection = filtered.map((entry) => entry.key).toList();
    } else {
      currentSelection = filtered.take(stage).map((entry) => entry.key).toList();
    }

    if (currentSelection.length == 1) {
      showFinalResult(currentSelection.first);
    } else {
      setState(() {
        stage = stage == 5 ? 3 : 1;
        resetVotes();
      });
    }
  }

  void showFinalResult(String winner) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('최종 선택'),
          content: Text('최종 선택된 음식은 "$winner"입니다!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // 결과 페이지 닫기
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(stage == 5
            ? 'Top 5 투표'
            : stage == 3
            ? 'Top 3 투표'
            : '최종 선택'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: currentSelection.length,
              itemBuilder: (context, index) {
                final food = currentSelection[index];
                return ListTile(
                  title: Text(food),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: () {
                      setState(() {
                        votes[food] = (votes[food] ?? 0) + 1;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              showResultsDialog();
              Future.delayed(const Duration(seconds: 2), () {
                Navigator.pop(context); // 결과 팝업 닫기
                filterTopFoods();
              });
            },
            child: const Text('결과 보기'),
          ),
        ],
      ),
    );
  }
}

