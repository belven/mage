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

function ChainLightning:_find_hostiles_around_target(target)
  local target_entities = {}
  local actual_target  = self._entity
  local sensor_name = self._tuning.sensor_name or 'sight'
  local player_id = radiant.entities.get_player_id(self._entity)

  if target ~= nil then
    actual_target = target
  end

  -- get everyone around us
  local sensor = actual_target:add_component('sensor_list'):get_sensor(sensor_name)

  for id, target in sensor:each_contents() do
    local target_player_id = radiant.entities.get_player_id(target)
    if stonehearth.player:are_player_ids_hostile(player_id, target_player_id) then
      -- If we can only target specific type of entity, make sure the entity's target_type matches
      if  self:_is_within_range(target) then
        table.insert(target_entities, target)
      end
    end
  end
  return target_entities
end

function ChainLightning:_on_pulse()
  local target_entities = {}
  local actualTarget = nil

  -- Get all nearby enemies
  target_entities = self:_find_hostiles_around_target(nil)

  -- Check if we found something
  for _, target in ipairs(target_entities) do
    -- Get the first entity found and target it
    actualTarget = target
    break
  end

  -- actualTarget could be nil if the loop didn't find anything
  if actualTarget == nil then
    return
  end      

  -- Check for enemies around our new target, as the lightning will originate from them
  for _, target in ipairs(self:_find_hostiles_around_target(actualTarget)) do
    -- Deal the damage to the targets
    self:_modify_health(target)
  end
end

function ChainLightning:_modify_health(target)
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
