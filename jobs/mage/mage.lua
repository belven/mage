local MageClass = class()
local CombatJob = require 'jobs.combat_job'
radiant.mixin(MageClass, CombatJob)

--- Public functions, required for all classes

function MageClass:initialize()
   CombatJob.initialize(self)
   self._sv.max_num_attended_hearthlings = 2
end

--Always do these things
function MageClass:activate()
   CombatJob.activate(self)

   if self._sv.is_current_class then
      self:_register_with_town()
   end

   local cd = radiant.entities.get_entity_data(self._sv._entity, 'stonehearth:calories')
   self._famished_threshold = cd and cd.famished_threshold or stonehearth.constants.food.FAMISHED

   self.__saved_variables:mark_changed()
end

-- Call when it's time to promote someone to this class
function MageClass:promote(json_path)
   CombatJob.promote(self, json_path)
   self._sv.max_num_attended_hearthlings = self._job_json.initial_num_attended_hearthlings or 2
   if self._sv.max_num_attended_hearthlings > 0 then
      self:_register_with_town()
   end
   self.__saved_variables:mark_changed()
end

function MageClass:_register_with_town()
   local player_id = radiant.entities.get_player_id(self._sv._entity)
   local town = stonehearth.town:get_town(player_id)
   if town then
      town:add_medic(self._sv._entity, self._sv.max_num_attended_hearthlings)
   end
end

-- Called when destroying this entity, we should alo remove ourselves
function MageClass:_unregister_with_town()
   local player_id = radiant.entities.get_player_id(self._sv._entity)
   local town = stonehearth.town:get_town(player_id)
   if town then
      town:remove_medic(self._sv._entity)
   end
end

function MageClass:_create_listeners()
   CombatJob._create_listeners(self)
   self._on_heal_entity_listener = radiant.events.listen(self._sv._entity, 'stonehearth:healer:healed_entity', self, self._on_healed_entity)
   self._on_heal_entity_in_combat_listener = radiant.events.listen(self._sv._entity, 'stonehearth:healer:healed_entity_in_combat', self, self._on_healed_entity_in_combat)
   self._on_calories_changed_listener = radiant.events.listen(self._sv._entity, 'stonehearth:expendable_resource_changed:calories', self, self._on_calories_changed)
end

function MageClass:_remove_listeners()
   CombatJob._remove_listeners(self)
   if self._on_heal_entity_listener then
      self._on_heal_entity_listener:destroy()
      self._on_heal_entity_listener = nil
   end
   if self._on_heal_entity_in_combat_listener then
      self._on_heal_entity_in_combat_listener:destroy()
      self._on_heal_entity_in_combat_listener = nil
   end
   if self._on_calories_changed_listener then
      self._on_calories_changed_listener:destroy()
      self._on_calories_changed_listener = nil
   end
end

-- Mages have a habit of interrupting their meals to heal themselves for the damage they've taken for starving, ending up in a
-- loop where they never eat enough to not starve. To prevent awful loops, we hold their hunger at the minimum of famished. It's kind of
-- weird, but since they couldn't die from starving anyway this actually ends up being the least disruptive of their behavior.
function MageClass:_on_calories_changed()
   local consumption_component = self._sv._entity:get_component('stonehearth:consumption')
   local hunger_state = consumption_component:get_hunger_state()
   if hunger_state >= stonehearth.constants.hunger_levels.FAMISHED then
      local expendable_resource_component = self._sv._entity:get_component('stonehearth:expendable_resources')
      expendable_resource_component:set_value('calories', self._famished_threshold)
   end
end

function MageClass:_on_healed_entity(args)
   self:_add_exp('heal_entity')
end

function MageClass:_on_healed_entity_in_combat(args)
   self:_add_exp('heal_entity_in_combat')
end

-- Get xp reward using key. Xp rewards table specified in Mage description file
function MageClass:_add_exp(key)
   local exp = self._xp_rewards[key]
   if exp then
      self._job_component:add_exp(exp)
   end
end

-- Call when it's time to demote
function MageClass:demote()
   self:_unregister_with_town()
   CombatJob.demote(self)
end

-- Called when destroying this entity
-- Note we could get destroyed without being demoted
-- So remove ourselves from town just in case
function MageClass:destroy()
   if self._sv.is_current_class then
      self:_unregister_with_town()
   end

   CombatJob.destroy(self)
end

return MageClass