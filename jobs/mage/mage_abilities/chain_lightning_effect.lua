-- Aura buff generic class
-- Add this as the script to your buff if you want your buff
-- to periodically apply another buff to entities around it
local ChainLightning = class()

function ChainLightning:on_buff_added(entity, buff)
   local json = buff:get_json()
   self._tuning = json.script_info
   if not self._tuning or not self._tuning.aura_buff then
      return
   end
   local pulse_duration = self._tuning.pulse or "15m"
   self._entity = entity
   self._pulse_listener = stonehearth.calendar:set_interval("Aura Buff "..buff:get_uri().." pulse", pulse_duration, 
         function()
            self:_on_pulse()
         end)
   if self._tuning.pulse_immediately then
      self:_on_pulse()
   end
end

function ChainLightning:_on_pulse()
   local player_id = radiant.entities.get_player_id(self._entity)
   local num_affected = 0
   -- get everyone around us
   local aura_buff = self._tuning.aura_buff
   local sensor_name = self._tuning.sensor_name or 'sight'
   local sensor = self._entity:add_component('sensor_list'):get_sensor(sensor_name)
   local enemies_within_range = false
   local target_entities = {}
   for id, target in sensor:each_contents() do
      if id ~= self._entity:get_id() or self._tuning.affect_self then
         local target_player_id = radiant.entities.get_player_id(target)
         if stonehearth.player:are_player_ids_hostile(player_id, target_player_id) then
            local can_target = true
            -- If we can only target specific type of entity, make sure the entity's target_type matches
            if self._tuning.target_type then
               if radiant.entities.get_target_type(target) ~= self._tuning.target_type then
                  can_target = false
               end
            end
            if not self:_is_within_range(target) then
               can_target = false
            end

            if can_target then
               table.insert(target_entities, target)
            end
         elseif self._tuning.emit_if_enemies_nearby and not enemies_within_range and stonehearth.player:are_player_ids_hostile(player_id, target_player_id) then
            if self:_is_within_range(target) then
               enemies_within_range = true
            end
         end
      end
   end

   if self._tuning.emit_if_enemies_nearby and not enemies_within_range then
      return -- buff needs enemies to be nearby in order to emit the aura buff
   end

   for _, target in ipairs(target_entities) do
	   local resources = target:get_component('stonehearth:expendable_resources')
	   if not resources then
		  return
	   end
	   
       local health_change = self._tuning.health_change
	   if self._tuning.is_percentage then
		  health_change = resources:get_max_value('health') * health_change
	   end
	   
	   local current_health = resources:get_value('health')
	   local current_guts = resources:get_percentage('guts') or 1
	   if current_health <= 0 or current_guts < 1 then
		  return  -- don't beat a dead (or incapacitated) horse
	   end
	   
	radiant.entities.modify_health(target, health_change)
   end
end

function ChainLightning:_is_within_range(target)
   if self._tuning.radius then
      local distance = radiant.entities.distance_between_entities(self._entity, target)
      if not distance or distance > self._tuning.radius then
         return false
      end
   end
   return true
end

function ChainLightning:on_buff_removed(entity, buff)
   if self._pulse_listener then
      self._pulse_listener:destroy()
      self._pulse_listener = nil
   end
end

return ChainLightning
