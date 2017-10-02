#!/bin/sh
set -e

if [[ "$DEBUG" == "true" ]]; then
  set -x
fi

case ${DB_TYPE} in
  postgresql)
    DB_ROOT_USER=${DB_ROOT_USER:-postgres}
    DB_PORT=${DB_PORT:-5432}
    export PGPASSWORD=$DB_ROOT_PASSWORD
    ;;

  mysql) 
    DB_ROOT_USER=${DB_ROOT_USER:-root}
    DB_PORT=${DB_PORT:-3306}
    ;;
esac


check_database_connection() {
  if [[ -z ${DB_HOST} ]] || [[ -z ${DB_ROOT_PASSWORD} ]] || [[ -z ${DB_DATABASE} ]] || [[ -z ${DB_USER} ]] || [[ -z ${DB_PASSWORD} ]]; then
    echo
    echo "ERROR: "
    echo "  Please specify DB_HOST, DB_ROOT_PASSWORD, DB_DATABASE, DB_USER & DB_PASSWORD"
    echo "  Aborting..."
    echo
    return 1
  fi

  case ${DB_TYPE} in
    mysql)
      prog="mysqladmin -h ${DB_HOST} -P ${DB_PORT} -u ${DB_ROOT_USER} -p${DB_ROOT_PASSWORD} status"
      ;;
    postgresql)
      prog="pg_isready -h ${DB_HOST} -p ${DB_PORT} -U ${DB_ROOT_USER} -t 1"
      ;;
    *)
      echo
      echo "ERROR: "
      echo "  Please specify the database type in use via the DB_TYPE configuration option."
      echo "  Accepted values are \"postgresql\" or \"mysql\". Aborting..."
      echo
      return 1
  esac
  timeout=60
  while ! ${prog} >/dev/null 2>&1
  do
    timeout=$(expr $timeout - 1)
    if [[ $timeout -eq 0 ]]; then
      echo
      echo "Could not connect to database server. Aborting..."
      return 1
    fi
    echo -n "."
    sleep 1
  done
  echo
}


postgresql_clear_init() {
  result=`psql -h$DB_HOST -p $DB_PORT -U$DB_ROOT_USER -tc "SELECT datname FROM pg_catalog.pg_database WHERE datname like '$DB_DATABASE';"`
  if [ $result ]; then
    psql -h$DB_HOST -p $DB_PORT -U$DB_ROOT_USER -tc "drop database if exists $DB_DATABASE;" > /dev/null
    echo "Removed database \"$DB_DATABASE\""
  fi

  postgresql_init
}

postgresql_init() {
  result=`psql -h$DB_HOST -p $DB_PORT -U$DB_ROOT_USER -tc "SELECT datname FROM pg_catalog.pg_database WHERE datname like '$DB_DATABASE';"`
  if [ ! $result ]; then
    psql -h$DB_HOST -p $DB_PORT -U$DB_ROOT_USER -tc "create database $DB_DATABASE;" > /dev/null
    echo "Database \"$DB_DATABASE\" created"
  else
    echo "Database \"$DB_DATABASE\" already exist"
  fi

  result=`psql -h$DB_HOST -p $DB_PORT -U$DB_ROOT_USER -tc "SELECT usename FROM pg_catalog.pg_user WHERE usename = '$DB_USER';"`
  if [ ! $result ]; then
    psql -h$DB_HOST -p $DB_PORT -U$DB_ROOT_USER -c "CREATE ROLE $DB_USER with LOGIN CREATEDB PASSWORD '$DB_PASSWORD';" > /dev/null
    echo "User \"$DB_USER\" created"
  else
    echo "User \"$DB_USER\" already exist"
  fi

  psql -h$DB_HOST -p $DB_PORT -U$DB_ROOT_USER -tc "GRANT ALL PRIVILEGES ON DATABASE $DB_DATABASE to $DB_USER;" > /dev/null

  # TODO make this configurable
  psql -h$DB_HOST -p $DB_PORT -U$DB_ROOT_USER -d $DB_DATABASE -tc "CREATE EXTENSION pg_trgm;" > /dev/null 2> /dev/null || true
}

postgresql_auto_backup() {
  case ${BACKUP_SCHEDULE} in
    15min|hourly|daily|weekly|monthly)
      # create backup dir
      mkdir -p /backup
      
      # create backup script
      cat > /etc/periodic/${BACKUP_SCHEDULE}/backup <<EOF
#!/bin/sh

export PGPASSWORD=$DB_ROOT_PASSWORD

now=\$(date +"%Y%d%m_%H%M%S")
pg_dump -h ${DB_HOST} -p ${DB_PORT} -U ${DB_ROOT_USER} ${DB_DATABASE} | gzip -c > /backup/${DB_DATABASE}_\${now}.sql.gz
EOF
      chmod +x /etc/periodic/${BACKUP_SCHEDULE}/backup
      ;;
  esac
}


mysql_clear_init() {
  result=`mysql -P $DB_PORT -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -Bse "show databases like '$DB_DATABASE';"`
  if [ $result ]; then
    mysql -P $DB_PORT -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -Bse "drop database if exists $DB_DATABASE;"
    echo "Removed database \"$DB_DATABASE\""
  fi

  mysql_init
}

mysql_init() {
  result=`mysql -P $DB_PORT -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -Bse "show databases like '$DB_DATABASE';"`
  if [ ! $result ]; then
    mysql -P $DB_PORT -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -Bse "create database $DB_DATABASE;"
    echo "Database \"$DB_DATABASE\" created"
  else
    echo "Database \"$DB_DATABASE\" already exist"
  fi

  result=`mysql -P $DB_PORT -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -Bse "SELECT User FROM mysql.user WHERE User = '$DB_USER' AND Host = '%';"`
  if [ ! $result ]; then
    mysql -P $DB_PORT -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -Bse "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';"
    echo "User \"$DB_USER\" created"
  else
    echo "User \"$DB_USER\" already exist"
  fi

  mysql -P $DB_PORT -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD -h$DB_HOST -Bse "GRANT ALL PRIVILEGES ON \`$DB_DATABASE\`.* TO '$DB_USER'@'%';"
}

mysql_auto_backup() {
  case ${BACKUP_SCHEDULE} in
    15min|hourly|daily|weekly|monthly)
      # create backup dir
      mkdir -p /backup
      
      # create backup script
      cat > /etc/periodic/${BACKUP_SCHEDULE}/backup <<EOF
#!/bin/sh

now=\$(date +"%Y%d%m_%H%M%S")
mysqldump -h ${DB_HOST} -P ${DB_PORT} -u ${DB_ROOT_USER} -p$DB_ROOT_PASSWORD ${DB_DATABASE} | gzip -c > /backup/${DB_DATABASE}_\${now}.sql.gz
EOF
      chmod +x /etc/periodic/${BACKUP_SCHEDULE}/backup
      ;;
  esac
}


case ${1} in
  app:init|app:clear_init)
    check_database_connection

    case ${DB_TYPE} in
      postgresql)
        case ${1} in
          app:init)
            postgresql_init
            ;;

          app:clear_init)
            postgresql_clear_init
            ;;
        esac

        postgresql_auto_backup
        ;;

      mysql)
        case ${1} in
          app:init)
            mysql_init
            ;;

          app:clear_init)
            mysql_clear_init
            ;;
        esac

        mysql_auto_backup
        ;;
    esac

    exec /usr/sbin/crond -f
    ;;
  *)
    exec "$@"
    ;;
esac
