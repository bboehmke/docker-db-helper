Database Helper
===============

Docker database initialization for MySQL and PostgreSQL.


Usage
-----

Direct usage:
```
docker run --rm \
    -e DB_TYPE=postgresql \
    -e DB_ROOT_PASSWORD=password \
    -e DB_HOST=host_name \
    -e DB_DATABASE=database_to_create \
    -e DB_USER=user_to_create \
    -e DB_PASSWORD=user_password \
    bboehmke/db-helper
```

In compose file:
```
services:
  db_init:
    restart: "no"
    image: bboehmke/db-helper
    environment:
    - DB_TYPE=postgresql
    - DB_ROOT_PASSWORD=password
    - DB_HOST=host_name
    - DB_DATABASE=database_to_create
    - DB_USER=user_to_create
    - DB_PASSWORD=user_password
```


Possible Commands
-----------------
- **app:init**: (Default) Create database and user if not exist
- **app:clear_init**: Like `app:init` but remove all tables from database


Available Configuration Parameters
----------------------------------

- **DB_TYPE**: Which type of database should be used: mysql or postgresql
- **DB_HOST**: Host name of database server
- **DB_ROOT_PASSWORD**: Password of root account
- **DB_ROOT_USER**: Name of root account (Default: Database default)
- **DB_PORT**: Port of database server (Default: Database default)
- **DB_DATABASE**: Database to create
- **DB_USER**: User to create with access to `DB_DATABASE`
- **DB_PASSWORD**: Password of `DB_USER`
