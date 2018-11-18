<?php

require_once(dirname(__FILE__) . "/../inc/conf.php");
use DBA\AccessGroupUser;
use DBA\Config;
use DBA\QueryFilter;
use DBA\RightGroup;
use DBA\User;
use DBA\Factory;

require_once(dirname(__FILE__) . "/../inc/load.php");

    $pepper = array(Util::randomString(50), Util::randomString(50), Util::randomString(50));
    $key = Util::randomString(40);
    $conf = file_get_contents(dirname(__FILE__) . "/../inc/conf.php");
    $conf = str_replace("__PEPPER1__", $pepper[0], str_replace("__PEPPER2__", $pepper[1], str_replace("__PEPPER3__", $pepper[2], $conf)));
    $conf = str_replace("__CSRF__", $key, $conf);
    file_put_contents(dirname(__FILE__) . "/../inc/conf.php", $conf);
    
    if (Factory::getUserFactory()->getDB(true) === null) {
      //connection not valid
	printf ( "Unable to connect to the Database\n" );
        exit;
    }
?>
