local MageClass = class()
local CombatJob = require 'jobs.combat_job'
radiant.mixin(MageClass, CombatJob)
return MageClass