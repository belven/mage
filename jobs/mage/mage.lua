local MageClass = class()

local CombatJob = radiant.mods.require 'stonehearth.jobs.combat_job'
radiant.mixin(MageClass, CombatJob)

return MageClass