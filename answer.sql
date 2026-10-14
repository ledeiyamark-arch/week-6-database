-- ============================================================
-- POSTGRESQL BACKUP, RECOVERY AND REPLICATION LAB
-- File: answer.sql
-- ============================================================

-- ============================================================
-- STEP 1: VERIFY THE BOOTCAMP DATABASE
-- ============================================================

-- Connect to the bootcamp database before running this:
-- \c bootcamp

-- Check available tables
\dt

-- Check the students table
SELECT * FROM students;


-- ============================================================
-- STEP 2: RECORD TIME BEFORE THE DISASTER
-- ============================================================

-- IMPORTANT:
-- Run this command BEFORE deleting any data.
-- Record the exact timestamp returned.

SELECT now();


-- ============================================================
-- STEP 3: SIMULATE A DISASTER
-- ============================================================

-- WARNING:
-- This intentionally deletes all records from students.
-- Only run this in the practice/lab database.

DELETE FROM students;

-- Verify that the records were deleted
SELECT count(*) AS remaining_students
FROM students;


-- ============================================================
-- STEP 4: CREATE REPLICATION USER
-- ============================================================

-- Run this on the PRIMARY PostgreSQL server.

CREATE ROLE replicator
WITH REPLICATION LOGIN PASSWORD 'reppass';


-- Verify the replication role
\du


-- ============================================================
-- STEP 5: CHECK REPLICATION HEALTH
-- ============================================================

-- Run this on the PRIMARY server after configuring
-- the standby server.

SELECT application_name,
       state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;


-- ============================================================
-- END OF SQL ANSWERS
-- ============================================================

-- NOTE:
-- Commands such as pg_dump, pg_restore, createdb and
-- pg_basebackup are Linux/terminal commands, NOT SQL.
--
-- PostgreSQL configuration settings such as:
--
-- wal_level = replica
-- archive_mode = on
-- archive_command = 'cp %p /home/YOUR_USERNAME/backups/wal/%f'
--
-- belong in postgresql.conf.
--
-- The replication access rule:
--
-- host replication replicator 127.0.0.1/32 md5
--
-- belongs in pg_hba.conf.
