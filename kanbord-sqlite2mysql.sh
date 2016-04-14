#!/usr/bin/env bash

DB_HOSTNAME=localhost
DB_USERNAME=root
DB_PASSWORD=root
DB_NAME=kanboard2
DB_FILE=data/db.sqlite

function createMysqlDump
{
    sqlite3 ${DB_FILE} .dump | python sqlite2mysql.py > db-mysql.sql

    cat db-mysql.sql
        | sed -e 's/\\Kanboard\\Action\\/\\\\Kanboard\\\\Action\\\\/g'
        | sed -e '/^DROP TABLE.*$/d'
        > db-mysql.sql
}

function generateMysqlSchema
{
    mv config.php config_tmp.php
    export DATABASE_URL="mysql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOSTNAME}/${DB_NAME}"
    php index.php
    mv config_tmp.php config.php
}

function fillMysqlDb
{
    SQL_ADD_MISSING_COLUMS='ALTER TABLE users ADD COLUMN is_admin INT DEFAULT 0;
    ALTER TABLE users ADD COLUMN default_project_id INT DEFAULT 0;
    ALTER TABLE users ADD COLUMN is_project_admin INT DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN estimate_duration VARCHAR(255) DEFAULT '';
    ALTER TABLE tasks ADD COLUMN actual_duration VARCHAR(255) DEFAULT '';
    ALTER TABLE project_has_users ADD COLUMN id INT DEFAULT 0;
    ALTER TABLE project_has_users ADD COLUMN is_owner INT DEFAULT 0;'
    echo ${SQL_ADD_MISSING_COLUMS} > 1
    SQL_REMOVE_ADDED_COLUMS='ALTER TABLE users DROP COLUMN is_admin;
    ALTER TABLE users DROP COLUMN default_project_id;
    ALTER TABLE users DROP COLUMN is_project_admin;
    ALTER TABLE tasks DROP COLUMN estimate_duration;
    ALTER TABLE tasks DROP COLUMN actual_duration;
    ALTER TABLE project_has_users DROP COLUMN id;
    ALTER TABLE project_has_users DROP COLUMN is_owner;'
    echo ${SQL_REMOVE_ADDED_COLUMS} > 2
    
    mysql -h ${DB_HOSTNAME} -u ${DB_USERNAME} --password=${DB_PASSWORD} ${DB_NAME} < 1

    mysql -h ${DB_HOSTNAME} -u ${DB_USERNAME} --password=${DB_PASSWORD} ${DB_NAME} < db-mysql.sql

    mysql -h ${DB_HOSTNAME} -u ${DB_USERNAME} --password=${DB_PASSWORD} ${DB_NAME} < 2
}

echo '# Create MySQL dump from Sqlite database'
createMysqlDump

echo '# Generate schema in the MySQL database'
generateMysqlSchema

echo '# Fill the MySQL database with the Sqlite database data'
fillMysqlDb