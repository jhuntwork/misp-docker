#!/bin/bash

init_mysql(){
    # Test when MySQL is ready....
    # wait for Database come ready
    isDBup () {
        echo "SHOW STATUS" | $MYSQL_CMD 1>/dev/null
        echo $?
    }

    isDBinitDone () {
        # Table attributes has existed since at least v2.1
        echo "DESCRIBE attributes" | $MYSQL_CMD 1>/dev/null
        echo $?
    }

    RETRY=100
    until [ $(isDBup) -eq 0 ] || [ $RETRY -le 0 ] ; do
        echo "... waiting for database to come up"
        sleep 5
        RETRY=$(( RETRY - 1))
    done
    if [ $RETRY -le 0 ]; then
        >&2 echo "... error: Could not connect to Database on $MYSQL_HOST:$MYSQL_PORT"
        exit 1
    fi

    if [ $(isDBinitDone) -eq 0 ]; then
        echo "... database has already been initialized"
        export DB_ALREADY_INITIALISED=true
    else
        echo "... database has not been initialized, importing MySQL scheme..."
        $MYSQL_CMD < /var/www/MISP/INSTALL/MYSQL.sql
    fi
}

init_misp_data_files(){
    # Init config (shared with host)
    echo "... initialize configuration files"
    MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
    # workaround for https://forums.docker.com/t/sed-couldnt-open-temporary-file-xyz-permission-denied-when-using-virtiofs/125473
    # [ -f $MISP_APP_CONFIG_PATH/bootstrap.php ] || cp $MISP_APP_CONFIG_PATH.dist/bootstrap.default.php $MISP_APP_CONFIG_PATH/bootstrap.php
    # [ -f $MISP_APP_CONFIG_PATH/database.php ] || cp $MISP_APP_CONFIG_PATH.dist/database.default.php $MISP_APP_CONFIG_PATH/database.php
    # [ -f $MISP_APP_CONFIG_PATH/core.php ] || cp $MISP_APP_CONFIG_PATH.dist/core.default.php $MISP_APP_CONFIG_PATH/core.php
    # [ -f $MISP_APP_CONFIG_PATH/config.php ] || cp $MISP_APP_CONFIG_PATH.dist/config.default.php $MISP_APP_CONFIG_PATH/config.php
    # [ -f $MISP_APP_CONFIG_PATH/email.php ] || cp $MISP_APP_CONFIG_PATH.dist/email.php $MISP_APP_CONFIG_PATH/email.php
    # [ -f $MISP_APP_CONFIG_PATH/routes.php ] || cp $MISP_APP_CONFIG_PATH.dist/routes.php $MISP_APP_CONFIG_PATH/routes.php
    [ -f $MISP_APP_CONFIG_PATH/bootstrap.php ] || dd if=$MISP_APP_CONFIG_PATH.dist/bootstrap.default.php of=$MISP_APP_CONFIG_PATH/bootstrap.php
    [ -f $MISP_APP_CONFIG_PATH/database.php ] || dd if=$MISP_APP_CONFIG_PATH.dist/database.default.php of=$MISP_APP_CONFIG_PATH/database.php
    [ -f $MISP_APP_CONFIG_PATH/core.php ] || dd if=$MISP_APP_CONFIG_PATH.dist/core.default.php of=$MISP_APP_CONFIG_PATH/core.php
    [ -f $MISP_APP_CONFIG_PATH/config.php.template ] || dd if=$MISP_APP_CONFIG_PATH.dist/config.default.php of=$MISP_APP_CONFIG_PATH/config.php.template
    [ -f $MISP_APP_CONFIG_PATH/config.php ] || echo -e "<?php\n\$config=array();\n?>" > $MISP_APP_CONFIG_PATH/config.php
    [ -f $MISP_APP_CONFIG_PATH/email.php ] || dd if=$MISP_APP_CONFIG_PATH.dist/email.php of=$MISP_APP_CONFIG_PATH/email.php
    [ -f $MISP_APP_CONFIG_PATH/routes.php ] || dd if=$MISP_APP_CONFIG_PATH.dist/routes.php of=$MISP_APP_CONFIG_PATH/routes.php

    echo "... initialize database.php settings"
    # workaround for https://forums.docker.com/t/sed-couldnt-open-temporary-file-xyz-permission-denied-when-using-virtiofs/125473
    # sed -i "s/localhost/$MYSQL_HOST/" $MISP_APP_CONFIG_PATH/database.php
    # sed -i "s/db\s*login/$MYSQL_USER/" $MISP_APP_CONFIG_PATH/database.php
    # sed -i "s/3306/$MYSQL_PORT/" $MISP_APP_CONFIG_PATH/database.php
    # sed -i "s/db\s*password/$MYSQL_PASSWORD/" $MISP_APP_CONFIG_PATH/database.php
    # sed -i "s/'database' => 'misp'/'database' => '$MYSQL_DATABASE'/" $MISP_APP_CONFIG_PATH/database.php
    chmod +w $MISP_APP_CONFIG_PATH/database.php
    sed "s/localhost/$MYSQL_HOST/" $MISP_APP_CONFIG_PATH/database.php > tmp; cat tmp > $MISP_APP_CONFIG_PATH/database.php; rm tmp
    sed "s/db\s*login/$MYSQL_USER/" $MISP_APP_CONFIG_PATH/database.php > tmp; cat tmp > $MISP_APP_CONFIG_PATH/database.php; rm tmp
    sed "s/3306/$MYSQL_PORT/" $MISP_APP_CONFIG_PATH/database.php > tmp; cat tmp > $MISP_APP_CONFIG_PATH/database.php; rm tmp
    sed "s/db\s*password/$MYSQL_PASSWORD/" $MISP_APP_CONFIG_PATH/database.php > tmp; cat tmp > $MISP_APP_CONFIG_PATH/database.php; rm tmp
    sed "s/'database' => 'misp'/'database' => '$MYSQL_DATABASE'/" $MISP_APP_CONFIG_PATH/database.php > tmp; cat tmp > $MISP_APP_CONFIG_PATH/database.php; rm tmp

    echo "... initialize email.php settings"
    chmod +w $MISP_APP_CONFIG_PATH/email.php
    tee $MISP_APP_CONFIG_PATH/email.php > /dev/null <<EOT
<?php
class EmailConfig {
    public \$default = array(
        'transport'     => 'Smtp',
        'from'          => array('misp-dev@admin.test' => 'Misp DEV'),
        'host'          => '$SMTP_FQDN',
        'port'          => 25,
        'timeout'       => 30,
        'client'        => null,
        'log'           => false,
    );
    public \$smtp = array(
        'transport'     => 'Smtp',
        'from'          => array('misp-dev@admin.test' => 'Misp DEV'),
        'host'          => '$SMTP_FQDN',
        'port'          => 25,
        'timeout'       => 30,
        'client'        => null,
        'log'           => false,
    );
    public \$fast = array(
        'from'          => 'misp-dev@admin.test',
        'sender'        => null,
        'to'            => null,
        'cc'            => null,
        'bcc'           => null,
        'replyTo'       => null,
        'readReceipt'   => null,
        'returnPath'    => null,
        'messageId'     => true,
        'subject'       => null,
        'message'       => null,
        'headers'       => null,
        'viewRender'    => null,
        'template'      => false,
        'layout'        => false,
        'viewVars'      => null,
        'attachments'   => null,
        'emailFormat'   => null,
        'transport'     => 'Smtp',
        'host'          => '$SMTP_FQDN',
        'port'          => 25,
        'timeout'       => 30,
        'client'        => null,
        'log'           => true,
    );
}
EOT
    chmod -w $MISP_APP_CONFIG_PATH/email.php

    # Init files (shared with host)
    echo "... initialize app files"
    MISP_APP_FILES_PATH=/var/www/MISP/app/files
    if [ ! -f ${MISP_APP_FILES_PATH}/INIT ]; then
        cp -R ${MISP_APP_FILES_PATH}.dist/* ${MISP_APP_FILES_PATH}
        touch ${MISP_APP_FILES_PATH}/INIT
    fi
}

update_misp_data_files(){
    for DIR in $(ls /var/www/MISP/app/files.dist); do
        if [ "$DIR" = "certs" ] || [ "$DIR" = "img" ] || [ "$DIR" == "taxonomies" ] ; then
            echo "... rsync -azh \"/var/www/MISP/app/files.dist/$DIR\" \"/var/www/MISP/app/files/\""
            rsync -azh "/var/www/MISP/app/files.dist/$DIR" "/var/www/MISP/app/files/"
        else
            echo "... rsync -azh --delete \"/var/www/MISP/app/files.dist/$DIR\" \"/var/www/MISP/app/files/\""
            rsync -azh --delete "/var/www/MISP/app/files.dist/$DIR" "/var/www/MISP/app/files/"
        fi
    done
}

enforce_misp_data_permissions(){
    echo "... chown -R www-data:www-data /var/www/MISP/app/tmp" && find /var/www/MISP/app/tmp \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
    # Files are also executable and read only, because we have some rogue scripts like 'cake' and we can not do a full inventory
    echo "... chmod -R 0550 files /var/www/MISP/app/tmp" && find /var/www/MISP/app/tmp -not -perm 550 -type f -exec chmod 0550 {} +
    # Directories are also writable, because there seems to be a requirement to add new files every once in a while
    echo "... chmod -R 0770 directories /var/www/MISP/app/tmp" && find /var/www/MISP/app/tmp -not -perm 770 -type d -exec chmod 0770 {} +
    # We make 'files' and 'tmp' (logs) directories and files user and group writable (we removed the SGID bit)
    echo "... chmod -R u+w,g+w /var/www/MISP/app/tmp" && chmod -R u+w,g+w /var/www/MISP/app/tmp

    echo "... chown -R www-data:www-data /var/www/MISP/app/files" && find /var/www/MISP/app/files \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
    # Files are also executable and read only, because we have some rogue scripts like 'cake' and we can not do a full inventory
    echo "... chmod -R 0550 files /var/www/MISP/app/files" && find /var/www/MISP/app/files -not -perm 550 -type f -exec chmod 0550 {} +
    # Directories are also writable, because there seems to be a requirement to add new files every once in a while
    echo "... chmod -R 0770 directories /var/www/MISP/app/files" && find /var/www/MISP/app/files -not -perm 770 -type d -exec chmod 0770 {} +
    # We make 'files' and 'tmp' (logs) directories and files user and group writable (we removed the SGID bit)
    echo "... chmod -R u+w,g+w /var/www/MISP/app/files" && chmod -R u+w,g+w /var/www/MISP/app/files

    echo "... chown -R www-data:www-data /var/www/MISP/app/Config" && find /var/www/MISP/app/Config \( ! -user www-data -or ! -group www-data \) -exec chown www-data:www-data {} +
    # Files are also executable and read only, because we have some rogue scripts like 'cake' and we can not do a full inventory
    echo "... chmod -R 0550 files /var/www/MISP/app/Config ..." && find /var/www/MISP/app/Config -not -perm 550 -type f -exec chmod 0550 {} +
    # Directories are also writable, because there seems to be a requirement to add new files every once in a while
    echo "... chmod -R 0770 directories /var/www/MISP/app/Config" && find /var/www/MISP/app/Config -not -perm 770 -type d -exec chmod 0770 {} +
    # We make configuration files read only
    echo "... chmod 600 /var/www/MISP/app/Config/{config,database,email}.php" && chmod 600 /var/www/MISP/app/Config/{config,database,email}.php
}

# Initialize MySQL
echo "INIT | Initialize MySQL ..." && init_mysql

# Initialize MISP
echo "INIT | Initialize MISP files and configurations ..." && init_misp_data_files
echo "INIT | Update MISP app/files directory ..." && update_misp_data_files
echo "INIT | Enforce MISP permissions ..." && enforce_misp_data_permissions

# Run configure MISP script
echo "INIT | Configure MISP installation ..."
/configure_misp.sh

if [[ -x /custom/files/customize_misp.sh ]]; then
    echo "INIT | Customize MISP installation ..."
    /custom/files/customize_misp.sh
fi
