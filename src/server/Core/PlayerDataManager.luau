local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local ProfileService = require(script.Parent:WaitForChild("ProfileService"))

local MAX_SLOTS = 10

local PROFILE_TEMPLATE = {
	ActiveSlotId = nil,
	Slots = {},
}

local ProfileStore = ProfileService.GetProfileStore(
	"WhishGo_MultiSlot_v10",
	PROFILE_TEMPLATE
)

local Profiles = {}

local PlayerDataManager = Knit.CreateService({
	Name = "PlayerDataManager",
	Client = {},
})

function PlayerDataManager:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		local profileKey = "Player_" .. player.UserId
		local profile = ProfileStore:LoadProfileAsync(profileKey)

		if profile ~= nil then
			profile:AddUserId(player.UserId)
			profile:Reconcile()

			profile:ListenToRelease(function()
				Profiles[player] = nil
				player:Kick("Tu sesión se ha cargado en otro servidor.")
			end)

			if player:IsDescendantOf(Players) then
				Profiles[player] = profile
				print(`[PlayerDataManager] Perfil multiranura cargado para {player.Name}`)
			else
				profile:Release()
			end
		else
			player:Kick("No se pudieron cargar tus datos de juego. Reintenta ingresar.")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles[player]
		if profile ~= nil then
			profile:Release()
		end
	end)
end

function PlayerDataManager:WaitForProfile(player: Player)
	local profile = Profiles[player]
	if profile then return profile end

	local timeWaited = 0
	while not Profiles[player] and player.Parent and timeWaited < 10 do
		task.wait(0.1)
		timeWaited += 0.1
	end

	return Profiles[player]
end

function PlayerDataManager:GetSlots(player: Player)
	local profile = self:WaitForProfile(player)
	return profile and profile.Data.Slots or {}
end

function PlayerDataManager:CreateCharacterSlot(player: Player, className: string, subtype: string?, charName: string, personalityKey: string?)
	local profile = self:WaitForProfile(player)
	if not profile then return nil end

	if #profile.Data.Slots >= MAX_SLOTS then
		warn(`[PlayerDataManager] {player.Name} alcanzó el límite máximo de ranuras.`)
		return nil
	end

	local newSlot = {
		Id = "char_" .. HttpService:GenerateGUID(false),
		Name = if charName ~= "" then charName else "Héroe",
		Class = className,
		Subtype = subtype or "",
		Personality = personalityKey or "Heroic",
		Level = 1,
		XP = 0,
		EvolutionPoints = 0,
		Radiation = 100,
		MaxRadiation = 100,
		RadiationRegenRate = 2,
		Gold = 0,
		Inventory = {},
		CreatedAt = os.time(),
		Quests = {
			Active = {},
			Completed = {},
		},
	}

	table.insert(profile.Data.Slots, newSlot)
	profile.Data.ActiveSlotId = newSlot.Id

	-- Aplicar atributos inmediatamente tras la creación
	self:ApplyPlayerAttributes(player, newSlot)

	print(`[PlayerDataManager] Nueva ranura creada: '{newSlot.Name}' ({className})`)
	return newSlot
end

function PlayerDataManager:SelectSlot(player: Player, slotId: string)
	local profile = self:WaitForProfile(player)
	if not profile then return nil end

	for _, slot in ipairs(profile.Data.Slots) do
		if slot.Id == slotId then
			profile.Data.ActiveSlotId = slotId
			print(`[PlayerDataManager] {player.Name} seleccionó la ranura '{slot.Name}'`)

			-- Aplicar los atributos del personaje en la instancia de Player
			self:ApplyPlayerAttributes(player, slot)
			return slot
		end
	end
	return nil
end

function PlayerDataManager:GetActiveSlot(player: Player)
	local profile = self:WaitForProfile(player)
	if not profile or not profile.Data.ActiveSlotId then return nil end

	for _, slot in ipairs(profile.Data.Slots) do
		if slot.Id == profile.Data.ActiveSlotId then
			-- Parche defensivo de migración para slots antiguos
			slot.XP = slot.XP or 0
			slot.Gold = slot.Gold or 0
			slot.Personality = slot.Personality or "Heroic"
			slot.EvolutionPoints = slot.EvolutionPoints or 0
			slot.Radiation = slot.Radiation or 100
			slot.MaxRadiation = slot.MaxRadiation or 100
			slot.RadiationRegenRate = slot.RadiationRegenRate or 2

			-- Asegurar tabla Quests en slots antiguos
			slot.Quests = slot.Quests or { Active = {}, Completed = {} }
			slot.Quests.Active = slot.Quests.Active or {}
			slot.Quests.Completed = slot.Quests.Completed or {}
			return slot
		end
	end
	return nil
end

function PlayerDataManager:GetProfile(player: Player)
	return self:WaitForProfile(player)
end

function PlayerDataManager:ApplyPlayerAttributes(player: Player, slotData: table)
	if not player or not slotData then return end

	local level = slotData.Level or 1
	local ProgressionService = Knit.GetService("ProgressionService")
	local maxXP = if ProgressionService then ProgressionService:GetRequiredXP(level) else math.floor(100 * (math.max(1, level) ^ 1.5))
	slotData.MaxXP = maxXP

	-- Atributos de Experiencia y Nivel
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", slotData.XP or 0)
	player:SetAttribute("MaxXP", maxXP)

	-- Atributos de Economía y Personalidad
	player:SetAttribute("Gold", slotData.Gold or 0)
	player:SetAttribute("Personality", slotData.Personality or "Heroic")

	-- Atributos de Radiación
	player:SetAttribute("Radiation", slotData.Radiation or 0)
	player:SetAttribute("MaxRadiation", slotData.MaxRadiation or 100)
end

function PlayerDataManager:AddXP(player: Player, amount: number)
	local ProgressionService = Knit.GetService("ProgressionService")
	if ProgressionService then
		ProgressionService:AddXP(player, amount)
	end
end

function PlayerDataManager:SetRadiation(player: Player, amount: number)
	local slot = self:GetActiveSlot(player)
	if not slot then return end

	local maxRad = slot.MaxRadiation or 100
	slot.Radiation = math.clamp(amount, 0, maxRad)
	player:SetAttribute("Radiation", slot.Radiation)
end

function PlayerDataManager:AddItemToActiveSlot(player: Player, itemId: string)
	local activeSlot = self:GetActiveSlot(player)
	if activeSlot then
		if not activeSlot.Inventory then
			activeSlot.Inventory = {}
		end
		table.insert(activeSlot.Inventory, itemId)
		return true
	end
	return false
end

function PlayerDataManager:MoveItemSlot(player: Player, fromSlot: number, toSlot: number)
	local activeSlot = self:GetActiveSlot(player)
	if not activeSlot or not activeSlot.Inventory then return false end

	local itemAtFrom = activeSlot.Inventory[tostring(fromSlot)] or activeSlot.Inventory[fromSlot]
	local itemAtTo = activeSlot.Inventory[tostring(toSlot)] or activeSlot.Inventory[toSlot]

	activeSlot.Inventory[tostring(toSlot)] = itemAtFrom
	activeSlot.Inventory[tostring(fromSlot)] = itemAtTo

	return true
end

return PlayerDataManager
