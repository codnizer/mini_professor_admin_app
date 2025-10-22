import 'dart:html';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

const String backendUrl = 'http://localhost:8080';

final FormElement profForm = querySelector('#prof-form') as FormElement;
final InputElement profName = querySelector('#prof-name') as InputElement;
final InputElement profDept = querySelector('#prof-dept') as InputElement;
final UListElement profList = querySelector('#prof-list') as UListElement;
final HeadingElement profFormHeader =
    querySelector('#prof-form-header') as HeadingElement;
final ButtonElement profFormSubmit =
    querySelector('#prof-form-submit') as ButtonElement;
final ButtonElement profFormCancel =
    querySelector('#prof-form-cancel') as ButtonElement;

final DivElement lectureSection =
    querySelector('#lecture-section') as DivElement;
final HeadingElement lectureHeader =
    querySelector('#lecture-header') as HeadingElement;
final FormElement lectureForm = querySelector('#lecture-form') as FormElement;
final InputElement lectureTitle =
    querySelector('#lecture-title') as InputElement;
final UListElement lectureList = querySelector('#lecture-list') as UListElement;
final ButtonElement lectureFormSubmit =
    querySelector('#lecture-form-submit') as ButtonElement;
final ButtonElement lectureFormCancel =
    querySelector('#lecture-form-cancel') as ButtonElement;

int? _selectedProfessorId;
String? _selectedProfessorName;
int? _editingProfessorId;
int? _editingLectureId;

StreamSubscription? _profFormSubscription;
StreamSubscription? _lectureFormSubscription;

const String _spinnerHtml = '''
<div class="spinner-container">
    <div class="spinner"></div>
</div>
''';

void main() {
  // 1. Load data when the page opens
  loadProfessors();

  // 2. Set forms to 'create' mode by default
  _switchToCreateProfessorMode();
  _switchToCreateLectureMode();

  // 3. Listen for cancel button clicks
  profFormCancel.onClick.listen((_) => _switchToCreateProfessorMode());
  lectureFormCancel.onClick.listen((_) => _switchToCreateLectureMode());
}

//
// PROFESSOR CRUD

void loadProfessors() async {
  profList.innerHtml = _spinnerHtml;

  try {
    final response = await http.get(Uri.parse('$backendUrl/professors'));

    if (response.statusCode == 200) {
      final List<dynamic> professors = jsonDecode(response.body);

      profList.innerHtml = '';
      if (professors.isEmpty) {
        profList.innerHtml =
            '<li class="empty-state">No professors found.</li>';
        return;
      }

      for (var prof in professors) {
        final profId = prof['id'] as int;
        final profName = prof['name'] as String;
        final profDept = prof['department'] as String;

        final li = LIElement()..id = 'prof-$profId';

        final nameSpan = SpanElement()
          ..text = '$profName ($profDept)'
          ..className = 'item-name';

        final viewButton = ButtonElement()
          ..text = 'Lectures'
          ..className = 'view-btn'
          ..onClick.listen((_) => selectProfessor(profId, profName));

        final editButton = ButtonElement()
          ..text = 'Edit'
          ..onClick.listen(
              (_) => _switchToEditProfessorMode(profId, profName, profDept));

        final deleteButton = ButtonElement()
          ..text = 'Delete'
          ..className = 'delete-btn' // Add class for styling
          ..onClick.listen((_) => deleteProfessor(profId));

        final actionsDiv = DivElement()
          ..className = 'actions'
          ..children.addAll([viewButton, editButton, deleteButton]);

        li.children.addAll([nameSpan, actionsDiv]);
        profList.append(li);
      }
    } else {
      profList.innerHtml =
          '<li class="empty-state error">❌ Error loading: ${response.statusCode}</li>';
    }
  } catch (e) {
    profList.innerHtml =
        '<li class="empty-state error">❌ Error loading professors: $e</li>';
  }
}

///  Sends new professor data to the backend
void _handleCreateProfessor(Event e) async {
  e.preventDefault();

  final data = {
    'name': profName.value,
    'department': profDept.value,
  };

  try {
    final response = await http.post(
      Uri.parse('$backendUrl/professors'),
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      _switchToCreateProfessorMode();
      loadProfessors();
    } else {
      window.alert(
          'Error saving professor: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    window.alert('Error saving professor: $e');
  }
}

///  Updates an existing professor
void _handleUpdateProfessor(Event e) async {
  e.preventDefault();
  if (_editingProfessorId == null) return;

  final data = {
    'name': profName.value,
    'department': profDept.value,
  };

  try {
    final response = await http.put(
      Uri.parse('$backendUrl/professors/$_editingProfessorId'),
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      _switchToCreateProfessorMode();
      loadProfessors();
    } else {
      window.alert(
          'Error updating professor: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    window.alert('Error updating professor: $e');
  }
}

///  Deletes a professor
void deleteProfessor(int id) async {
  if (!window.confirm(
      'Are you sure you want to delete this professor? This will also delete all their lectures.')) {
    return;
  }

  try {
    final response = await http.delete(
      Uri.parse('$backendUrl/professors/$id'),
    );

    if (response.statusCode == 200) {
      loadProfessors();

      if (_selectedProfessorId == id) {
        lectureSection.style.display = 'none';
        _selectedProfessorId = null;
        _selectedProfessorName = null;
      }

      if (_editingProfessorId == id) {
        _switchToCreateProfessorMode();
      }
    } else {
      window.alert(
          'Error deleting professor: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    window.alert('Error deleting professor: $e');
  }
}

// LECTURE CRUD

/// Selects a professor and shows their lectures
void selectProfessor(int id, String name) {
  _selectedProfessorId = id;
  _selectedProfessorName = name;

  final currentSelected = profList.querySelector('.selected');
  currentSelected?.classes.remove('selected');

  final newItem = profList.querySelector('#prof-$id');
  newItem?.classes.add('selected');

  lectureSection.style.display = 'block';
  lectureHeader.text = 'Lectures for $_selectedProfessorName';
  _switchToCreateLectureMode();
  loadLectures(id);
}

void loadLectures(int professorId) async {
  lectureList.innerHtml = _spinnerHtml;
  try {
    final response = await http
        .get(Uri.parse('$backendUrl/professors/$professorId/lectures'));

    if (response.statusCode == 200) {
      final List<dynamic> lectures = jsonDecode(response.body);

      lectureList.innerHtml = '';
      if (lectures.isEmpty) {
        lectureList.innerHtml =
            '<li class="empty-state">No lectures found for this professor.</li>';
        return;
      }

      for (var lecture in lectures) {
        final lectureId = lecture['id'] as int;
        final lectureTitle = lecture['title'] as String;

        final li = LIElement();
        final titleSpan = SpanElement()
          ..text = lectureTitle
          ..className = 'item-name';

        final editButton = ButtonElement()
          ..text = 'Edit'
          ..onClick
              .listen((_) => _switchToEditLectureMode(lectureId, lectureTitle));

        final deleteButton = ButtonElement()
          ..text = 'Delete'
          ..className = 'delete-btn'
          ..onClick.listen((_) => deleteLecture(lectureId));

        final actionsDiv = DivElement()
          ..className = 'actions'
          ..children.addAll([editButton, deleteButton]);

        li.children.addAll([titleSpan, actionsDiv]);
        lectureList.append(li);
      }
    } else {
      lectureList.innerHtml =
          '<li class="empty-state error">❌ Error loading lectures: ${response.statusCode}</li>';
    }
  } catch (e) {
    lectureList.innerHtml =
        '<li class="empty-state error">❌ Error loading lectures: $e</li>';
  }
}

void _handleCreateLecture(Event e) async {
  e.preventDefault();

  if (_selectedProfessorId == null) {
    window.alert('No professor selected!');
    return;
  }

  final data = {
    'title': lectureTitle.value,
    'professor_id': _selectedProfessorId,
  };

  try {
    final response = await http.post(
      Uri.parse('$backendUrl/lectures'),
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      _switchToCreateLectureMode();
      loadLectures(_selectedProfessorId!);
    } else {
      window.alert(
          'Error saving lecture: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    window.alert('Error saving lecture: $e');
  }
}

void _handleUpdateLecture(Event e) async {
  e.preventDefault();
  if (_editingLectureId == null) return;

  final data = {'title': lectureTitle.value};

  try {
    final response = await http.put(
      Uri.parse('$backendUrl/lectures/$_editingLectureId'),
      body: jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      _switchToCreateLectureMode();
      loadLectures(_selectedProfessorId!);
    } else {
      window.alert(
          'Error updating lecture: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    window.alert('Error updating lecture: $e');
  }
}

/// DELETE: Deletes a lecture
void deleteLecture(int id) async {
  if (!window.confirm('Are you sure you want to delete this lecture?')) {
    return;
  }

  try {
    final response = await http.delete(
      Uri.parse('$backendUrl/lectures/$id'),
    );

    if (response.statusCode == 200) {
      loadLectures(_selectedProfessorId!);

      if (_editingLectureId == id) {
        _switchToCreateLectureMode();
      }
    } else {
      window.alert(
          'Error deleting lecture: ${response.statusCode} ${response.body}');
    }
  } catch (e) {
    window.alert('Error deleting lecture: $e');
  }
}

void _switchToCreateProfessorMode() {
  _editingProfessorId = null;
  profName.value = '';
  profDept.value = '';

  profFormHeader.text = 'Create Professor';
  profFormSubmit.text = 'Add Professor';
  profFormCancel.style.display = 'none';

  _profFormSubscription?.cancel();
  _profFormSubscription = profForm.onSubmit.listen(_handleCreateProfessor);
}

void _switchToEditProfessorMode(int id, String name, String dept) {
  _editingProfessorId = id;
  profName.value = name;
  profDept.value = dept;

  profFormHeader.text = 'Edit $name';
  profFormSubmit.text = 'Update Professor';
  profFormCancel.style.display = 'inline-block';

  profForm.scrollIntoView(ScrollAlignment.TOP);

  _profFormSubscription?.cancel();
  _profFormSubscription = profForm.onSubmit.listen(_handleUpdateProfessor);
}

void _switchToCreateLectureMode() {
  _editingLectureId = null;
  lectureTitle.value = '';

  lectureFormSubmit.text = 'Add Lecture';
  lectureFormCancel.style.display = 'none';

  _lectureFormSubscription?.cancel();
  _lectureFormSubscription = lectureForm.onSubmit.listen(_handleCreateLecture);
}

void _switchToEditLectureMode(int id, String title) {
  _editingLectureId = id;
  lectureTitle.value = title;

  lectureFormSubmit.text = 'Update Lecture';
  lectureFormCancel.style.display = 'inline-block';

  lectureForm.scrollIntoView(ScrollAlignment.TOP);

  _lectureFormSubscription?.cancel();
  _lectureFormSubscription = lectureForm.onSubmit.listen(_handleUpdateLecture);
}
