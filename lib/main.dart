import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:location/location.dart';

void main() {
  runApp(FoodRecommendationApp());
}

class FoodRecommendationApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '점심 메뉴 추천',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('홈'),
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              child: Text('목록'),
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
            ),
            ListTile(
              title: Text('음식 추천'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MainPage()));
              },
            ),
            ListTile(
              title: Text('지도'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MapPage()));
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Text('홈 페이지입니다!', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String recommendedFood = '';
  List<String> foodList = [
    '피자',
    '햄버거',
    '학식',
    '파스타',
    '빵',
    '돈까스',
    '라면',
    '술',
  ];
  final random = Random();
  late Timer _timer;
  int currentIndex = 0;

  void recommendFood() {
    currentIndex = 0;
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        if (currentIndex < foodList.length) {
          recommendedFood = foodList[currentIndex];
          currentIndex++;
        } else {
          _timer.cancel();
          Timer(Duration(seconds: 3), () {
            setState(() {
              recommendedFood = foodList[random.nextInt(foodList.length)];
            });
          });
        }
      });
    });
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('음식 추천'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: recommendFood,
              child: Text('음식 랜덤으로 추천'),
            ),
            SizedBox(height: 20),
            Text(
              recommendedFood,
              style: TextStyle(fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Completer<GoogleMapController> _controller = Completer();
  static final CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 12.0,
  );
  LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();

    bool serviceEnabled;
    PermissionStatus permissionStatus;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionStatus = await location.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return;
      }
    }

    LocationData currentLocation = await location.getLocation();
    setState(() {
      _currentLocation = currentLocation;
    });
  }

  Future<void> _onMapTap(LatLng latLng) async {
    if (_currentLocation != null) {
      final apiKey = 'AIzaSyCdSsJlKMXXP-fcdAtCaKZDHgLvlFMYag4'; // Google Places API 키 입력
      final radius = 500;
      final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${latLng.latitude},${latLng.longitude}&radius=$radius&key=$apiKey';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
        final placeId = data['results'][0]['place_id'];
        final detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';

        final detailsResponse = await http.get(Uri.parse(detailsUrl));
        final detailsData = json.decode(detailsResponse.body);

        if (detailsData['status'] == 'OK' && detailsData['result'] != null) {
          final placeDetails = detailsData['result'];

          // Weekday text null 처리
          final weekdayText = placeDetails['opening_hours'] != null
              ? placeDetails['opening_hours']['weekday_text'] ?? []
              : [];

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(placeDetails['name'] ?? ''),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('평점: ${placeDetails['rating']?.toStringAsFixed(1) ?? ''}'),
                  Text('영업 시간: ${weekdayText.join('\n') ?? ''}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('닫기'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('지도'),
      ),
      body: _currentLocation != null
          ? GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        initialCameraPosition: CameraPosition(
          target: LatLng(
            _currentLocation!.latitude!,
            _currentLocation!.longitude!,
          ),
          zoom: 15.0,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onTap: _onMapTap,
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
}