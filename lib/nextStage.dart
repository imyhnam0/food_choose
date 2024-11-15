import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';
import 'package:provider/provider.dart';

class NextstagePage extends StatefulWidget {
  final String gameId;

  const NextstagePage({super.key, required this.gameId});

  @override
  State<NextstagePage> createState() => _NextstagePageState();
}

class _NextstagePageState extends State<NextstagePage> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
