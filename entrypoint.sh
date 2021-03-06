#!/bin/bash

ATTEMPTS=12 # try to connect to mysql 
INTERVAL=5  # seconds before trying to reconnect

function getRandom() {
	dd if=/dev/urandom bs=32768 count=1 2>/dev/null | openssl sha512  | grep stdin | cut -d " " -f2 | cut -c1-64
}

function exitOnFail() {
    [ $? -ne 0 ] && echo "Error: ${1}" && exit 7
}

[ -n "$MYSQL_ENV_MYSQL_ROOT_PASSWORD" ] && MYSQL_ROOT_PASSWORD="$MYSQL_ENV_MYSQL_ROOT_PASSWORD"
[ -n "$MYSQL_ENV_MYSQL_USER" ]          && MYSQL_USER="$MYSQL_ENV_MYSQL_USER"
[ -n "$MYSQL_ENV_MYSQL_PASSWORD" ]      && MYSQL_PASSWORD="$MYSQL_ENV_MYSQL_PASSWORD"
[ -n "$MYSQL_ENV_MYSQL_DATABASE" ]      && MYSQL_DB="$MYSQL_ENV_MYSQL_DATABASE"
[ -n "$MYSQL_PORT_3306_TCP_ADDR" ]      && MYSQL_HOST="$MYSQL_PORT_3306_TCP_ADDR"
[ -z "$MYSQL_HOST" ]                    && MYSQL_HOST="mysql"
[ -z "$MYSQL_DB" ]                      && MYSQL_DB="hashtopolis"
[ -z "$MYSQL_PORT" ]                    && MYSQL_PORT="3306"
[ -n "$MYSQL_ROOT_PASSWORD" ]           && MYSQL_USER="root" && MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD

if [ ! -f /var/www/html/inc/conf.php ]
then
	cp -r /var/www/hashtopolis/src/inc /var/www/html/
	cp /var/backup.conf.php /var/www/html/inc/conf.php
	chown -R www-data:www-data /var/www/html
fi

if [ ! grep "PENDING" /var/www/html/inc/conf.php &>/dev/null ]
then
    /usr/sbin/apachectl -DFOREGROUND
    exit 0
fi

# CHECK MYSQL AVAILABILITY
MYSQL="mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -h$MYSQL_HOST"

$MYSQL -e "SELECT 'PING';" &>/dev/null
ERROR=$?

while [ $ERROR -ne 0 -a $ATTEMPTS -gt 1 ]
do
    ATTEMPTS=$(($ATTEMPTS-1))
    echo "Failed connecting to the database.... Sleeping ${INTERVAL} sec and retrying $ATTEMPTS more."
    sleep $INTERVAL
    $MYSQL -e "SELECT 'PING';" &>/dev/null
    ERROR=$?
done

if [ $ERROR -ne 0 ]
then
    echo "Could not connect to mysql. Please double check your settings and mysql's availability."
    exit 20
fi

# CREATE DB
$MYSQL -e "CREATE database $MYSQL_DB;"
exitOnFail "Failed to create the database ${MYSQL_DB}."

# APPEND DB
MYSQL="$MYSQL $MYSQL_DB"

# IMPORT DB
$MYSQL < /var/www/html/install/hashtopolis.sql
exitOnFail "DB Import Failed!!!"

# CONFIGURE DB
# RUN SETUP & ADD USER
sed -i -e "s/MYSQL_USER/$MYSQL_USER/" -e "s/MYSQL_PASSWORD/$MYSQL_PASSWORD/" -e "s/MYSQL_DB/$MYSQL_DB/" -e "s/MYSQL_HOST/$MYSQL_HOST/" -e "s/PENDING/true/" /var/www/html/inc/conf.php || exit 8
#	-e "s/MYSQL_PORT/$MYSQL_PORT/"  <--- fails and I don't get why...
/usr/bin/php /var/www/html/install/setup.php

# CREATE USER & PASSWORD
[ -z "$H8_USER" ] && H8_USER=$(getRandom) && echo -e "Your random username:\n\t$H8_USER\n\n\n"
[ -z "$H8_PASS" ] && H8_PASS=$(getRandom) && echo -e "Your random password:\n\t$H8_PASS\n\n\n"
sed -i -e "s/H8_USER/$H8_USER/" -e  "s/H8_PASS/$H8_PASS/" -e "s/H8_EMAIL/$H8_EMAIL/" /var/www/html/install/adduser.php
/usr/bin/php /var/www/html/install/adduser.php

# PHP MAIL SETTINGS
[ -n "$PHP_MAIL_HOST" ] && sed -i "s/^SMTP.*/SMTP = $PHP_MAIL_HOST/" /etc/php/7.0/apache2/php.ini
[ -n "$PHP_MAIL_PORT" ] && sed -i "s/^smtp_port.*/smtp_port = $PHP_MAIL_PORT/" /etc/php/7.0/apache2/php.ini
[ -n "$PHP_MAIL_FROM" ] && sed -i "s/^;sendmail_from.*/sendmail_from = $PHP_MAIL_FROM/" /etc/php/7.0/apache2/php.ini

echo "Setup finished, pruning /install folder"
rm -rf /var/www/html/install

# filling the Database, add generic cracker, hashlist and tasks

function check_ret {
    local ERROR=$?
    [ $? == 0 ] && echo -n "OK" || echo -n "FAIL"
    echo " - $1"
}

function masking {
    local MASK_=${1}
    local ID_=0
    local COUNT_=${2}

    while [ $COUNT_ -gt 0 ]; do
        ID_=$(shuf -i 0-${#1} -n 1)
        if [ "x${ID_}" != "x0" ]; then
            MASK_=${MASK_:0:ID_-1}?${MASK_:ID_}
        else
            MASK_=?${MASK_:1}
        fi
        let COUNT_=$COUNT_-1
    done

    echo ${MASK_}
}

source hashes.sh

$MYSQL -D$MYSQL_DB -e "INSERT INTO CrackerBinaryType
        ( typeName,  isChunkingAvailable)
  VALUES( 'generic', 1                  );"
  # should return crackerBinaryTypeId=2
check_ret "add generic cracker type"

$MYSQL -D$MYSQL_DB -e "INSERT INTO CrackerBinary
        (crackerBinaryTypeId, version, downloadUrl,                      binaryName   )
  VALUES(2,                   '0.0.1', 'http://localhost/malt-0.0.1.7z', 'maltcracker');"
  # should return crackerBinaryId=2
check_ret "add maltcracker binary"

[ ${#hashlist_mode[@]} != ${#hashlist_pass[@]} ] && echo "ERROR: bad hashlist[_mode|_pass] arrays size."
[ ${#hashlist_mode[@]} != ${#hashlist_hash[@]} ] && echo "ERROR: bad hashlist[_mode|_hash] arrays size."

ID=1 #database index starts with 1...
let hashlist_count=${#hashlist_mode[@]}-1
for H in $(seq 0 $hashlist_count); do
    name="${hashlist_mode[$H]}_${hashlist_pass[$H]}";

    $MYSQL -D$MYSQL_DB -e "INSERT INTO Hashlist
          (hashlistName, format, hashTypeId,           hashCount, saltSeparator, cracked, isSecret, hexSalt, isSalted, accessGroupId, notes, brainId, brainFeatures)
    VALUES('$name',      0,      ${hashlist_mode[$H]}, 1,         ':',           0,       0,        0,       0,        1,             '',    0,       0            );"
    check_ret "add $ID hashlist"

    $MYSQL -D$MYSQL_DB -e "INSERT INTO Hash
          (hashlistId, hash,                   salt, plaintext, timeCracked, chunkId, isCracked, crackPos)
    VALUES($ID,        '${hashlist_hash[$H]}', '',   '',        0,           NULL,    0,         0       );"
    check_ret "add $ID hash"

    $MYSQL -D$MYSQL_DB -e "INSERT INTO TaskWrapper
          (priority, taskType, hashlistId, accessGroupId, taskWrapperName, isArchived, cracked)
    VALUES(0,        0,        $ID,        1,             '',              0,          0      );"
    check_ret "add $ID task wrapper"

    mask=$(masking ${hashlist_pass[$H]} 1)
    $MYSQL -D$MYSQL_DB -e "INSERT INTO Task
          (taskName, attackCmd,      chunkTime, statusTimer, keyspace, keyspaceProgress, priority, color, isSmall, isCpuTask, useNewBench, skipKeyspace,
           crackerBinaryId, crackerBinaryTypeId, taskWrapperId, isArchived, notes, staticChunks, chunkSize, forcePipe, usePreprocessor, preprocessorCommand)
    VALUES('$name', '#HL# -p $mask', 600,       5,           0,        0,                0,        NULL,  0,       0,         1,           0,
           2,               2,                   $ID,           0,          '',    0,            0,         0,         0,               ''                 );"
    check_ret "add $ID task"

    let ID=$ID+1
done



/usr/sbin/apachectl -DFOREGROUND

