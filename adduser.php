<?php

require_once(dirname(__FILE__) . "/../inc/conf.php");
use DBA\AccessGroupUser;
use DBA\Config;
use DBA\QueryFilter;
use DBA\RightGroup;
use DBA\User;
use DBA\Factory;

require_once(dirname(__FILE__) . "/../inc/load.php");

    $username = "H8_USER";
    $password = "H8_PASS";
    $email = "H8_EMAIL";
    
    if (Factory::getUserFactory()->getDB(true) === null) {
      //connection not valid
	printf ( "Unable to connect to the Database\n" );
        exit;
    }

    Factory::getAgentFactory()->getDB()->beginTransaction();
    
    $qF = new QueryFilter(RightGroup::GROUP_NAME, "Administrator", "=");
    $group = Factory::getRightGroupFactory()->filter(array(Factory::FILTER => array($qF)));
    $group = $group[0];
    $newSalt = Util::randomString(20);
//    $newHash = Encryption::passwordHash($password, $newSalt);
    $user = new User(0, $username, $email, Encryption::passwordHash($password, $newSalt), $newSalt, 1, 1, 0, time(), 3600, $group->getId(), 0, "", "", "", "");
    Factory::getUserFactory()->save($user);
    
    // create default group
    $group = AccessUtils::getOrCreateDefaultAccessGroup();
    $groupUser = new AccessGroupUser(0, $group->getId(), $user->getId());
    Factory::getAccessGroupUserFactory()->save($groupUser);
    Factory::getAgentFactory()->getDB()->commit();

