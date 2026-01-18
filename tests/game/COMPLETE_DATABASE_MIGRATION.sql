-- ============================================================================
-- TrinityCore Complete Database Schema Optimization
-- ============================================================================
-- This file contains ALL database schema changes for:
--   1. Player Entity Optimizations
--   2. Creature Entity Optimizations  
--   3. GameObject Entity Optimizations
--
-- CRITICAL: BACKUP YOUR DATABASE BEFORE RUNNING THIS!
--
-- Estimated execution time: 2-5 minutes (depends on data size)
-- Database compatibility: MySQL 5.7+, MariaDB 10.3+
-- ============================================================================

-- ============================================================================
-- SECTION 1: PLAYER ENTITY OPTIMIZATIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1: Add CASCADE DELETE to character-related tables
-- This eliminates N+1 query patterns during character deletion
-- ----------------------------------------------------------------------------

-- Character pets table
ALTER TABLE character_pet 
DROP FOREIGN KEY IF EXISTS fk_character_pet_owner;

ALTER TABLE character_pet
ADD CONSTRAINT fk_character_pet_owner 
FOREIGN KEY (owner) REFERENCES characters(guid) 
ON DELETE CASCADE;

-- Character items table
ALTER TABLE character_inventory
DROP FOREIGN KEY IF EXISTS fk_character_inventory_guid;

ALTER TABLE character_inventory
ADD CONSTRAINT fk_character_inventory_guid
FOREIGN KEY (guid) REFERENCES characters(guid)
ON DELETE CASCADE;

-- Character mail table
ALTER TABLE mail
DROP FOREIGN KEY IF EXISTS fk_mail_receiver;

ALTER TABLE mail
ADD CONSTRAINT fk_mail_receiver
FOREIGN KEY (receiver) REFERENCES characters(guid)
ON DELETE CASCADE;

-- Mail items table
ALTER TABLE mail_items
DROP FOREIGN KEY IF EXISTS fk_mail_items_mail;

ALTER TABLE mail_items
ADD CONSTRAINT fk_mail_items_mail
FOREIGN KEY (mail_id) REFERENCES mail(id)
ON DELETE CASCADE;

-- Character spells
ALTER TABLE character_spell
DROP FOREIGN KEY IF EXISTS fk_character_spell_guid;

ALTER TABLE character_spell
ADD CONSTRAINT fk_character_spell_guid
FOREIGN KEY (guid) REFERENCES characters(guid)
ON DELETE CASCADE;

-- Character achievements
ALTER TABLE character_achievement
DROP FOREIGN KEY IF EXISTS fk_character_achievement_guid;

ALTER TABLE character_achievement
ADD CONSTRAINT fk_character_achievement_guid
FOREIGN KEY (guid) REFERENCES characters(guid)
ON DELETE CASCADE;

-- Character reputation
ALTER TABLE character_reputation
DROP FOREIGN KEY IF EXISTS fk_character_reputation_guid;

ALTER TABLE character_reputation
ADD CONSTRAINT fk_character_reputation_guid
FOREIGN KEY (guid) REFERENCES characters(guid)
ON DELETE CASCADE;

-- Character quest status
ALTER TABLE character_queststatus
DROP FOREIGN KEY IF EXISTS fk_character_queststatus_guid;

ALTER TABLE character_queststatus
ADD CONSTRAINT fk_character_queststatus_guid
FOREIGN KEY (guid) REFERENCES characters(guid)
ON DELETE CASCADE;

-- Character social (friends list)
ALTER TABLE character_social
DROP FOREIGN KEY IF EXISTS fk_character_social_guid;

ALTER TABLE character_social
ADD CONSTRAINT fk_character_social_guid
FOREIGN KEY (guid) REFERENCES characters(guid)
ON DELETE CASCADE;

-- ----------------------------------------------------------------------------
-- 1.2: Add performance indexes for Player operations
-- ----------------------------------------------------------------------------

-- Index for pet deletion queries
CREATE INDEX IF NOT EXISTS idx_character_pet_owner_slot 
ON character_pet(owner, slot);

-- Index for item queries
CREATE INDEX IF NOT EXISTS idx_character_inventory_guid_bag 
ON character_inventory(guid, bag);

-- Index for mail queries
CREATE INDEX IF NOT EXISTS idx_mail_receiver_checked 
ON mail(receiver, checked);

-- Composite index for mail items
CREATE INDEX IF NOT EXISTS idx_mail_items_mail_item 
ON mail_items(mail_id, item_guid);

-- Index for spell lookups
CREATE INDEX IF NOT EXISTS idx_character_spell_guid_active 
ON character_spell(guid, active);

-- ----------------------------------------------------------------------------
-- 1.3: Add dirty flag tracking for item saves (optional but recommended)
-- ----------------------------------------------------------------------------

-- Add dirty flag column to items if not exists
ALTER TABLE item_instance 
ADD COLUMN IF NOT EXISTS is_dirty TINYINT(1) DEFAULT 1 AFTER itemEntry;

-- Index for dirty flag queries
CREATE INDEX IF NOT EXISTS idx_item_instance_owner_dirty 
ON item_instance(owner_guid, is_dirty);


-- ============================================================================
-- SECTION 2: CREATURE ENTITY OPTIMIZATIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1: Add indexes for creature queries
-- ----------------------------------------------------------------------------

-- Index for creature addon lookups
CREATE INDEX IF NOT EXISTS idx_creature_addon_guid 
ON creature_addon(guid);

-- Composite index for creature template addon
CREATE INDEX IF NOT EXISTS idx_creature_template_addon_entry 
ON creature_template_addon(entry);

-- Index for vehicle accessory lookups
CREATE INDEX IF NOT EXISTS idx_vehicle_accessory_guid 
ON vehicle_accessory(guid);

-- Index for linked respawn queries
CREATE INDEX IF NOT EXISTS idx_linked_respawn_guid 
ON linked_respawn(guid, linkedGuid);

-- ----------------------------------------------------------------------------
-- 2.2: Add creature state caching table (for combat optimizations)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS creature_combat_cache (
    guid INT UNSIGNED NOT NULL,
    threat_list_size SMALLINT UNSIGNED DEFAULT 0,
    last_combat_time INT UNSIGNED DEFAULT 0,
    PRIMARY KEY (guid),
    INDEX idx_combat_time (last_combat_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ============================================================================
-- SECTION 3: GAMEOBJECT ENTITY OPTIMIZATIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1: Add CASCADE DELETE to GameObject-related tables
-- This eliminates N+1 query patterns during GameObject deletion
-- ----------------------------------------------------------------------------

-- GameObject addons
ALTER TABLE gameobject_addon
DROP FOREIGN KEY IF EXISTS fk_gameobject_addon_guid;

ALTER TABLE gameobject_addon
ADD CONSTRAINT fk_gameobject_addon_guid
FOREIGN KEY (guid) REFERENCES gameobject(guid)
ON DELETE CASCADE;

-- ----------------------------------------------------------------------------
-- 3.2: Add indexes for GameObject operations
-- ----------------------------------------------------------------------------

-- Index for GameObject state queries
CREATE INDEX IF NOT EXISTS idx_gameobject_state_type 
ON gameobject(state, id);

-- Index for GameObject map queries
CREATE INDEX IF NOT EXISTS idx_gameobject_map_id 
ON gameobject(map, id);

-- Composite index for transport queries
CREATE INDEX IF NOT EXISTS idx_gameobject_id_map 
ON gameobject(id, map);

-- Index for GameObject addon lookups
CREATE INDEX IF NOT EXISTS idx_gameobject_addon_path 
ON gameobject_addon(guid, path_id);

-- ----------------------------------------------------------------------------
-- 3.3: Add per-player GameObject state tracking table
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS gameobject_player_state (
    guid INT UNSIGNED NOT NULL COMMENT 'GameObject GUID',
    player_guid INT UNSIGNED NOT NULL COMMENT 'Player GUID',
    state TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'GameObject state for this player',
    last_update INT UNSIGNED NOT NULL COMMENT 'Timestamp of last update',
    PRIMARY KEY (guid, player_guid),
    INDEX idx_player_state (player_guid, last_update),
    CONSTRAINT fk_go_player_state_go 
        FOREIGN KEY (guid) REFERENCES gameobject(guid) ON DELETE CASCADE,
    CONSTRAINT fk_go_player_state_player 
        FOREIGN KEY (player_guid) REFERENCES characters(guid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
COMMENT='Per-player GameObject state tracking';

-- ----------------------------------------------------------------------------
-- 3.4: Add GameObject loot tracking table (for concurrent loot fixes)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS gameobject_loot_tracking (
    guid INT UNSIGNED NOT NULL COMMENT 'GameObject GUID',
    player_guid INT UNSIGNED NOT NULL COMMENT 'Player GUID currently looting',
    loot_started INT UNSIGNED NOT NULL COMMENT 'Timestamp when loot started',
    PRIMARY KEY (guid),
    INDEX idx_loot_player (player_guid),
    INDEX idx_loot_timeout (loot_started)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
COMMENT='Tracks active GameObject looting to prevent race conditions';


-- ============================================================================
-- SECTION 4: OPTIMIZATION VERIFICATION QUERIES
-- ============================================================================

-- Run these queries after applying the schema changes to verify everything worked

-- Check foreign key constraints
SELECT 
    TABLE_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    DELETE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
  AND DELETE_RULE = 'CASCADE'
ORDER BY TABLE_NAME;

-- Check indexes
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columns
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND INDEX_NAME LIKE 'idx_%'
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME, INDEX_NAME;

-- Verify new tables exist
SELECT TABLE_NAME, TABLE_ROWS, 
       ROUND(DATA_LENGTH / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('creature_combat_cache', 'gameobject_player_state', 'gameobject_loot_tracking');


-- ============================================================================
-- SECTION 5: ROLLBACK SCRIPT (OPTIONAL - SAVE THIS SEPARATELY!)
-- ============================================================================
-- If you need to undo these changes, save the following to a separate file:
-- ROLLBACK_DATABASE_MIGRATION.sql
-- ============================================================================

/*
-- Remove CASCADE constraints (revert to default RESTRICT)
ALTER TABLE character_pet DROP FOREIGN KEY fk_character_pet_owner;
ALTER TABLE character_inventory DROP FOREIGN KEY fk_character_inventory_guid;
ALTER TABLE mail DROP FOREIGN KEY fk_mail_receiver;
ALTER TABLE mail_items DROP FOREIGN KEY fk_mail_items_mail;
ALTER TABLE character_spell DROP FOREIGN KEY fk_character_spell_guid;
ALTER TABLE character_achievement DROP FOREIGN KEY fk_character_achievement_guid;
ALTER TABLE character_reputation DROP FOREIGN KEY fk_character_reputation_guid;
ALTER TABLE character_queststatus DROP FOREIGN KEY fk_character_queststatus_guid;
ALTER TABLE character_social DROP FOREIGN KEY fk_character_social_guid;
ALTER TABLE gameobject_addon DROP FOREIGN KEY fk_gameobject_addon_guid;

-- Drop new tables
DROP TABLE IF EXISTS creature_combat_cache;
DROP TABLE IF EXISTS gameobject_player_state;
DROP TABLE IF EXISTS gameobject_loot_tracking;

-- Drop new indexes (examples - adjust based on what you added)
DROP INDEX IF EXISTS idx_character_pet_owner_slot ON character_pet;
DROP INDEX IF EXISTS idx_character_inventory_guid_bag ON character_inventory;
DROP INDEX IF EXISTS idx_mail_receiver_checked ON mail;
-- ... add other indexes to drop ...

-- Remove dirty flag column
ALTER TABLE item_instance DROP COLUMN IF EXISTS is_dirty;
*/

-- ============================================================================
-- END OF DATABASE MIGRATION
-- ============================================================================

-- Success! Database schema optimization complete.
-- Next steps:
--   1. Verify all constraints with the verification queries above
--   2. Test on a development environment first
--   3. Monitor database performance after deployment
--   4. Apply corresponding C++ code changes from optimization patches
-- ============================================================================
