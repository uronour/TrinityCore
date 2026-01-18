-- ============================================================================
-- TrinityCore Database Optimization - ROLLBACK SCRIPT
-- ============================================================================
-- Use this script to undo all database schema changes if needed
--
-- WARNING: This will remove CASCADE constraints and new tables
-- Make sure you have a backup before running this!
-- ============================================================================

-- ============================================================================
-- SECTION 1: Remove Player Entity CASCADE Constraints
-- ============================================================================

-- Character pets - remove CASCADE, revert to default (RESTRICT)
ALTER TABLE character_pet 
DROP FOREIGN KEY IF EXISTS fk_character_pet_owner;

-- Optionally re-add without CASCADE (if original had FK)
-- ALTER TABLE character_pet
-- ADD CONSTRAINT fk_character_pet_owner 
-- FOREIGN KEY (owner) REFERENCES characters(guid);

-- Character inventory
ALTER TABLE character_inventory
DROP FOREIGN KEY IF EXISTS fk_character_inventory_guid;

-- Mail table
ALTER TABLE mail
DROP FOREIGN KEY IF EXISTS fk_mail_receiver;

-- Mail items
ALTER TABLE mail_items
DROP FOREIGN KEY IF EXISTS fk_mail_items_mail;

-- Character spells
ALTER TABLE character_spell
DROP FOREIGN KEY IF EXISTS fk_character_spell_guid;

-- Character achievements
ALTER TABLE character_achievement
DROP FOREIGN KEY IF EXISTS fk_character_achievement_guid;

-- Character reputation
ALTER TABLE character_reputation
DROP FOREIGN KEY IF EXISTS fk_character_reputation_guid;

-- Character quest status
ALTER TABLE character_queststatus
DROP FOREIGN KEY IF EXISTS fk_character_queststatus_guid;

-- Character social
ALTER TABLE character_social
DROP FOREIGN KEY IF EXISTS fk_character_social_guid;

-- ============================================================================
-- SECTION 2: Remove GameObject CASCADE Constraints
-- ============================================================================

-- GameObject addons
ALTER TABLE gameobject_addon
DROP FOREIGN KEY IF EXISTS fk_gameobject_addon_guid;

-- ============================================================================
-- SECTION 3: Drop New Tables
-- ============================================================================

DROP TABLE IF EXISTS creature_combat_cache;
DROP TABLE IF EXISTS gameobject_player_state;
DROP TABLE IF EXISTS gameobject_loot_tracking;

-- ============================================================================
-- SECTION 4: Drop Performance Indexes (Player)
-- ============================================================================

-- Pet indexes
DROP INDEX IF EXISTS idx_character_pet_owner_slot ON character_pet;

-- Inventory indexes
DROP INDEX IF EXISTS idx_character_inventory_guid_bag ON character_inventory;

-- Mail indexes
DROP INDEX IF EXISTS idx_mail_receiver_checked ON mail;
DROP INDEX IF EXISTS idx_mail_items_mail_item ON mail_items;

-- Spell indexes
DROP INDEX IF EXISTS idx_character_spell_guid_active ON character_spell;

-- Item dirty flag
ALTER TABLE item_instance DROP COLUMN IF EXISTS is_dirty;
DROP INDEX IF EXISTS idx_item_instance_owner_dirty ON item_instance;

-- ============================================================================
-- SECTION 5: Drop Performance Indexes (Creature)
-- ============================================================================

DROP INDEX IF EXISTS idx_creature_addon_guid ON creature_addon;
DROP INDEX IF EXISTS idx_creature_template_addon_entry ON creature_template_addon;
DROP INDEX IF EXISTS idx_vehicle_accessory_guid ON vehicle_accessory;
DROP INDEX IF EXISTS idx_linked_respawn_guid ON linked_respawn;

-- ============================================================================
-- SECTION 6: Drop Performance Indexes (GameObject)
-- ============================================================================

DROP INDEX IF EXISTS idx_gameobject_state_type ON gameobject;
DROP INDEX IF EXISTS idx_gameobject_map_id ON gameobject;
DROP INDEX IF EXISTS idx_gameobject_id_map ON gameobject;
DROP INDEX IF EXISTS idx_gameobject_addon_path ON gameobject_addon;

-- ============================================================================
-- SECTION 7: Verification
-- ============================================================================

-- Verify CASCADE constraints are removed
SELECT 
    TABLE_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    DELETE_RULE
FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
  AND DELETE_RULE = 'CASCADE'
ORDER BY TABLE_NAME;

-- Should return 0 rows if rollback was successful

-- Verify new tables are removed
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
      'creature_combat_cache',
      'gameobject_player_state', 
      'gameobject_loot_tracking'
  );

-- Should return 0 rows if rollback was successful

-- ============================================================================
-- END OF ROLLBACK SCRIPT
-- ============================================================================

SELECT 'Rollback completed successfully!' AS Status;

-- Note: This rollback removes optimizations but does NOT restore original
-- constraints or indexes that may have existed before. 
-- 
-- If you need to fully restore, use your database backup:
-- mysql -u trinity -p characters < characters_backup.sql
-- ============================================================================
