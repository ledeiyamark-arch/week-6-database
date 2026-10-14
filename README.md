# PostgreSQL Backup, Recovery and Replication Lab

## Overview

This project demonstrates basic PostgreSQL database administration techniques, including:

- Logical database backups
- Backup verification
- WAL archiving
- Base backups
- Disaster simulation
- Point-in-time recovery
- Streaming replication
- Replication health monitoring

The practical database used in this lab is called `bootcamp`.

---

## Repository Structure

```text
postgresql-backup-recovery-lab/
│
├── answer.sql
└── README.md
```

### Files

**answer.sql**

Contains the SQL commands used for the database exercises, including checking the database, recording the recovery time, simulating data loss, creating a replication user, and checking replication status.

**README.md**

Contains the explanation and instructions for completing the PostgreSQL backup and recovery lab.

---

# Step 1: Take and Verify a Logical Backup

First, create a directory for PostgreSQL backups.

Run this command in the Linux/WSL terminal:

```bash
mkdir -p ~/backups
```

Create a custom-format backup of the `bootcamp` database:

```bash
pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp
```

Check the backup:

```bash
ls -lh ~/backups/
```

The backup file should be:

```text
bootcamp.dump
```

Verify the contents of the backup:

```bash
pg_restore --list ~/backups/bootcamp.dump | head
```

Create a test database:

```bash
createdb bootcamp_check
```

Restore the backup into the test database:

```bash
pg_restore -d bootcamp_check ~/backups/bootcamp.dump
```

Connect to the restored database:

```bash
psql -d bootcamp_check
```

Check the tables:

```sql
\dt
```

Check the students:

```sql
SELECT * FROM students;
```

If the student records are present, the backup has been successfully restored.

---

# Step 2: Enable WAL Archiving

WAL means **Write-Ahead Logging**.

PostgreSQL uses WAL to record changes made to the database. WAL archiving is important for point-in-time recovery because archived WAL files can be replayed after restoring a base backup.

First create the WAL backup directory:

```bash
mkdir -p ~/backups/wal
```

Find the PostgreSQL configuration file:

```bash
psql -U postgres -c "SHOW config_file;"
```

Open the configuration file returned by PostgreSQL.

For example:

```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
```

Add or modify:

```text
wal_level = replica
archive_mode = on
archive_command = 'cp %p /home/YOUR_USERNAME/backups/wal/%f'
```

Replace `YOUR_USERNAME` with the actual Linux username.

Restart PostgreSQL:

```bash
sudo systemctl restart postgresql
```

Verify the settings:

```bash
psql -U postgres -c "SHOW wal_level;"
```

```bash
psql -U postgres -c "SHOW archive_mode;"
```

The expected values are:

```text
wal_level
---------
replica
```

and:

```text
archive_mode
------------
on
```

---

# Step 3: Take a Base Backup

Create a base backup using `pg_basebackup`:

```bash
pg_basebackup -D ~/backups/base -Ft -z -Xs -P
```

Explanation:

- `-D` specifies the destination directory.
- `-Ft` creates the backup in tar format.
- `-z` compresses the backup.
- `-Xs` includes required WAL data.
- `-P` displays progress.

Check the backup:

```bash
ls -lh ~/backups/base
```

---

# Step 4: Simulate a Disaster

Connect to the `bootcamp` database:

```bash
psql -d bootcamp
```

Before making the simulated mistake, record the current database time:

```sql
SELECT now();
```

Example:

```text
2026-10-14 09:40:00
```

Record the exact timestamp returned by your own PostgreSQL server.

Check the students:

```sql
SELECT * FROM students;
```

Simulate accidental deletion:

```sql
DELETE FROM students;
```

Check the number of remaining students:

```sql
SELECT count(*) FROM students;
```

The result should be zero if the table contained records before the deletion.

---

# Step 5: Point-in-Time Recovery

Point-in-time recovery, commonly called PITR, allows PostgreSQL to restore a database to a particular point in time.

The general recovery process is:

```text
Base Backup
     |
     v
Restore Base Backup
     |
     v
Replay Archived WAL
     |
     v
Recovery Target Time
     |
     v
Recovered Database
```

First stop PostgreSQL:

```bash
sudo systemctl stop postgresql
```

The PostgreSQL data directory can be found using:

```bash
psql -U postgres -c "SHOW data_directory;"
```

The base backup should be restored into an appropriate PostgreSQL data directory before starting the server.

Configure the recovery settings appropriate to your PostgreSQL version.

For older PostgreSQL recovery configurations, settings may be represented as:

```text
restore_command = 'cp /home/YOUR_USERNAME/backups/wal/%f %p'
recovery_target_time = '2026-10-14 09:40:00'
```

Use the actual timestamp that you recorded before the simulated deletion.

After recovery, start PostgreSQL:

```bash
sudo systemctl start postgresql
```

Connect to the database:

```bash
psql -d bootcamp
```

Check the students:

```sql
SELECT count(*) FROM students;
```

The goal is to verify that the database was recovered to a point before the accidental deletion.

> **Important:** PostgreSQL recovery configuration differs between major PostgreSQL versions. Do not overwrite the live PostgreSQL data directory until the base backup and recovery procedure has been verified.

---

# Step 6: Set Up a Streaming Standby

Create a replication user on the primary server:

```sql
CREATE ROLE replicator
WITH REPLICATION LOGIN PASSWORD 'reppass';
```

Verify the role:

```sql
\du
```

Find the `pg_hba.conf` file:

```bash
psql -U postgres -c "SHOW hba_file;"
```

Open the file:

```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
```

Add:

```text
host replication replicator 127.0.0.1/32 md5
```

Reload PostgreSQL:

```bash
sudo systemctl reload postgresql
```

Create a directory for the standby:

```bash
mkdir -p ~/standby
```

Build the standby using:

```bash
pg_basebackup -h 127.0.0.1 -U replicator -D ~/standby -R -P
```

When PostgreSQL asks for the password, enter:

```text
reppass
```

The `-R` option creates the standby connection configuration.

---

# Step 7: Monitor Replication

On the primary PostgreSQL server, run:

```sql
SELECT application_name,
       state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
```

The `state` column should normally show:

```text
streaming
```

when the standby is successfully receiving WAL from the primary.

The `lag_bytes` value indicates the difference between WAL sent by the primary and WAL replayed by the standby.

---

# Important Command Locations

## PostgreSQL / psql

Run SQL commands in PostgreSQL:

```sql
SELECT now();

SELECT * FROM students;

DELETE FROM students;

CREATE ROLE replicator
WITH REPLICATION LOGIN PASSWORD 'reppass';

SELECT application_name,
       state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
```

## Linux / WSL Terminal

Run PostgreSQL utility commands in the terminal:

```bash
mkdir -p ~/backups

pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp

pg_restore --list ~/backups/bootcamp.dump | head

createdb bootcamp_check

pg_restore -d bootcamp_check ~/backups/bootcamp.dump

pg_basebackup -D ~/backups/base -Ft -z -Xs -P

sudo systemctl restart postgresql

sudo systemctl stop postgresql

sudo systemctl start postgresql
```

## PostgreSQL Configuration

The following belong in `postgresql.conf`:

```text
wal_level = replica
archive_mode = on
archive_command = 'cp %p /home/YOUR_USERNAME/backups/wal/%f'
```

The following belongs in `pg_hba.conf`:

```text
host replication replicator 127.0.0.1/32 md5
```

---

# Learning Outcomes

After completing this lab, I should be able to:

1. Create a PostgreSQL logical backup.
2. Verify a PostgreSQL backup.
3. Restore a database from a backup.
4. Explain the purpose of WAL.
5. Configure WAL archiving.
6. Create a PostgreSQL base backup.
7. Explain point-in-time recovery.
8. Simulate database data loss in a test environment.
9. Create a replication user.
10. Configure access for replication.
11. Build a streaming standby.
12. Check PostgreSQL replication health and lag.

---

# Conclusion

This lab demonstrates how PostgreSQL can be protected against data loss using several complementary techniques.

The logical backup provides a portable database backup, WAL archiving preserves a history of database changes, and a base backup provides the starting point for point-in-time recovery.

Streaming replication provides another level of protection by maintaining a standby server that receives changes from the primary server.

Together, these techniques provide a practical foundation for PostgreSQL backup, recovery, and high-availability administration.
