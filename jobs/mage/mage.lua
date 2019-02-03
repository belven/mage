local MageClass = class()

local CombatJob = radiant.mods.require 'stonehearth.jobs.combat_job'
local BaseJob = require 'stonehearth.jobs.base_job'
radiant.mixin(MageClass, CombatJob)
radiant.mixin(MageClass, BaseJob)

return MageClass