import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String fName;
  final String lName;
  final String email;
  final Timestamp createdAt;
  final String userName;
  final List createdEvents;
  final List associatedEvents;
  final String phoneNumber;
  final String uid;

  UserModel({
    required this.phoneNumber,
    required this.fName,
    required this.lName,
    required this.email,
    required this.createdAt,
    required this.userName,
    required this.createdEvents,
    required this.associatedEvents,
    required this.uid,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      phoneNumber: map['phone_number'] ?? '',
      fName: map['first_name'] ?? '',
      lName: map['last_name'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp(0, 0),
      userName: map['username'] ?? '',
      createdEvents: map['created_events'] ?? [],
      associatedEvents: map['associated_events'] ?? [],
      uid: map['uid'] ?? '',
    );
  }

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) {
    return UserModel(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fName: firstName ?? fName,
      lName: lastName ?? lName,
      email: email,
      createdAt: createdAt,
      userName: userName,
      createdEvents: createdEvents,
      associatedEvents: associatedEvents,
      uid: uid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone_number': phoneNumber,
      'first_name': fName,
      'last_name': lName,
      'email': email,
      //'createdAt': createdAt,
      'username': userName,
      'created_events': createdEvents,
      'associated_events': associatedEvents,
      'uid': uid,
    };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final preferences = await SharedPreferences.getInstance();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.white, // Adjust as needed
  ));

  runApp(
    Phoenix(
      child: ProviderScope(
        overrides: [
          dataControllerProvider.overrideWithValue(DataController(preferences)),
        ],
        child: MyApp(),
      ),
    ),
  );
}

final dataControllerProvider = Provider<DataController>((ref) {
  return DataController(ref.watch as SharedPreferences);
});

final dataProvider = FutureProvider<List<UserModel>>((ref) async {
  final controller = ref.read(dataControllerProvider);
  return controller.fetchData();
});

class DataController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SharedPreferences _preferences;
  bool _isDataFromFirebase = false;

  DataController(this._preferences);

  List<UserModel> _cachedData = [];

  Future<List<UserModel>> fetchData() async {
    if (_cachedData.isNotEmpty) {
      _isDataFromFirebase = false;
      return _cachedData;
    }

    final cachedDataString = _preferences.getString('cachedData');
    if (cachedDataString != null) {
      final List<dynamic> cachedDataJson = json.decode(cachedDataString);
      _cachedData =
          cachedDataJson.map((json) => UserModel.fromMap(json)).toList();
      _isDataFromFirebase = false;
      return _cachedData;
    }

    QuerySnapshot querySnapshot = await _firestore
        .collection('users')
        .where('uid', isEqualTo: '5PfqnfRkPyYUEJBLOC8UhVpVozR2')
        .get();
    _cachedData = querySnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        _isDataFromFirebase = true;
        return UserModel.fromMap(data);
      } else {
        throw Exception();
      }
    }).toList();

    _preferences.setString('cachedData',
        json.encode(_cachedData.map((user) => user.toMap()).toList()));

    return _cachedData;
  }

  bool isDataFromFirebase() {
    return _isDataFromFirebase;
  }
}

class YourDataScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Data'),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final dataAsyncValue = ref.watch(dataProvider);
          return dataAsyncValue.when(
            data: (data) => _buildListView(data, ref),
            loading: () => CircularProgressIndicator(),
            error: (error, stackTrace) => Text('Error: $error'),
          );
        },
      ),
    );
  }

  Widget _buildListView(List<UserModel> data, WidgetRef ref) {
    final isDataFromFirebase =
        ref.read(dataControllerProvider).isDataFromFirebase();

    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(data[index].fName),
          subtitle: Text(data[index].email),
          trailing: Text(isDataFromFirebase ? 'Firebase' : 'Local'),
          // Display other properties as needed
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App',
      home: YourDataScreen(),
    );
  }
}
