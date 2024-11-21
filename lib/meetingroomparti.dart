import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invite.dart';

class ParticipantsPage extends StatefulWidget {
  final String? myuid;
  const ParticipantsPage({super.key, required this.myuid});

  @override
  State<ParticipantsPage> createState() => _ParticipantsPageState();
}

class _ParticipantsPageState extends State<ParticipantsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> participants = [];
  bool isLoading = true;
  String? roomId;

  @override
  void initState() {
    super.initState();
    fetchParticipants();

  }
  Future<void> removeParticipant(String uid, String name) async {
    try {
      // 방에서 사용자 데이터 제거
      await _firestore.collection('meetingRooms').doc(roomId).update({
        'availability.${uid}': FieldValue.delete(), // availability 내 특정 UID 삭제
        'participants': FieldValue.arrayRemove([uid]), // 참가자 목록에서 제거
        'participantDetails': FieldValue.arrayRemove([
          {'uid': uid, 'name': name}
        ]), // 참가자 상세 정보에서 제거
      });
      setState(() {
        roomId = null; // 방 ID 초기화
        participants.removeWhere((participant) => participant['uid'] == uid);
      });


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("삭제를 완료하였습니다.")),
      );
    }catch(e){
      print('Error removing participant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("삭제에 실패하였습니다.")),
      );
    }

  }

  Future<void> fetchParticipants() async {
    // 방 검색
    final existingRoomQuery = await _firestore
        .collection('meetingRooms')
        .where('participants', arrayContains: widget.myuid)
        .get();

    if (existingRoomQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("현재 참여 중인 방이 없습니다.")),
      );
      return;
    }

    final roomDoc = existingRoomQuery.docs.first;
    roomId = roomDoc.id;

    try {
      final roomDoc = await _firestore.collection('meetingRooms').doc(roomId).get();

      if (roomDoc.exists) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        final participantDetails = List<Map<String, dynamic>>.from(roomData['participantDetails'] ?? []);

        setState(() {
          participants = participantDetails;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching participants: $e');
      setState(() {
        isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "참가자 목록",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvitePage(),
                ),
              );
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : participants.isEmpty
          ? const Center(child: Text("참가자가 없습니다."))
          : ListView.builder(
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(participant['name'][0]), // 참가자 이름 첫 글자
            ),
            title: Text(participant['name']),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => removeParticipant(participant['uid'],participant['name']),
            ),
          );
        },
      ),
    );
  }
}
