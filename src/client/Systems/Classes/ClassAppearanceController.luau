local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local sharedClasses = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Systems"):WaitForChild("Classes")
local PersonalityData = require(sharedClasses:WaitForChild("PersonalityData"))

local ClassAppearanceController = Knit.CreateController({
	Name = "ClassAppearanceController",
})

function ClassAppearanceController:KnitStart()
	-- Inicialización de eventos visuales locales si es necesario
end

-- Método para previsualizar una personalidad en un Dummy o Viewport (UI)
function ClassAppearanceController:PreviewPersonalityOnModel(model: Model, personalityKey: string): AnimationTrack?
	local personalityConfig = PersonalityData.Personalities[personalityKey]
	if not personalityConfig then return nil end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	-- Detener animaciones previas del preview
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	local idleAnimId = personalityConfig.Animations.Idle
	if idleAnimId and idleAnimId ~= "rbxassetid://0" then
		local anim = Instance.new("Animation")
		anim.AnimationId = idleAnimId
		
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Idle
		track.Looped = true
		track:Play()
		return track
	end

	return nil
end

return ClassAppearanceController