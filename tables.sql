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