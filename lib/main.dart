import 'package:flutter/material.dart';
import 'package:foodchoose/meetingroom.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:foodchoose/loginpage.dart';
import 'firebase_options.dart';
import 'user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loginpage.dart';
import 'signuppage.dart';
import 'invite.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'foodchoose.dart';
import 'invitemessage.dart';
import 'loginpage.dart';
import 'myinfo.dart';
import 'meetingroom.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('uid');

    if (uid != null) {
      Provider.of<UserProvider>(context, listen: false).setUid(uid);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? Myuid;
  List<Map<String, String>> participants = []; // 방 참가자 리스트
  String? gameId; // 현재 사용자가 속한 게임 방 ID
  bool isReady = false; // 내가 준비 상태인지 여부
  Set<Map<String, dynamic>> processedRequests = {};

  @override
  void initState() {
    super.initState();
    Myuid = Provider.of<UserProvider>(context, listen: false).uid;
    fetchParticipants(); // 참가자 목록 가져오기
  }

  // 방에 속한 참가자 가져오기
  void fetchParticipants() {
    _firestore
        .collection('games')
        .where('participants', arrayContains: Myuid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final gameDoc = snapshot.docs.first;
        gameId = gameDoc.id;
        final participantUids =
            List<String>.from(gameDoc['participants'] ?? []);
        updateParticipantList(participantUids);
      } else {
        setState(() {
          participants = [];
          gameId = null;
        });
      }
    });
  }

  // 참가자 UID를 기준으로 Firestore에서 이름 가져오기
  Future<void> updateParticipantList(List<String> participantUids) async {
    List<Map<String, String>> updatedParticipants = [];
    for (String uid in participantUids) {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        updatedParticipants.add({
          'uid': uid,
          'name': userDoc['name'],
        });
      }
    }
    setState(() {
      participants = updatedParticipants;
    });
  }

  Future<void> toggleReadyStatus() async {
    if (gameId == null) return;

    try {
      // Firestore에서 현재 readyStatus를 가져오기
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      final Map<String, dynamic> readyStatus =
          gameDoc.data()?['readyStatus'] ?? {};

      // 현재 사용자의 상태를 반전시켜 업데이트
      readyStatus[Myuid!] = !isReady;

      // Firestore 업데이트
      await _firestore.collection('games').doc(gameId).update({
        'readyStatus': readyStatus,
      });

      // 로컬 상태 업데이트
      setState(() {
        isReady = readyStatus[Myuid!]!;
      });
    } catch (e) {
      print('Error toggling ready status: $e');
    }
  }

  Future<void> startGame() async {
    if (gameId == null) return;

    final gameDoc = await _firestore.collection('games').doc(gameId).get();
    final readyStatus = gameDoc['readyStatus'] ?? {};

    // 모든 참가자가 준비 상태인지 확인
    if (readyStatus.values.every((ready) => ready == true)) {
      // Firestore에서 gameState를 "started"로 업데이트
      await _firestore.collection('games').doc(gameId).update({
        'gameState': 'started',
      });

      // 모든 참가자의 readyStatus를 false로 초기화
      final updatedReadyStatus =
          readyStatus.map((key, value) => MapEntry(key, false));
      await _firestore.collection('games').doc(gameId).update({
        'readyStatus': updatedReadyStatus,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게임이 시작되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 참가자가 준비 완료해야 합니다.')),
      );
    }
  }

// 초대 요청 수락
  Future<void> acceptInvite(Map<String, dynamic> invite) async {
    final senderName = invite['senderName'];
    final senderUid = invite['senderUid'];
    final whatGame = invite['whatgame'];

    // Firestore에서 현재 사용자 이름 가져오기
    final currentUserDoc =
    await _firestore.collection('users').doc(Myuid).get();
    final currentUserName = currentUserDoc['name'];

    // 초대 요청 제거
    await _firestore.collection('users').doc(Myuid).update({
      'gameRequests': FieldValue.arrayRemove([invite]),
    });
    setState(() {
      processedRequests.remove(invite); // 수락한 요청을 제거
    });


    // 컬렉션 선택: 투표 초대 -> games, 미팅 정하기 -> meetingRooms
    final targetCollection = whatGame == '투표 초대' ? 'games' : 'meetingRooms';


    // 기존 방 검색
    final existingGameQuery = await _firestore
        .collection(targetCollection)
        .where('participants', arrayContains: senderUid)
        .get();

    String gameId;

    if (existingGameQuery.docs.isNotEmpty) {
      // 기존 방이 있으면 그 방에 참가자 추가
      final gameDoc = existingGameQuery.docs.first;
      gameId = gameDoc.id;

      await _firestore.collection(targetCollection).doc(gameId).update({
        'participants': FieldValue.arrayUnion([Myuid]),
        'participantDetails': FieldValue.arrayUnion([
          {'uid': Myuid, 'name': currentUserName}
        ]),
      });
    } else {
      // 기존 방이 없으면 새 방 생성
      gameId = DateTime.now().millisecondsSinceEpoch.toString();
      if(whatGame=='투표 초대'){
        await _firestore.collection(targetCollection).doc(gameId).set({
          'participants': [senderUid, Myuid], // 초대한 사람과 현재 사용자 추가
          'participantDetails': [
            {'uid': senderUid, 'name': senderName},
            {'uid': Myuid, 'name': currentUserName}
          ],
          'readyStatus': {}, // 초기화된 레디 상태
          'gameState': 'waiting', // 초기 상태는 대기 상태
          'foodchoose': 'waiting',
          'resultfood': 'waiting',
          'nextStage': 'waiting',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      else{
        await _firestore.collection(targetCollection).doc(gameId).set({
          'participants': [senderUid, Myuid], // 초대한 사람과 현재 사용자 추가
          'participantDetails': [
            {'uid': senderUid, 'name': senderName},
            {'uid': Myuid, 'name': currentUserName}
          ],
          'readyStatus': {}, // 초기화된 레디 상태
          'createdAt': FieldValue.serverTimestamp(),
        });

      }

    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$senderName님의 초대를 수락했습니다.')),
    );
  }

  // 초대 요청 거절
  Future<void> rejectInvite(Map<String, dynamic> invite) async {
    final senderName = invite['senderName'];

    await _firestore.collection('users').doc(Myuid).update({
      'gameRequests': FieldValue.arrayRemove([invite]),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$senderName님의 초대를 거절했습니다.')),
    );
  }

  // 참가자 나가기
  Future<void> leaveGame(String uid) async {
    if (gameId == null) return;

    // 게임에서 참가자 제거
    await _firestore.collection('games').doc(gameId).update({
      'participants': FieldValue.arrayRemove([uid]),
      'participantDetails': FieldValue.arrayRemove([
        {
          'uid': uid,
          'name': participants.firstWhere((p) => p['uid'] == uid)['name']
        }
      ]),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('방에서 나갔습니다.')),
    );
  }

  // 초대 요청 팝업
  void showInviteDialog(Map<String, dynamic> invite) {
    final senderName = invite['senderName']; // 초대한 사람의 이름 가져오기
    final whatgame = invite['whatgame']; // 초대한 사람의 게임 이름 가져오기

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: Colors.deepPurpleAccent.withOpacity(0.9),
          title: Text(
            whatgame,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 5.0,
                  color: Colors.black45,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
          content: Text(
            '$senderName님이 초대했습니다.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                rejectInvite(invite);
                Navigator.pop(context); // 팝업 닫기
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                foregroundColor: Colors.redAccent,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('거절'),
            ),
            ElevatedButton(
              onPressed: () {
                acceptInvite(invite);
                Navigator.pop(context); // 팝업 닫기
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
              child: const Text(
                '수락',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
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
        title: const Text(
          '투표 선정',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 5.0,
                color: Colors.black45,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyInfoPage()),
              );
            },
            icon: const Icon(Icons.person, size: 30, color: Colors.white),
          ),
        ],
        leading: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton(
            onPressed: () async {
              // 로그아웃 처리
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('uid'); // SharedPreferences에서 UID 제거

              // 로그인 페이지로 이동
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
            child: const Text(
              'logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: gameId == null
            ? StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('users').doc(Myuid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 사용자 데이터 가져오기
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final gameRequests = userData['gameRequests'] ?? [];

                  // 초대 요청이 있을 때 팝업 표시
                  if (gameRequests.isNotEmpty) {
                    final latestRequest = gameRequests.last;

                    if (!processedRequests.contains(latestRequest)) {
                      processedRequests.add(latestRequest);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showInviteDialog(latestRequest);
                      });
                    }
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '현재 방에 참가하지 않았습니다.',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 4.0,
                                color: Colors.black54,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 15),
                                backgroundColor: Colors.lightBlueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                                shadowColor: Colors.blueAccent,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const InvitePage()),
                                );
                              },
                              child: const Text(
                                '친구 목록 보기',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 15),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 15),
                                backgroundColor: Colors.purpleAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 10,
                                shadowColor: Colors.purple,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const InviteMessagesPage()),
                                );
                              },
                              child: const Text(
                                '받은 초대 메시지',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20), // 첫 번째 버튼 그룹과 두 번째 버튼 그룹 간격
                        // 두 번째 버튼 그룹: 미팅 정하기, 뽑기
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                backgroundColor: Colors.greenAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 10,
                                shadowColor: Colors.green,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => AvailabilityPage(myuid: Myuid!)),
                                );
                              },
                              child: const Text(
                                '미팅 정하기',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 15),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 15),
                                backgroundColor: Colors.orangeAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 10,
                                shadowColor: Colors.orange,
                              ),
                              onPressed: () {

                              },
                              child: const Text(
                                '제비뽑기',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              )
            : StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('games').doc(gameId).snapshots(),
                builder: (context, gameSnapshot) {
                  if (!gameSnapshot.hasData || gameSnapshot.data == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 게임 데이터 가져오기
                  final gameData =
                      gameSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  final readyStatus = gameData['readyStatus'] ?? {};
                  final allReady = participants.every(
                      (participant) => readyStatus[participant['uid']] == true);
                  final gameState = gameData['gameState'] ?? 'waiting';
                  // 게임이 시작되었는지 확인
                  if (gameState == 'started') {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                FoodChoosePage(gameId: gameId!)),
                      );
                    });
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '현재 방 참가자',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.purpleAccent,
                            shadows: [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.black38,
                                offset: Offset(3, 3),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 300,
                          height: 200,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.deepPurple, Colors.indigoAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                spreadRadius: 5,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: participants.isEmpty
                              ? const Center(
                                  child: Text(
                                    '현재 참가자가 없습니다.',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: participants.length,
                                  itemBuilder: (context, index) {
                                    final participant = participants[index];
                                    final isParticipantReady =
                                        readyStatus[participant['uid']] ??
                                            false;

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 5,
                                            offset: const Offset(2, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            participant['name']!,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Icon(
                                            isParticipantReady
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: isParticipantReady
                                                ? Colors.green
                                                : Colors.red,
                                            size: 24,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 30),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 15),
                                backgroundColor: Colors.greenAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 10,
                                shadowColor: Colors.green,
                              ),
                              onPressed: toggleReadyStatus,
                              child: Text(
                                isReady ? '준비 취소' : '준비하기',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 15),
                                backgroundColor: Colors.orangeAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 10,
                                shadowColor: Colors.orange,
                              ),
                              onPressed: allReady ? startGame : null,
                              child: const Text(
                                '게임 시작',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 15),
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 10,
                                shadowColor: Colors.red,
                              ),
                              onPressed: () async {
                                await leaveGame(Myuid!);
                              },
                              child: const Text(
                                '나가기',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 15),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 15),
                                backgroundColor: Colors.lightBlueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 10,
                                shadowColor: Colors.blue,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const InvitePage()),
                                );
                              },
                              child: const Text(
                                '친구 목록',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
