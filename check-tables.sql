-- Check if tables exist and their structure
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('devices', 'sessions', 'user_permissions');

-- Check sessions table columns if it exists
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'sessions'
ORDER BY ordinal_position;

-- Check if migration was recorded
SELECT * FROM schema_migrations;
