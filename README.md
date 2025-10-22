# Professor Admin Mini App

A simple full-stack Dart application for managing professors and their associated lectures. The application features a Dart web frontend (`dart:html`) and a Dart backend server (`shelf`, `postgres`).

![Application Demo](prof_admin_mini_app/DEMO.png)

## Description

This project is a mini web app that demonstrates full-stack development using Dart. It provides a simple admin interface to perform CRUD (Create, Read, Update, Delete) operations on two main entities: Professors and Lectures.

A user can:
* Create, view, edit, and delete professors.
* Select a professor to view their associated lectures.
* Create, edit, and delete lectures for a selected professor.

## Features

### Professor Management

Users can manage the list of all professors. This includes adding a new professor with a name and department, editing their details, or deleting them (which also deletes their associated lectures).

![CRUD Professors](prof_admin_mini_app/CRUD%20professor.png)

### Lecture Management

After selecting a professor, users can manage that professor's lectures. This includes adding new lectures, editing their titles, or deleting them.

![CRUD Lectures](prof_admin_mini_app/CRUD%20LECTURES.png)

## Project Structure

The project is organized into two main parts:

* `/backend`: A Dart server built with `shelf` and `shelf_router` that connects to a PostgreSQL database.
* `/frontend`: A Dart web application using `dart:html` and the `http` package to communicate with the backend API.

## Tech Stack

* **Frontend**: Dart (`dart:html`), `http` package
* **Backend**: Dart, `shelf`, `shelf_router`, `postgres` package
* **Database**: PostgreSQL
* **Dev Tools**: `build_runner`, `build_web_compilers`

## Setup and Running

### 1. Database

You must have a running PostgreSQL server.

1.  Create a database (e.g., `postgres`).
2.  Run the `tables.sql` script to create the necessary `professors` and `lectures` tables.

```sql
-- Table for professors
CREATE TABLE professors (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  department VARCHAR(100)
);

-- Table for lectures
CREATE TABLE lectures (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  professor_id INTEGER NOT NULL REFERENCES professors(id) ON DELETE CASCADE
);
```

### 2. Backend

1.  Navigate to the `backend/` directory.
2.  Update the database connection details in `backend/bin/server.dart` if they differ from the defaults:
    ```dart
    final dbEndpoint = Endpoint(
        host: 'localhost',
        port: 5434,
        database: 'postgres',
        username: 'postgres',
        password: '1234');
    ```
3.  Install dependencies: `dart pub get`
4.  Run the server: `dart run bin/server.dart`
5.  The server will be listening on `http://localhost:8080`.

### 3. Frontend

1.  Navigate to the `frontend/` directory.
2.  Install dependencies: `dart pub get`
3.  Compile the application using `build_runner`:
    ```bash
    dart run build_runner build -o build
    ```
    Or, for development with hot reload:
    ```bash
    dart run build_runner serve
    ```
4.  Serve the `frontend/` directory (or the `build/` directory if you compiled) using a simple web server (like `python -m http.server` or `live-server`).
5.  Open `http://localhost:<port>` (e.g., `http://localhost:8000`) in your browser to use the app.

## API Endpoints

The backend server exposes the following REST API endpoints:

### Professors

* `GET /professors`: Fetches all professors.
* `POST /professors`: Creates a new professor.
    * Body: `{"name": "...", "department": "..."}`
* `PUT /professors/<id>`: Updates an existing professor.
    * Body: `{"name": "...", "department": "..."}`
* `DELETE /professors/<id>`: Deletes a professor and their lectures.

### Lectures

* `GET /professors/<profId>/lectures`: Fetches all lectures for a specific professor.
* `POST /lectures`: Creates a new lecture.
    * Body: `{"title": "...", "professor_id": ...}`
* `PUT /lectures/<id>`: Updates an existing lecture.
    * Body: `{"title": "..."}`
* `DELETE /lectures/<id>`: Deletes a lecture.