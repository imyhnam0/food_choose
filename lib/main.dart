import 'package:flutter/material.dart';
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
      home: LoginPage(),
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
  List<Map<String, String>> acceptedParticipants = []; // 수락한 사람들의 리스트

  @override
  void initState() {
    super.initState();
    Myuid = Provider.of<UserProvider>(context, listen: false).uid;
  }

  // 초대 요청 수락
  Future<void> acceptInvite(Map<String, dynamic> invite) async {
    final senderName = invite['senderName'];
    final senderUid = invite['senderUid'];

    // Firestore에서 현재 사용자 이름 가져오기
    final currentUserDoc = await _firestore.collection('users').doc(Myuid).get();
    final currentUserName = currentUserDoc['name'];

    // 초대 요청 제거
    await _firestore.collection('users').doc(Myuid).update({
      'gameRequests': FieldValue.arrayRemove([invite]),
    });

    // 기존 방 검색
    final existingGameQuery = await _firestore
        .collection('games')
        .where('participants', arrayContains: senderUid)
        .get();

    String gameId;

    if (existingGameQuery.docs.isNotEmpty) {
      // 기존 방이 있으면 그 방에 참가자 추가
      final gameDoc = existingGameQuery.docs.first;
      gameId = gameDoc.id;

      await _firestore.collection('games').doc(gameId).update({
        'participants': FieldValue.arrayUnion([Myuid]),
      });
    } else {
      // 기존 방이 없으면 새 방 생성
      gameId = DateTime.now().millisecondsSinceEpoch.toString();
      print('생성된 gameId: $gameId');
      print('새 방 생성 시작');

      await _firestore.collection('games').doc(gameId).set({
        'participants': [senderUid, Myuid], // 초대한 사람과 현재 사용자 추가
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('새 방 생성 완료');
    }

    // 수락한 사람 리스트 업데이트
    setState(() {
      if (!acceptedParticipants.any((p) => p['uid'] == senderUid)) {
        acceptedParticipants.add({'uid': senderUid, 'name': senderName});
      }
      if (!acceptedParticipants.any((p) => p['uid'] == Myuid)) {
        acceptedParticipants.add({'uid': Myuid!, 'name': currentUserName});
      }
    });

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

  // 초대 요청 팝업
  void showInviteDialog(Map<String, dynamic> invite) {
    final senderName = invite['senderName']; // 초대한 사람의 이름 가져오기

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('게임 초대'),
          content: Text('$senderName님이 게임에 초대했습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                rejectInvite(invite);
                Navigator.pop(context); // 팝업 닫기
              },
              child: const Text('거절'),
            ),
            ElevatedButton(
              onPressed: () {
                acceptInvite(invite);
                Navigator.pop(context); // 팝업 닫기
              },
              child: const Text('수락'),
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
        title: const Text('음식 선정'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(Myuid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          var gameRequests = userData['gameRequests'] ?? [];

          // 초대 요청이 있을 때 팝업 표시
          if (gameRequests.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showInviteDialog(gameRequests.last);
            });
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Food',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // 네모 박스 추가: 수락한 사람들 리스트 표시
                Container(
                  width: 300,
                  height: 200,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    itemCount: acceptedParticipants.length,
                    itemBuilder: (context, index) {
                      final participant = acceptedParticipants[index];
                      return ListTile(
                        title: Text(participant['name']!),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        // Firestore에 게임 데이터 저장
                        final gameId = DateTime.now().millisecondsSinceEpoch.toString(); // 고유한 게임 ID 생성
                        await _firestore.collection('games').doc(gameId).set({
                          'participants': acceptedParticipants.map((p) => p['uid']).toList(),
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        // FoodChoosePage로 데이터 전달
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FoodChoosePage(
                              participants: acceptedParticipants,
                              gameId: gameId,
                            ),
                          ),
                        );
                      },
                      child: const Text('시작하기'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const InvitePage()),
                        );
                      },
                      child: const Text('친구목록'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


