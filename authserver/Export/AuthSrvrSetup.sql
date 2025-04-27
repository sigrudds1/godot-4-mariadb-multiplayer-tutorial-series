INSTALL PLUGIN IF NOT EXISTS ed25519 SONAME 'auth_ed25519';

CREATE DATABASE IF NOT EXISTS `AuthSrvrTemplate` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;


-- `AuthSrvrTemplate`.`plyr_acct` definition
CREATE TABLE IF NOT EXISTS `AuthSrvrTemplate`.`player_acct` (
  `plyr_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `status` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `login_dt` datetime DEFAULT current_timestamp(),
  `login_attempts` tinyint(3) unsigned DEFAULT 0,
  `email` varchar(254) NOT NULL,
  `display_name` varchar(50) NOT NULL,
  `argon2_hash` varchar(44) NOT NULL,
  `argon2_salt` varchar(22) NOT NULL,
  `captcha` varchar(32) DEFAULT NULL,
  `prime_gw_id` tinyint(3) unsigned DEFAULT NULL,
  `gw_moved_dt` datetime DEFAULT current_timestamp(),
  `connected_gmsrvr_id` tinyint(3) unsigned DEFAULT NULL,
  `totp_key` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`plyr_id`),
  UNIQUE KEY `unq_users_display_name` (`display_name`)
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_general_ci
COMMENT='';

-- AuthSrvrTemplate.Test definition
CREATE TABLE IF NOT EXISTS `AuthSrvrTemplate`.`Test` (
  `Column1` tinyint(3) unsigned NOT NULL,
  `Column2` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Reminder: Replace 'secret' with a strong password in production
-- Note backticks on DB name
-- localhost name usually works for IPv4 but just in case, the loopback IP is included, I have seen flipflop
CREATE OR REPLACE USER `auth_server_user`@'localhost' IDENTIFIED VIA ed25519 USING PASSWORD('secret');
CREATE OR REPLACE USER `auth_server_user`@'127.0.0.1' IDENTIFIED VIA ed25519 USING PASSWORD('secret');
-- IPv6 localhost IP
CREATE OR REPLACE USER `auth_server_user`@'::1' IDENTIFIED VIA ed25519 USING PASSWORD('secret');
-- Add the subnet of expected connections, yours may be 192.168.1.%
CREATE OR REPLACE USER `auth_server_user`@'192.168.2.%' IDENTIFIED VIA ed25519 USING PASSWORD('secret');

-- Add a specific ip of an expected connection
-- CREATE USER auth_server_user`@'192.168.1.234' IDENTIFIED VIA ed25519 USING PASSWORD('secret')

GRANT ALL PRIVILEGES ON `AuthSrvrTemplate`.* TO 'auth_server_user'@'localhost';
GRANT ALL PRIVILEGES ON `AuthSrvrTemplate`.* TO 'auth_server_user'@'127.0.0.1';
GRANT ALL PRIVILEGES ON `AuthSrvrTemplate`.* TO 'auth_server_user'@'::1';
GRANT ALL PRIVILEGES ON `AuthSrvrTemplate`.* TO 'auth_server_user'@'192.168.2.%';

