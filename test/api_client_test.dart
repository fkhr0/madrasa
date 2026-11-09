import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school/core/config/server_address.dart';
import 'package:school/core/l10n/language.dart';
import 'package:school/core/network/api_client.dart';
import 'package:school/core/network/api_exception.dart';
import 'package:school/core/network/response_cache.dart';
import 'package:school/features/auth/models/user_model.dart';
import 'package:school/features/calendar/models/calendar_event_model.dart';
import 'package:school/features/calendar/models/school_event_model.dart';
import 'package:school/features/institution/models/academic_year_model.dart';
import 'package:school/features/institution/models/holiday_model.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  group('ApiClient', () {
    test('an expired access token is refreshed once, silently', () async {
      final calls = <String>[];
      final api = ApiClient(
        baseUrl: 'http://api',
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.url.path == '/auth/refresh') {
            return json({'accessToken': 'new', 'refreshToken': 'r2'});
          }
          final auth = request.headers['Authorization'];
          return auth == 'Bearer new'
              ? json({'name': 'Zainab'})
              : json({'error': 'Your session has expired.'}, 401);
        }),
      )..setTokens(accessToken: 'old', refreshToken: 'r1');

      final me = await api.get('/me');

      expect(me['name'], 'Zainab');
      expect(calls, ['GET /me', 'POST /auth/refresh', 'GET /me']);
      expect(api.refreshToken, 'r2');
    });

    test('a refused refresh signs the user out', () async {
      var expired = false;
      final api =
          ApiClient(
              baseUrl: 'http://api',
              client: MockClient(
                (_) async => json({'error': 'Please sign in again.'}, 401),
              ),
            )
            ..setTokens(accessToken: 'old', refreshToken: 'r1')
            ..onSessionExpired = () => expired = true;

      await expectLater(api.get('/me'), throwsA(isA<ApiException>()));
      expect(expired, isTrue);
      expect(api.refreshToken, isNull);
    });

    test('the server\'s message reaches the user', () async {
      final api = ApiClient(
        baseUrl: 'http://api',
        client: MockClient(
          (_) async =>
              json({'error': 'The ID or password is not correct.'}, 401),
        ),
      );

      await expectLater(
        api.post('/auth/login', {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'The ID or password is not correct.',
          ),
        ),
      );
    });

    test('no connection gives a friendly message', () async {
      final api = ApiClient(
        baseUrl: 'http://api',
        client: MockClient((_) async => throw http.ClientException('down')),
      );

      await expectLater(
        api.get('/health'),
        throwsA(
          isA<ApiException>().having((e) => e.isOffline, 'offline', true),
        ),
      );
    });
  });

  group('JSON from the server', () {
    test('a parent with children', () {
      final user = UserModel.fromJson({
        'id': 'PAR-2026-0142',
        'name': 'Haider Jasim',
        'role': 'parent',
        'email': '',
        'phone': '+964 770 123 4567',
        'schoolName': 'Al-Noor Preparatory School',
        'className': null,
        'subjectName': null,
        'isActive': true,
        'children': [
          {
            'id': 'STU-2026-0142',
            'name': 'Zainab Haider',
            'role': 'student',
            'schoolName': 'Al-Noor Preparatory School',
            'className': '5th Scientific – A',
          },
        ],
      });

      expect(user.role, UserRole.parent);
      expect(user.children.single.className, '5th Scientific – A');
    });

    test('the study year keeps plain days (no time zone shift)', () {
      final year = AcademicYearModel.fromJson({
        'name': '2026–2027',
        'start': '2026-09-20',
        'end': '2027-06-10',
        'workingDays': [7, 1, 2, 3, 4],
        'terms': [
          {
            'name': 'First semester',
            'start': '2026-09-20',
            'end': '2027-01-21',
          },
        ],
        'holidays': [
          {
            'id': 'h1',
            'name': 'Iraqi National Day',
            'type': 'national',
            'start': '2026-10-03',
            'end': null,
          },
        ],
      });

      expect(year.holidayOn(DateTime(2026, 10, 3))?.name, 'Iraqi National Day');
      expect(year.isWorkingDay(DateTime(2026, 11, 8)), isTrue); // Sunday
      expect(year.isWorkingDay(DateTime(2026, 11, 6)), isFalse); // Friday
    });

    test('a new holiday is sent as plain days', () {
      final holiday = HolidayModel(
        name: 'Exam preparation',
        type: HolidayType.schoolBreak,
        start: DateTime(2026, 12, 20),
        end: DateTime(2026, 12, 21),
      );

      expect(holiday.toJson(), {
        'name': 'Exam preparation',
        'type': 'schoolBreak',
        'start': '2026-12-20',
        'end': '2026-12-21',
      });
    });
  });

  test('a school event goes to the server and back unchanged', () {
    final event = SchoolEventModel(
      id: 'e1',
      title: 'Parent–teacher meeting',
      type: CalendarEventType.meeting,
      audience: EventAudience.families,
      date: DateTime(2026, 11, 12),
      startMinute: 14 * 60 + 30,
      place: 'Main hall',
    );
    final json = event.toJson();
    expect(json['time'], '14:30');
    expect(json['date'], '2026-11-12');

    final back = SchoolEventModel.fromJson({...json, 'id': 'e1'});
    expect(back.start, DateTime(2026, 11, 12, 14, 30));
    expect(back.audience, EventAudience.families);
    expect(back.toCalendarEvent().schoolEvent, isNotNull);
  });

  test('every request tells the server the app language', () async {
    final seen = <String?>[];
    final api = ApiClient(
      baseUrl: 'http://server',
      client: MockClient((request) async {
        seen.add(request.headers['X-Language']);
        return http.Response('{}', 200);
      }),
    );

    await api.get('/me');
    AppLanguage.current = AppLanguage.ar;
    addTearDown(() => AppLanguage.current = AppLanguage.en);
    await api.get('/me');

    expect(seen, ['en', 'ar']);
  });

  test('a test build cleans and checks the server address', () {
    expect(
      ServerAddress.clean('  https://a-b.trycloudflare.com/ '),
      'https://a-b.trycloudflare.com',
    );
    expect(ServerAddress.clean('a-b.trycloudflare.com'), isNull);
    expect(ServerAddress.clean('https://'), isNull);
  });

  group('answers saved on the device', () {
    test('an unchanged answer costs a 304 and comes from the device', () async {
      final sent = <String?>[];
      final api = ApiClient(
        baseUrl: 'http://api',
        cache: MemoryResponseCache(),
        client: MockClient((request) async {
          sent.add(request.headers['If-None-Match']);
          return request.headers['If-None-Match'] == 'v1'
              ? http.Response('', 304)
              : http.Response(
                  jsonEncode({'name': 'Zainab'}),
                  200,
                  headers: {'etag': 'v1'},
                );
        }),
      )..cacheOwner = 'STU-1';

      expect((await api.get('/me'))['name'], 'Zainab');
      // Shown from the device at once; the server is asked in the background.
      expect((await api.get('/me'))['name'], 'Zainab');
      await pumpEventQueue();
      expect(sent, [null, 'v1']);
      // Later asks go to the server, and an unchanged answer is a 304.
      expect((await api.get('/me'))['name'], 'Zainab');
      expect(sent, [null, 'v1', 'v1']);
    });

    test(
      'saved answers shown at start that turn out old refresh the screens',
      () async {
        var version = 'v1';
        final cache = MemoryResponseCache();
        ApiClient open() => ApiClient(
          baseUrl: 'http://api',
          cache: cache,
          client: MockClient(
            (request) async => request.headers['If-None-Match'] == version
                ? http.Response('', 304)
                : http.Response(
                    jsonEncode({'room': version}),
                    200,
                    headers: {'etag': version},
                  ),
          ),
        )..cacheOwner = 'STU-1';
        await open().get('/timetable'); // saved on the device

        // The app opens again; meanwhile the timetable changed.
        version = 'v2';
        var outdated = 0;
        final api = open()..onSavedAnswersOutdated = () => outdated++;
        expect(await api.get('/timetable'), {'room': 'v1'}); // at once
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(outdated, 1);
        expect(await api.get('/timetable'), {'room': 'v2'});
      },
    );

    test('offline: the saved answer is shown and the app knows', () async {
      var online = true;
      final api = ApiClient(
        baseUrl: 'http://api',
        cache: MemoryResponseCache(),
        client: MockClient((_) async {
          if (!online) throw http.ClientException('no signal');
          return http.Response(
            jsonEncode(['Maths']),
            200,
            headers: {'etag': 'v1'},
          );
        }),
      )..cacheOwner = 'STU-1';

      await api.get('/timetable');
      online = false;
      expect(await api.get('/timetable'), ['Maths']); // the saved one at once
      expect(await api.get('/timetable'), ['Maths']); // the server: no signal
      expect(api.offline.value, isTrue);

      // Never seen before: nothing to show.
      await expectLater(api.get('/grades'), throwsA(isA<ApiException>()));

      online = true;
      await api.get('/timetable');
      expect(api.offline.value, isFalse);
    });

    test('one person never sees another\'s saved answers', () async {
      final cache = MemoryResponseCache();
      var online = true;
      final api = ApiClient(
        baseUrl: 'http://api',
        cache: cache,
        client: MockClient((_) async {
          if (!online) throw http.ClientException('no signal');
          return http.Response('{"marks":[95]}', 200, headers: {'etag': 'v1'});
        }),
      )..cacheOwner = 'STU-1';
      await api.get('/grades');

      online = false;
      api.cacheOwner = 'STU-2';
      await expectLater(api.get('/grades'), throwsA(isA<ApiException>()));

      await api.forgetSavedAnswers();
      expect(cache.saved, isEmpty);
    });
  });
}

/// Saved answers in memory, for tests.
class MemoryResponseCache implements ResponseCache {
  final saved = <String, CachedResponse>{};

  @override
  Future<CachedResponse?> read(String owner, String key) async =>
      saved['$owner $key'];

  @override
  Future<void> write(String owner, String key, CachedResponse r) async =>
      saved['$owner $key'] = r;

  @override
  Future<void> clear() async => saved.clear();
}
