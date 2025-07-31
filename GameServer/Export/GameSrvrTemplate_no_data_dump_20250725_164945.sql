/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.11.13-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: GameSrvrTemplate
-- ------------------------------------------------------
-- Server version	10.11.13-MariaDB-0ubuntu0.24.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `GameSrvrTemplate`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `GameSrvrTemplate` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;

USE `GameSrvrTemplate`;

--
-- Table structure for table `builds`
--

DROP TABLE IF EXISTS `builds`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `builds` (
  `id` tinyint(3) unsigned NOT NULL,
  `plyr_id` int(10) unsigned NOT NULL,
  `slot_id` tinyint(3) unsigned NOT NULL,
  `item_id` bigint(20) unsigned NOT NULL,
  UNIQUE KEY `builds_unique` (`id`,`plyr_id`,`slot_id`),
  KEY `builds_player_FK` (`plyr_id`),
  KEY `builds_item_FK` (`item_id`),
  CONSTRAINT `builds_item_FK` FOREIGN KEY (`item_id`) REFERENCES `item` (`id`),
  CONSTRAINT `builds_player_FK` FOREIGN KEY (`plyr_id`) REFERENCES `player` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `inventory`
--

DROP TABLE IF EXISTS `inventory`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `inventory` (
  `plyr_id` int(10) unsigned NOT NULL,
  `slot_id` smallint(5) unsigned NOT NULL,
  `qty` bigint(20) DEFAULT 0,
  UNIQUE KEY `inventory_unique` (`plyr_id`,`slot_id`),
  CONSTRAINT `inventory_player_FK` FOREIGN KEY (`plyr_id`) REFERENCES `player` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `item`
--

DROP TABLE IF EXISTS `item`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `item` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `ref_id` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `item_ref_id_FK` (`ref_id`),
  CONSTRAINT `item_ref_id_FK` FOREIGN KEY (`ref_id`) REFERENCES `ref_id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `item_stats`
--

DROP TABLE IF EXISTS `item_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `item_stats` (
  `item_id` bigint(20) unsigned NOT NULL,
  `stat_id` tinyint(3) unsigned NOT NULL,
  `value` decimal(8,4) NOT NULL,
  KEY `item_stats_item_FK` (`item_id`),
  KEY `item_stats_stats_FK` (`stat_id`),
  CONSTRAINT `item_stats_item_FK` FOREIGN KEY (`item_id`) REFERENCES `item` (`id`),
  CONSTRAINT `item_stats_stats_FK` FOREIGN KEY (`stat_id`) REFERENCES `stats` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `msg_blocks`
--

DROP TABLE IF EXISTS `msg_blocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `msg_blocks` (
  `plyr_id` int(10) unsigned NOT NULL,
  `blocked_plyr_id` int(10) unsigned NOT NULL,
  PRIMARY KEY (`plyr_id`,`blocked_plyr_id`),
  KEY `msg_blocks_player_blocked_id_FK` (`blocked_plyr_id`),
  CONSTRAINT `msg_blocks_player_blocked_id_FK` FOREIGN KEY (`blocked_plyr_id`) REFERENCES `player` (`id`),
  CONSTRAINT `msg_blocks_player_id_FK` FOREIGN KEY (`plyr_id`) REFERENCES `player` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `player`
--

DROP TABLE IF EXISTS `player`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `player` (
  `id` int(10) unsigned NOT NULL,
  `status` tinyint(3) unsigned DEFAULT 0,
  `display_name` varchar(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `player_display_name_unique` (`display_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ref_id`
--

DROP TABLE IF EXISTS `ref_id`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ref_id` (
  `id` smallint(5) unsigned NOT NULL,
  `short_desc` varchar(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ref_id_unique` (`short_desc`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stats`
--

DROP TABLE IF EXISTS `stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `stats` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `short_desc` varchar(64) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `stats_unique` (`short_desc`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-07-25 16:49:50
