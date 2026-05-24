-- =============================================================
-- Numera+ Classroom Sessions — Supabase Migration
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- =============================================================

-- 1. Sesiones de clase
CREATE TABLE classroom_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(10) UNIQUE NOT NULL,
  teacher_name VARCHAR(100) NOT NULL,
  monitor_token UUID DEFAULT gen_random_uuid(),
  operation_type VARCHAR(20),
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ DEFAULT now() + INTERVAL '8 hours'
);

CREATE INDEX idx_sessions_code ON classroom_sessions (code);
CREATE INDEX idx_sessions_monitor_token ON classroom_sessions (monitor_token);
CREATE INDEX idx_sessions_active ON classroom_sessions (active);

-- 2. Estudiantes en una sesión
CREATE TABLE session_students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES classroom_sessions(id) ON DELETE CASCADE NOT NULL,
  student_name VARCHAR(100) NOT NULL,
  completed INT DEFAULT 0,
  errors INT DEFAULT 0,
  max_streak INT DEFAULT 0,
  coins INT DEFAULT 0,
  joined_at TIMESTAMPTZ DEFAULT now(),
  last_active_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_students_session ON session_students (session_id);

-- 3. Eventos de progreso (cada ejercicio resuelto)
CREATE TABLE progress_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES session_students(id) ON DELETE CASCADE NOT NULL,
  event_type VARCHAR(20) NOT NULL,
  operation_type VARCHAR(20) NOT NULL,
  problem_text VARCHAR(100),
  student_answer VARCHAR(50),
  correct_answer VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_events_student ON progress_events (student_id);

-- 4. RLS: Deny all direct access (only service_role key from API routes)
ALTER TABLE classroom_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress_events ENABLE ROW LEVEL SECURITY;
