import 'package:flutter/material.dart';
import 'invite.dart';
import 'dart:math';

class pickPeoplePage extends StatefulWidget {
  const pickPeoplePage({super.key});

  @override
  State<pickPeoplePage> createState() => _pickPeoplePageState();
}

class _pickPeoplePageState extends State<pickPeoplePage> {
  int _counter = 0;
  int? selectedValue;
  List<TextEditingController> textControllers = [];
  final Random _random = Random();

  void _incrementCounter() {
    setState(() {
      _counter++;
      textControllers.add(TextEditingController());
    });
  }

  void _decrementCounter() {
    setState(() {
      if (_counter > 0) {
        _counter--;
        textControllers.removeLast().dispose();
      }
    });
  }

  void _selectValue(int value) {
    setState(() {
      selectedValue = value;
    });
  }

  void _selectRandomValue() {
    if (_counter > 0) {
      setState(() {
        selectedValue = _random.nextInt(_counter) + 1; // 1부터 _counter까지 랜덤 선택
      });
    }
  }

  void _start() {
    if (selectedValue == null) {
      _selectRandomValue(); // 아무 버튼도 누르지 않았을 때 랜덤 선택
    }

    bool allFilled =
    textControllers.every((controller) => controller.text.isNotEmpty);

    if (allFilled) {
      final result = textControllers[selectedValue! - 1].text;
      _showResultDialog(result);
    } else {
      _showErrorDialog();
    }
  }

  void _reset() {
    setState(() {
      _counter = 0;
      selectedValue = null;
      textControllers.forEach((controller) => controller.dispose());
      textControllers.clear();
    });
  }

  void _showResultDialog(String result) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('뽑기 결과'),
          content: Text(result.isNotEmpty ? result : '값이 입력되지 않았습니다.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('오류'),
          content: const Text('모든 값을 입력해주세요.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('닫기'),
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
        title: Text(
          '제비뽑기',
          style: TextStyle(fontSize: 40),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              '인원수를 고르세요',
              style: TextStyle(fontSize: 24),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _decrementCounter,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '$_counter',
                  style: const TextStyle(fontSize: 40),
                ),
                IconButton(
                  onPressed: _incrementCounter,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: List.generate(_counter, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: TextField(
                    controller: textControllers[index],
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '인원 ${index + 1}',
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _start,
                  child: const Text('시작'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _reset,
                  child: const Text('초기화'),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in textControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
