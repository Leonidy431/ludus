--!strict
--[[
	UI.luau — Phase 1 dev-facing HUD.

	This is intentionally plain. It exists to prove the loop is playable
	end-to-end in Studio; the shipping UI is a separate art pass. Do not
	grow game logic here — it only renders Client.State and calls Client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local player = Players.LocalPlayer

local UI = {}
UI.__index = UI

local COLORS = {
	bg      = Color3.fromRGB(22, 24, 34),
	panel   = Color3.fromRGB(32, 35, 50),
	accent  = Color3.fromRGB(212, 175, 96),
	text    = Color3.fromRGB(232, 232, 240),
	muted   = Color3.fromRGB(150, 155, 175),
	good    = Color3.fromRGB(96, 200, 128),
	bad     = Color3.fromRGB(220, 96, 96),
}

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function button(parent: Instance, text: string, order: number, color: Color3?): TextButton
	local b = make("TextButton", {
		Text = text,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		BackgroundColor3 = color or COLORS.panel,
		TextColor3 = COLORS.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	return b
end

function UI.new(client)
	local self = setmetatable({}, UI)
	self.client = client
	self.targets = {}
	self:build()
	client.subscribe(function(state) self:render(state) end)
	client.onNotify(function(payload) self:toast(payload.text, payload.kind) end)
	client.onPvpResolved(function(payload)
		for _, record in ipairs(payload.records or {}) do
			local verb = record.won and "Defended against" or "Raided by"
			self:toast(("%s %s (%+d)"):format(verb, record.opponentName, record.ratingDelta),
				record.won and "good" or "bad")
		end
	end)
	return self
end

function UI:build()
	local gui = make("ScreenGui", {
		Name = "DeaconsPathHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local root = make("Frame", {
		Name = "Root",
		Size = UDim2.new(0, 320, 0, 520),
		Position = UDim2.new(0, 16, 0.5, -260),
		BackgroundColor3 = COLORS.bg,
		BorderSizePixel = 0,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, root)

	local header = make("TextLabel", {
		Text = Config.GameTitle,
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.new(0, 12, 0, 10),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, root)

	self.status = make("TextLabel", {
		Text = "Connecting…",
		Size = UDim2.new(1, -24, 0, 60),
		Position = UDim2.new(0, 12, 0, 42),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.text,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, root)

	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -180),
		Position = UDim2.new(0, 12, 0, 110),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, root)

	local layout = make("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	for _, region in ipairs(Config.Reports.Regions) do
		local btn = button(scroll, "Collect · " .. region, nextOrder())
		btn.Activated:Connect(function()
			self:call(self.client.collectReport, region)
		end)
	end

	local submit = button(scroll, "Submit Reports (bonus)", nextOrder(), COLORS.accent)
	submit.TextColor3 = COLORS.bg
	submit.Activated:Connect(function()
		self:call(self.client.submitReports)
	end)

	local roll1 = button(scroll, ("Fate Roll ×1 (%d)"):format(Config.Gacha.CostSingle), nextOrder())
	roll1.Activated:Connect(function()
		self:call(self.client.rollFate, 1)
	end)

	local roll10 = button(scroll, ("Fate Roll ×10 (%d)"):format(Config.Gacha.CostTen), nextOrder())
	roll10.Activated:Connect(function()
		self:call(self.client.rollFate, 10)
	end)

	self.targetFrame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, scroll)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, self.targetFrame)

	local scout = button(scroll, "Scout Caravans (Async PvP)", nextOrder(), COLORS.panel)
	scout.Activated:Connect(function()
		self:scout()
	end)

	self.toasts = make("Frame", {
		Size = UDim2.new(0, 300, 0, 200),
		Position = UDim2.new(1, -316, 0, 16),
		BackgroundTransparency = 1,
	}, gui)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top }, self.toasts)

	return gui
end

function UI:call(fn, ...)
	local result = fn(...)
	if type(result) == "table" and result.ok == false then
		self:toast(result.err or "Rejected.", "bad")
	end
	return result
end

function UI:toast(text: string, kind: string?)
	local color = COLORS.panel
	if kind == "good" or kind == "win" then
		color = COLORS.good
	elseif kind == "bad" or kind == "loss" then
		color = COLORS.bad
	end

	local frame = make("TextLabel", {
		Text = text,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = color,
		TextColor3 = COLORS.bg,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		BorderSizePixel = 0,
		LayoutOrder = os.clock() * 1000,
	}, self.toasts)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)

	task.delay(4, function()
		frame:Destroy()
	end)
end

function UI:scout()
	local result = self.client.listTargets()
	if type(result) ~= "table" or not result.ok then
		return
	end

	for _, child in ipairs(self.targetFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local targets = (result.res and result.res.targets) or {}
	if #targets == 0 then
		self:toast("No caravans in range. Publish your defense and wait.", "bad")
		return
	end

	for _, target in ipairs(targets) do
		local btn = button(self.targetFrame,
			("%s · %d · power %d"):format(target.displayName, target.rating, target.power),
			0)
		btn.Activated:Connect(function()
			self:call(self.client.attack, target.userId)
		end)
	end
end

function UI:render(state)
	if not state then
		self.status.Text = "Loading ledger…"
		return
	end

	self.status.Text = table.concat({
		("Deniers: %d   Aspri: %d   Laurels: %d"):format(
			state.wallet.deniers, state.wallet.aspri, state.wallet.laurels),
		("Energy: %d/%d  (missions left: %d)"):format(
			state.energy, state.maxEnergy, math.floor(state.energy / Config.Ludus.MissionEnergyCost)),
		("Relics: %d   Defenders: %d"):format(state.relicCount, #state.defenseTeam),
		("Rating: %d   W/L: %d/%d"):format(
			state.stats.pvpRating, state.stats.pvpWins, state.stats.pvpLosses),
		("Pity: %d since Epic · %d since Legendary"):format(
			state.pity.sinceEpic, state.pity.sinceLegendary),
	}, "\n")
end

return UI
