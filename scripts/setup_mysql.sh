#!/bin/bash
set -e

# Author: Dr. Dongfang Zhao (dzhao@cs.washington.edu)
#
# Configuration
# WARNING: Do not use hardcoded passwords in production.

ROOT_PASS='root'
USER_NAME='hpdic'
USER_PASS='hpdic2023'
USER_HOST='localhost'

echo 'MySQL Automated Setup Script'
echo 'Please enter the CURRENT MySQL root password. Press Enter if none.'
read -s CURRENT_ROOT_PASS
echo ''

if [[ -z ${CURRENT_ROOT_PASS} ]]; then
    MYSQL_CMD='sudo mysql'
else
    MYSQL_CMD='mysql -u root -p'${CURRENT_ROOT_PASS}
fi

echo 'Executing SQL commands...'

${MYSQL_CMD} <<MYSQL_SCRIPT
ALTER USER 'root'@'${USER_HOST}' IDENTIFIED WITH 'mysql_native_password' BY '${ROOT_PASS}';

DROP USER IF EXISTS '${USER_NAME}'@'${USER_HOST}';

CREATE USER '${USER_NAME}'@'${USER_HOST}' IDENTIFIED WITH 'mysql_native_password' BY '${USER_PASS}';

GRANT ALL PRIVILEGES ON *.* TO '${USER_NAME}'@'${USER_HOST}' WITH GRANT OPTION;

FLUSH PRIVILEGES;

SELECT 'MySQL setup complete.' AS 'Status';
MYSQL_SCRIPT

echo 'Setup Complete.'
echo 'Root password has been updated.'
echo 'User has been recreated.'
echo ''

echo 'Testing root connection...'
if mysql -u root -p${ROOT_PASS} -e 'SHOW DATABASES;' > /dev/null 2>&1; then
    echo 'Root login successful.'
else
    echo 'Root login FAILED!'
    exit 1
fi

echo 'Testing new user connection...'
if mysql -u ${USER_NAME} -p${USER_PASS} -e 'SHOW DATABASES;' > /dev/null 2>&1; then
    echo 'New user login successful.'
else
    echo 'New user login FAILED!'
    exit 1
fi

echo 'Automation Succeeded.'