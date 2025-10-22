import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';

final dbEndpoint = Endpoint(
    host: 'localhost',
    port: 5434,
    database: 'postgres',
    username: 'postgres',
    password: '1234');

Future<Connection> _getDbConnection() async {
  final connection = await Connection.open(dbEndpoint,
      settings: ConnectionSettings(
        sslMode: SslMode.disable,
      ));
  return connection;
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Allows all origins
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type',
};

Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(null, headers: _corsHeaders);
      }

      final response = await innerHandler(request);

      return response.change(headers: _corsHeaders);
    };
  };
}

void main() async {
  final app = Router();

  app.get('/professors', (Request request) async {
    Connection? db;
    try {
      db = await _getDbConnection();
      final result = await db.execute('SELECT * FROM professors ORDER BY name');
      final professors = result.map((row) => row.toColumnMap()).toList();
      return Response.ok(jsonEncode(professors),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error fetching: $e');
    } finally {
      await db?.close();
    }
  });

  app.post('/professors', (Request request) async {
    Connection? db;
    try {
      db = await _getDbConnection();
      final body = await request.readAsString();
      final params = jsonDecode(body) as Map<String, dynamic>;

      await db.execute(
        Sql.named(
            'INSERT INTO professors (name, department) VALUES (@name, @department)'),
        parameters: {
          'name': params['name'],
          'department': params['department'],
        },
      );
      return Response(201,
          body: '{"status": "Professor created"}',
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error creating: $e');
    } finally {
      await db?.close();
    }
  });

  // PUT
  app.put('/professors/<id>', (Request request, String id) async {
    Connection? db;
    try {
      db = await _getDbConnection();
      final body = await request.readAsString();
      final params = jsonDecode(body) as Map<String, dynamic>;
      final profId = int.parse(id);

      await db.execute(
        Sql.named(
            'UPDATE professors SET name = @name, department = @department WHERE id = @id'),
        parameters: {
          'name': params['name'],
          'department': params['department'],
          'id': profId,
        },
      );
      return Response.ok('{"status": "Professor updated"}',
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error updating: $e');
    } finally {
      await db?.close();
    }
  });

  // DELETE
  app.delete('/professors/<id>', (Request request, String id) async {
    Connection? db;
    try {
      db = await _getDbConnection();
      final profId = int.parse(id);

      await db.execute(
        Sql.named('DELETE FROM professors WHERE id = @id'),
        parameters: {'id': profId},
      );
      return Response.ok('{"status": "Professor deleted"}',
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error deleting: $e');
    } finally {
      await db?.close();
    }
  });

  //  LECTURE

  // GET
  app.get('/professors/<profId>/lectures',
      (Request request, String profId) async {
    Connection? db;
    try {
      db = await _getDbConnection();
      final result = await db.execute(
        Sql.named(
            'SELECT * FROM lectures WHERE professor_id = @profId ORDER BY title'),
        parameters: {'profId': int.parse(profId)},
      );
      final lectures = result.map((row) => row.toColumnMap()).toList();
      return Response.ok(jsonEncode(lectures),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error fetching lectures: $e');
    } finally {
      await db?.close();
    }
  });

  // POST
  app.post('/lectures', (Request request) async {
    Connection? db;
    try {
      db = await _getDbConnection();
      final body = await request.readAsString();
      final params = jsonDecode(body) as Map<String, dynamic>;

      await db.execute(
        Sql.named(
            'INSERT INTO lectures (title, professor_id) VALUES (@title, @profId)'),
        parameters: {
          'title': params['title'],
          'profId': params['professor_id'],
        },
      );
      return Response(201,
          body: '{"status": "Lecture created"}',
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error creating lecture: $e');
    } finally {
      await db?.close();
    }
  });

  // PUT
  app.put('/lectures/<id>', (Request request, String id) async {
    Connection? db;
    try {
      db = await _getDbConnection();
      final body = await request.readAsString();
      final params = jsonDecode(body) as Map<String, dynamic>;
      final lectureId = int.parse(id);

      await db.execute(
        Sql.named('UPDATE lectures SET title = @title WHERE id = @id'),
        parameters: {
          'title': params['title'],
          'id': lectureId,
        },
      );
      return Response.ok('{"status": "Lecture updated"}',
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error updating lecture: $e');
    } finally {
      await db?.close();
    }
  });

  // DELETE
  app.delete('/lectures/<id>', (Request request, String id) async {
    Connection? db;
    try {
      db = await _getDbConnection();
      final lectureId = int.parse(id);

      await db.execute(
        Sql.named('DELETE FROM lectures WHERE id = @id'),
        parameters: {'id': lectureId},
      );
      return Response.ok('{"status": "Lecture deleted"}',
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'Error deleting lecture: $e');
    } finally {
      await db?.close();
    }
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(app);

  final server = await shelf_io.serve(handler, 'localhost', 8080);

  print('Server listening on http://localhost:8080');
}
