import '../../auth/data/mock_users.dart';
import '../models/bus_route_model.dart';
import '../models/bus_stop_model.dart';
import '../models/route_student_model.dart';

/// Fake bus lines in Baghdad until the transport module has a backend.
class MockTransport {
  MockTransport._();

  static int _at(int hour, int minute) => hour * 60 + minute;

  /// Every line ends at the school (morning) and starts there (afternoon).
  static const school = BusStopModel(
    id: BusStopModel.schoolId,
    name: 'Al-Noor School',
    landmark: 'Main gate',
    latitude: 33.315,
    longitude: 44.365,
    morningMinute: 465, // 07:45
    afternoonMinute: 800, // 13:20
  );

  static const mansourLine = BusRouteModel(
    id: 'route-1',
    name: 'Al-Mansour line',
    busNumber: '12',
    plateNumber: 'Baghdad 41582',
    driverId: 'DRV-2024-0012',
    driverName: 'Kadhim Jawad',
    driverPhone: '+964 770 900 1212',
    supervisorName: 'Ms. Iman Fadhil',
    supervisorPhone: '+964 771 300 4545',
    capacity: 26,
    stops: [
      BusStopModel(
        id: 's1',
        name: 'Al-Ghazaliya',
        landmark: 'Al-Ghazaliya square',
        latitude: 33.338,
        longitude: 44.270,
        morningMinute: 410, // 06:50
        afternoonMinute: 854, // 14:14
      ),
      BusStopModel(
        id: 's2',
        name: 'Al-Adel',
        landmark: 'Al-Adel mosque',
        latitude: 33.330,
        longitude: 44.300,
        morningMinute: 422, // 07:02
        afternoonMinute: 842, // 14:02
      ),
      BusStopModel(
        id: 's3',
        name: 'Hay Al-Jamia',
        landmark: 'Al-Jamia street',
        latitude: 33.317,
        longitude: 44.318,
        morningMinute: 432, // 07:12
        afternoonMinute: 832, // 13:52
      ),
      BusStopModel(
        id: 's4',
        name: 'Al-Yarmouk',
        landmark: 'Al-Yarmouk hospital',
        latitude: 33.300,
        longitude: 44.335,
        morningMinute: 442, // 07:22
        afternoonMinute: 822, // 13:42
      ),
      BusStopModel(
        id: 's5',
        name: 'Al-Mansour',
        landmark: '14th of Ramadan street',
        latitude: 33.310,
        longitude: 44.350,
        morningMinute: 452, // 07:32
        afternoonMinute: 812, // 13:32
      ),
      school,
    ],
  );

  static final karradaLine = BusRouteModel(
    id: 'route-2',
    name: 'Al-Karrada line',
    busNumber: '7',
    plateNumber: 'Baghdad 30917',
    driverId: 'DRV-2024-0019',
    driverName: 'Salam Hameed',
    driverPhone: '+964 780 222 7070',
    supervisorName: 'Ms. Rasha Kamil',
    supervisorPhone: '+964 772 555 1919',
    capacity: 26,
    stops: [
      BusStopModel(
        id: 'k1',
        name: 'Al-Karrada',
        landmark: 'Kahramana square',
        latitude: 33.300,
        longitude: 44.420,
        morningMinute: _at(7, 0),
        afternoonMinute: _at(14, 0),
      ),
      BusStopModel(
        id: 'k2',
        name: 'Al-Jadriya',
        landmark: 'Al-Jadriya bridge',
        latitude: 33.280,
        longitude: 44.380,
        morningMinute: _at(7, 20),
        afternoonMinute: _at(13, 40),
      ),
      school,
    ],
  );

  static List<BusRouteModel> get routes => [mansourLine, karradaLine];

  /// (student ID, name, class, stop, parent). The IDs are the same as in
  /// the People directory; parents are often known as "Umm ..." / "Abu ...".
  static const _riders = {
    'route-1': [
      ('STU-2026-0150', 'Fatima Ali', '5th Scientific – A', 's1', 'Umm Fatima'),
      (
        'STU-2026-0151',
        'Maryam Hussein',
        '5th Scientific – A',
        's1',
        'Abu Maryam',
      ),
      ('STU-2026-0152', 'Noor Abbas', '5th Scientific – A', 's2', 'Umm Noor'),
      ('STU-2026-0159', 'Duaa Saad', '4th Scientific – A', 's2', 'Abu Duaa'),
      (
        'STU-2026-0157',
        'Sara Mahdi',
        '6th Scientific – C',
        's3',
        'Mahdi Saleh',
      ),
      (
        'STU-2026-0158',
        'Hawraa Kadhim',
        '6th Scientific – C',
        's3',
        'Abu Hawraa',
      ),
      (
        'STU-2026-0160',
        'Ruqaya Salman',
        '4th Scientific – A',
        's4',
        'Umm Ruqaya',
      ),
      (
        'STU-2026-0161',
        'Zahraa Jaafar',
        '5th Scientific – B',
        's5',
        'Abu Zahraa',
      ),
      ('STU-2026-0162', 'Aya Ahmed', '5th Scientific – B', 's5', 'Umm Aya'),
    ],
    'route-2': [
      (
        'STU-2026-0153',
        'Ali Hassan',
        '5th Scientific – B',
        'k1',
        'Ali Hassan Sr.',
      ),
      (
        'STU-2026-0154',
        'Mustafa Kareem',
        '5th Scientific – B',
        'k1',
        'Kareem Mahmoud',
      ),
      (
        'STU-2026-0155',
        'Hussein Adel',
        '4th Scientific – A',
        'k2',
        'Abu Hussein',
      ),
      (
        'STU-2026-0156',
        'Yousif Raad',
        '4th Scientific – A',
        'k2',
        'Umm Yousif',
      ),
    ],
  };

  /// Students registered on a route (Zainab rides the Al-Mansour line).
  static List<RouteStudentModel> rosterOf(String routeId) {
    final riders = _riders[routeId] ?? const [];

    return [
      if (routeId == mansourLine.id)
        RouteStudentModel(
          id: MockUsers.student.id,
          name: MockUsers.student.name,
          stopId: 's4',
          className: MockUsers.student.className!,
          parentId: MockUsers.parent.id,
          parentName: MockUsers.parent.name,
          parentPhone: MockUsers.parent.phone,
        ),
      for (final (id, name, className, stopId, parent) in riders)
        RouteStudentModel(
          id: id,
          name: name,
          stopId: stopId,
          className: className,
          parentId: id.replaceFirst('STU', 'PAR'),
          parentName: parent,
          parentPhone: '+964 770 ${id.substring(9)} ${id.substring(11)}0',
        ),
    ];
  }
}
