Kanboard - SQLite2MySQL
=======================

Guidelines to migrate a Kanboard SQLite database to a MySQL / MariaDB one.

Usage
------------------------

*/!\ This work is in progress and DOES NOT WORK YET! This script can be used to perform the migration manually! You have been adviced!*

Copy / paste the two scripts into your Kanboard repository and run:

    ./kanbord-sqlite2mysql.sh


Steps to reproduce
------------------------

* Create an SQL dump from the SQLite database

     sqlite3 data/db.sqlite .dump > db-mysql.sql
     
* Change this SQL dump to something working with MySQL using a script (to be done)

* Move the "INSERT INTO" for project, columns, tasks, links at the beginning of the dump

* users: remove is_admin,default_project_id,is_admin_project

    ALTER TABLE users ADD COLUMN is_admin INT DEFAULT 0;
    ALTER TABLE users ADD COLUMN default_project_id INT DEFAULT 0;
    ALTER TABLE users ADD COLUMN is_project_admin INT DEFAULT 0;
    ALTER TABLE users DROP COLUMN is_admin;
    ALTER TABLE users DROP COLUMN default_project_id;
    ALTER TABLE users DROP COLUMN is_project_admin;

* tasks: remove estimate_duration, actual_duration, replace \ by /

    ALTER TABLE tasks ADD COLUMN estimate_duration VARCHAR(255) DEFAULT '';
    ALTER TABLE tasks ADD COLUMN actual_duration VARCHAR(255) DEFAULT '';
    ALTER TABLE tasks DROP COLUMN estimate_duration;
    ALTER TABLE tasks DROP COLUMN actual_duration;

* settings: add quote around `option` and`value` n the SQL dump

* project_has_users: remove id and is_owner

    ALTER TABLE project_has_users ADD COLUMN id INT DEFAULT 0;
    ALTER TABLE project_has_users ADD COLUMN is_owner INT DEFAULT 0;
    ALTER TABLE project_has_users DROP COLUMN id;
    ALTER TABLE project_has_users DROP COLUMN is_owner;

* comments: Replace \ by /

* actions: Replace \ by \\