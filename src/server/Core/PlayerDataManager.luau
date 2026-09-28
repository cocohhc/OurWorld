local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local ProfileService = require(script.Parent:WaitForChild("ProfileService"))

local MAX_SLOTS = 4

local PROFILE_TEMPLATE = {
	ActiveSlotId = nil,
	Slots = {},
}

local ProfileStore = ProfileService.GetProfileStore(
	"WhishGo_MultiSlot_v2",
	PROFILE_TEMPLATE
)

local Profiles = {}

-- 🚀 CONVERTIDO A SERVICIO DE KNIT PARA QUE Knit.GetService LO RECONOZCA
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

function PlayerDataManager:CreateCharacterSlot(player: Player, className: string, subtype: string?, charName: string)
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
		Level = 1,
		Gold = 0,
		Inventory = {},
		CreatedAt = os.time(),
	}

	table.insert(profile.Data.Slots, newSlot)
	profile.Data.ActiveSlotId = newSlot.Id
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
			return slot
		end
	end
	return nil
end

-- 🚀 Método requerido por InventoryService para guardar ítems en la ranura activa
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

-- En PlayerDataManager.luau:
function PlayerDataManager:MoveItemSlot(player: Player, fromSlot: number, toSlot: number)
	local activeSlot = self:GetActiveSlot(player)
	if not activeSlot or not activeSlot.Inventory then return false end

	-- Intercambiar o mover los ítems entre las casillas especificadas
	local itemAtFrom = activeSlot.Inventory[tostring(fromSlot)] or activeSlot.Inventory[fromSlot]
	local itemAtTo = activeSlot.Inventory[tostring(toSlot)] or activeSlot.Inventory[toSlot]

	activeSlot.Inventory[tostring(toSlot)] = itemAtFrom
	activeSlot.Inventory[tostring(fromSlot)] = itemAtTo

	return true
end

return PlayerDataManager