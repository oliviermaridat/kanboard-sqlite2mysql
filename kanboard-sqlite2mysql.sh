#!/usr/bin/env bash

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))
readonly ARGS="$@"

usage()
{
	cat <<- EOF
	usage: $PROGNAME <Kanboard instance physical path> [ <MySQL DB name> -h <MySQL DB host> -u <MySQL DB user> -p ] [ --help ]

	 -p, --password		MySQL database password. If password is not given it's asked from the tty.
	 -h, --host		MySQL database host
	 -u, --user		MySQL database user for login
	 -o, --output		Path to the output SQL dump compatible with MySQL
	 -v, --verbose		Enable more verbosity
	 -H, --help		Display this help
	 -V, --version		Display the Kanboard SQLite2MySQL version

	Example:
	 $PROGNAME /usr/local/share/www/kanboard -o db-mysql.sql
	 $PROGNAME /usr/local/share/www/kanboard kanboard -u root --password root
	EOF
}

version()
{
	cat <<- EOF
	Kanboard SQLite2MySQL 0.0.1
	Migrate your SQLite Kanboard database to MySQL in one go! By Olivier.
	EOF
}

cmdline()
{
  KANBOARD_PATH=
  DB_HOSTNAME=
  DB_USERNAME=
  DB_PASSWORD=
  DB_NAME=
  OUTPUT_FILE=db-mysql.sql
  IS_VERBOSE=0
  if [ "$#" -lt "1" ]; then
    echo 'error: missing arguments'
    usage
    exit -1
  fi
  while [ "$1" != "" ]; do
  case $1 in
    -o | --output )
      shift
      OUTPUT_FILE=$1
      shift
      ;;
    -h | --host )
      shift
      DB_HOSTNAME=$1
      shift
      ;;
    -u | --user )
      shift
      DB_USERNAME=$1
      shift
      ;;
    -p )
      shift
      echo 'Enter password: '
      read DB_PASSWORD
      ;;
    --password )
      shift
      DB_PASSWORD=$1
      shift
      ;;
    -v | --verbose )
      shift
      IS_VERBOSE=1
      ;;
    -H | --help )
      usage
      exit 0
      ;;
    -V | --version )
      version
      exit 0
      ;;
    *)
      if [ "${KANBOARD_PATH}" == ""  ]; then
        if [ ! -d "$1" ]; then
          echo "error: unknown path '$1'"
          usage
          exit -1
        fi
        KANBOARD_PATH=$1
        shift
      elif [ "$DB_NAME" == ""  ]; then
        DB_NAME=$1
        shift
      else
        echo "error: unknwon argument '$1'"
        usage
        exit -1
      fi
      ;;
  esac
  done
  
  if [ ! "${DB_NAME}" == "" ]; then
    if [ "${DB_USERNAME}" == "" ]; then
        DB_USERNAME=root
    fi
    if [ "${DB_HOSTNAME}" == "" ]; then
        DB_HOSTNAME=localhost
    fi
  fi
  return 0
}

# List tables names of a SQLite database
# 'sqlite3 db.sqlite .tables' already return tables names but only in column mode...
# * @param Database file
sqlite_tables()
{
    local sqliteDbFile=$1
    sqlite3 ${sqliteDbFile} .schema \
        | sed -e '/[^C(]$/d' -e '/^\s\+($/d' -e 's/CREATE TABLE \([a-z_]*\).*/\1/' -e '/^$/d'
}

# List column names of a SQLite table
# * @param Database file
# * @param Table name
sqlite_columns()
{
    local sqliteDbFile=$1
    local table=$2
    sqlite3 -csv -header ${sqliteDbFile} "select * from ${table};" \
        | head -n 1 \
        | sed -e 's/,/`,`/g' -e 's/^/`/' -e 's/$/`/'
}

# Generate "INSERT INTO" queries to dump data of an SQLite table
# * @param Database file
# * @param Table name
sqlite_dump_table_data()
{
    local sqliteDbFile=$1
    local table=$2
    local columns=`sqlite_columns ${sqliteDbFile} ${table}`
    
    echo -e ".mode insert ${table}\nselect * from ${table};" \
        | sqlite3 ${sqliteDbFile} \
        | sed -e "s/INSERT INTO \([a-z_\"]*\)/INSERT INTO \1 (${columns})/"
}

# If verbose, displays version of the schema found in the SQLite file. Beware this version is different from MySQL schema versions
sqlite_dump_schemaversion()
{
    local sqliteDbFile=$1
    if [ "1" == "${IS_VERBOSE}" ]; then
        echo "# Found schema version `sqlite3 ${sqliteDbFile} 'PRAGMA user_version'` for SQLite"
    fi
}

# Generate "INSERT INTO" queries to dump data of a SQLite database
# * @param Database file
sqlite_dump_data()
{
    local sqliteDbFile=$1
    local prioritizedTables='plugin_schema_versions projects columns links groups users tasks task_has_links subtasks comments actions'
    for t in $prioritizedTables; do
        # Please do not ask why: this TRUNCATE is already done elsewhere, but this table "plugin_schema_versions" seems to be refillld I don't know where... This fix the issue
        if [ "plugin_schema_versions" == "${t}" ]; then
            echo 'TRUNCATE TABLE plugin_schema_versions;'
        fi
        sqlite_dump_table_data ${sqliteDbFile} ${t}
    done
    for t in $(sqlite_tables ${sqliteDbFile} | sed -e '/^plugin_schema_versions$/d' -e '/^projects$/d' -e '/^columns$/d' -e '/^links$/d' -e '/^groups$/d' -e '/^users$/d' -e '/^tasks$/d' -e '/^task_has_links$/d' -e '/^subtasks$/d' -e '/^comments$/d' -e '/^actions$/d'); do
        sqlite_dump_table_data ${sqliteDbFile} ${t}
    done
}

createMysqlDump()
{
    local sqliteDbFile=$1
    
    echo 'ALTER TABLE users ADD COLUMN is_admin INT DEFAULT 0;
    ALTER TABLE users ADD COLUMN default_project_id INT DEFAULT 0;
    ALTER TABLE users ADD COLUMN is_project_admin INT DEFAULT 0;
    ALTER TABLE tasks ADD COLUMN estimate_duration VARCHAR(255) DEFAULT "";
    ALTER TABLE tasks ADD COLUMN actual_duration VARCHAR(255) DEFAULT "";
    ALTER TABLE project_has_users ADD COLUMN id INT DEFAULT 0;
    ALTER TABLE project_has_users ADD COLUMN is_owner INT DEFAULT 0;
    ALTER TABLE projects ADD COLUMN is_everybody_allowed TINYINT(1) DEFAULT 0;
    ALTER TABLE projects ADD COLUMN default_swimlane VARCHAR(200) DEFAULT "Default swimlane";
    ALTER TABLE projects ADD COLUMN show_default_swimlane INT DEFAULT 1;
    ALTER TABLE tasks DROP FOREIGN KEY tasks_swimlane_ibfk_1;

    SET FOREIGN_KEY_CHECKS = 0;
    TRUNCATE TABLE settings;
    TRUNCATE TABLE users;
    TRUNCATE TABLE links;
    TRUNCATE TABLE plugin_schema_versions;
    SET FOREIGN_KEY_CHECKS = 1;' > ${OUTPUT_FILE}
    
    echo 'ALTER TABLE `tasks` CHANGE `column_id` `column_id` INT( 11 ) NULL;' >> ${OUTPUT_FILE}

    sqlite_dump_data ${sqliteDbFile} >> ${OUTPUT_FILE}
    
    echo 'ALTER TABLE users DROP COLUMN is_admin;
    ALTER TABLE users DROP COLUMN default_project_id;
    ALTER TABLE users DROP COLUMN is_project_admin;
    ALTER TABLE tasks DROP COLUMN estimate_duration;
    ALTER TABLE tasks DROP COLUMN actual_duration;
    ALTER TABLE project_has_users DROP COLUMN id;
    ALTER TABLE project_has_users DROP COLUMN is_owner;
    ALTER TABLE projects DROP COLUMN is_everybody_allowed;
    ALTER TABLE projects DROP COLUMN default_swimlane;
    ALTER TABLE projects DROP COLUMN show_default_swimlane;' >> ${OUTPUT_FILE}
    
    #echo 'ALTER TABLE `tasks` CHANGE `column_id` `column_id` INT( 11 ) NOT NULL;' >> ${OUTPUT_FILE}

    echo 'ALTER TABLE tasks ADD CONSTRAINT tasks_swimlane_ibfk_1 FOREIGN KEY (swimlane_id) REFERENCES swimlanes(id) ON DELETE CASCADE;' >> ${OUTPUT_FILE}

    # For MySQL, we need to double the anti-slash (\\ instead of \)
    # But we need to take care of Windows URL (e.g. C:\test\) in the JSON of project_activities (e.g. C:\test\" shall not become C:\\test\\" this will break the json...). Windows URL are transformed into Linux URL for this reason
    cat ${OUTPUT_FILE} \
        | sed -e 's/\\\\"/"/g' \
        | sed -e 's/\\\\/\//g' \
        | sed -e 's/\\"/##"/g' \
        | sed -e 's/\\u\([[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]\)/##u\1/g' \
        | sed -e 's/\\/\//g' \
        | sed -e 's/##"/\\\\"/g' \
        | sed -e 's/##u\([[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]\)/\\u\1/g' \
        | sed -e 's/\/Kanboard\/Action\//\\\\Kanboard\\\\Action\\\\/g' \
        | sed -e 's/\/r\/n/\\\\n/g' \
        | sed -e 's/\/\//\//g' \
        > db.mysql
    mv db.mysql ${OUTPUT_FILE}
}

generateMysqlSchema()
{
    mv ${KANBOARD_PATH}/config.php ${KANBOARD_PATH}/config_tmp.php
    export DATABASE_URL="mysql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOSTNAME}/${DB_NAME}"
    php ${KANBOARD_PATH}/app/common.php
    mv ${KANBOARD_PATH}/config_tmp.php ${KANBOARD_PATH}/config.php
}

fillMysqlDb()
{
    local verbosity=
    if [ "1" == "${IS_VERBOSE}" ]; then
        verbosity="--verbose"
    fi
    mysql ${verbosity} -h ${DB_HOSTNAME} -u ${DB_USERNAME} --password=${DB_PASSWORD} ${DB_NAME} \
        < ${OUTPUT_FILE}
}

main()
{
    cmdline $ARGS
    local sqliteDbFile=${KANBOARD_PATH}/data/db.sqlite

    sqlite_dump_schemaversion ${sqliteDbFile}
    
    echo '# Create MySQL data dump from SQLite database'
    createMysqlDump ${sqliteDbFile} \
        && (echo "done" ; echo "check ${OUTPUT_FILE}") \
        || (echo 'FAILLURE' ; exit -1)

    if [ ! "${DB_NAME}" == "" ]; then
        echo '# Generate schema in the MySQL database using Kanboard'
        generateMysqlSchema \
            && echo "done" \
            || (echo 'FAILLURE' ; exit -1)

        echo '# Fill the MySQL database with the SQLite database data'
        fillMysqlDb \
            && echo "done" \
            || (echo 'FAILLURE' ; exit -1)
    fi
}
main


