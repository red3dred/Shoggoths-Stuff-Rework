function init()
	script.setUpdateDelta(5)

	self.tickDamagePercentage = 0.04
	self.tickTime = 1.0
	self.tickTimer = self.tickTime
end

function update(dt)
	self.tickTimer = self.tickTimer - dt
	if self.tickTimer <= 0 then
		self.tickTimer = self.tickTime
		status.applySelfDamageRequest({
			damageType = "IgnoresDef",
			damage = math.floor(status.resourceMax("health") * self.tickDamagePercentage) + 1,
			damageSourceKind = "poison",
			sourceEntityId = entity.id()
		})
	end
end

function uninit()

end
