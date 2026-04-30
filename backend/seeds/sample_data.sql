-- ============================================================
-- Clubhouse Stakes — Sample Data
-- Passwords are all "Password123!" (bcrypt hashed)
-- ============================================================

INSERT INTO users (id, name, email, password_hash, handicap, city, is_admin) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Admin User',    'admin@clubhousestakes.com',  '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHHy', 0,   'Austin',      TRUE),
  ('a0000000-0000-0000-0000-000000000002', 'Jordan Pierce', 'jordan@example.com',         '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHHy', 8.2, 'Austin',      FALSE),
  ('a0000000-0000-0000-0000-000000000003', 'Taylor Brooks', 'taylor@example.com',         '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHHy', 12.0,'Austin',      FALSE),
  ('a0000000-0000-0000-0000-000000000004', 'Morgan Ellis',  'morgan@example.com',         '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHHy', 5.4, 'Austin',      FALSE),
  ('a0000000-0000-0000-0000-000000000005', 'Casey Rivera',  'casey@example.com',          '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHHy', 18.0,'Dallas',      FALSE),
  ('a0000000-0000-0000-0000-000000000006', 'Riley Sanders', 'riley@example.com',          '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHHy', 3.1, 'Dallas',      FALSE);

INSERT INTO tournaments (id, name, city, date, format, sign_up_fee, max_players, fee_per, status, course_name, description, created_by) VALUES
  ('b0000000-0000-0000-0000-000000000001',
   'Austin Spring Classic', 'Austin',
   NOW() + INTERVAL '14 days',
   'individual', 50.00, 40, 'player', 'upcoming',
   'Barton Creek Meadows',
   'Annual spring individual stroke-play tournament. Net scoring with handicaps applied.',
   'a0000000-0000-0000-0000-000000000001'),

  ('b0000000-0000-0000-0000-000000000002',
   'Texas Four-Ball Invitational', 'Austin',
   NOW() + INTERVAL '30 days',
   'fourball', 75.00, 32, 'team', 'upcoming',
   'Avery Ranch Golf Club',
   'Best-ball format. Teams of 2 compete for the biggest purse in Austin.',
   'a0000000-0000-0000-0000-000000000001'),

  ('b0000000-0000-0000-0000-000000000003',
   'Dallas Open Championship', 'Dallas',
   NOW() + INTERVAL '21 days',
   'individual', 60.00, 50, 'player', 'upcoming',
   'Bear Creek Golf Complex',
   'Open to all handicaps. Top 3 finishers take home the purse.',
   'a0000000-0000-0000-0000-000000000001');

-- Sample entries for Austin Spring Classic
INSERT INTO entries (user_id, tournament_id, payment_status) VALUES
  ('a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'paid'),
  ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'paid'),
  ('a0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'paid');

-- Sample team for Four-Ball
INSERT INTO teams (id, tournament_id, name, created_by) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'Eagle Squad', 'a0000000-0000-0000-0000-000000000002');

INSERT INTO team_members (team_id, user_id) VALUES
  ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002'),
  ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003');

INSERT INTO entries (user_id, tournament_id, team_id, payment_status) VALUES
  ('a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'paid'),
  ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'paid');
