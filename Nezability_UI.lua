local A = Apollo.GetAddon("Nezability")

local ClassIcons = {
	"IconSprites:Icon_Windows_UI_CRB_Warrior",
	"IconSprites:Icon_Windows_UI_CRB_Engineer",
	"IconSprites:Icon_Windows_UI_CRB_Esper",
	"IconSprites:Icon_Windows_UI_CRB_Medic",
	"IconSprites:Icon_Windows_UI_CRB_Stalker",
	"",
	"IconSprites:Icon_Windows_UI_CRB_Spellslinger"
}

local ViewModeIcons = {
	"CRB_Basekit:kitAccent_Difficulty_High",
	"CRB_Basekit:kitAccent_Difficulty_Medium",
	"CRB_Basekit:kitAccent_Difficulty_Low"
}

function A:InitWindow()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		self.wndMain = Apollo.LoadForm(A.xmlDoc, "NezabilityForm", nil, A)
	
		self.wndMain:FindChild("BG"):SetOpacity(0.8)
		self.wndMain:FindChild("Header"):SetOpacity(0.6)
		self.wndMain:FindChild("Footer"):SetOpacity(0.6)
		
		self.moving = false
		self.mouseOffsetX = 0
		self.mouseOffsetY = 0
		self.windowOffsetX = 0
		self.windowOffsetY = 0
		
		self.rows = {}

		self.wndMain:Show(false, true)
	end
end

function A:UpdateUI()
	self:UpdateRows()
	
	for i, name, color in self:GroupTableIterator() do
		debugprint("Updating slot for " .. name)
		self:LoadPlayer(i, name, color)
	end
end

function A:GroupTableIterator()
	local IAValues = {}
	
	for name, player in pairs(self.group) do
		local cooldown = 100
		local color = CColor.new(0, 1, 0) -- Default Green
		
		--Basic weight based on IA/CD
		if tablelength(player.spells) ~= 0 and player.totalIA ~= nil then
			for _, spell in ipairs(player.spells) do
				if spell.cd < cooldown then
					cooldown = spell.cd
				end
			end
			cooldown = math.floor(cooldown) + (5 - player.totalIA) * 100
			--If interrupts are all used
			if player.totalIA == 0 then
				color = CColor.new(1, 0, 0)
			end
		end
		
		--Everyone with the addon but no current interrupts below that
		if tablelength(player.spells) == 0 and player.totalIA and player.totalIA == 0 then
			cooldown = 3000
			color = CColor.new(0, 1, 1)
		end
		
		--Everyone Dead below that
		if not IsAlive(name) then
			cooldown = 4000
			color = CColor.new(0.402, 0, 0)
		end
		
		--Everyone offline below that
		if not IsOnline(name) then
			cooldown = 5000
			color = CColor.new(0.5, 0.5, 0.5)
		end
		
		--Everyone who doesnt have the addon below that
		if not player.totalIA then
			cooldown = 6000
			color = CColor.new(1, 1, 1)
		end
		
		--Add to sort table
		IAValues[#IAValues + 1] = {}
		IAValues[#IAValues][1] = cooldown
		IAValues[#IAValues][2] = name
		IAValues[#IAValues][3] = color	
	end
	
	table.sort(IAValues, function(a,b) return a[1] < b[1] end)
	
	local i = 0
	return function()
		i = i + 1
		if IAValues[i] then
			return i, IAValues[i][2], IAValues[i][3]
		end
	end
end

function A:OnHeaderMouseButtonDown(wndHandler, wndController, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Left and not self.settings.windowLocked then
		self.moving = true
		
		local mouse = Apollo.GetMouse()
		local anchors = {self.wndMain:GetAnchorOffsets()}
		
		self.mouseOffsetX = mouse.x
		self.mouseOffsetY = mouse.y
		
		self.windowOffsetX = anchors[1]
		self.windowOffsetY = anchors[2]
	end
end

function A:OnHeaderMouseButtonUp()
	self.moving = false
end

function A:OnHeaderMouseMove()
	if self.moving then
		local mouse = Apollo.GetMouse()
		local anchors = {self.wndMain:GetAnchorOffsets()}
		local x = mouse.x - self.mouseOffsetX + self.windowOffsetX
		local y = mouse.y - self.mouseOffsetY + self.windowOffsetY
		
		self.wndMain:SetAnchorOffsets(x, y, x + anchors[3] - anchors[1], y + anchors[4] - anchors[2])
	end
end

--Thanks to NexusMeter/OdysseyMeter for this wonderful hack
function A:OnWindowSizeChanged(wndHandler, wndControl)
	if wndHandler == wndControl then
		local mouse = Apollo.GetMouse()
		local anchors = {self.wndMain:GetAnchorOffsets()}
		
		local hfoffset = self.wndMain:FindChild("Header"):GetHeight() + self.wndMain:FindChild("Footer"):GetHeight()
		local rows = round((mouse.y - anchors[2] - hfoffset) / self.settings.rowHeight)
		if rows <= 0 then rows = 1 end
		
		--Make sure we are resizing in the footer and not dragging the header
		if mouse.y < anchors[2] + self.wndMain:FindChild("Header"):GetHeight() then return end
		
		--Need to do this or we get too many events
		self.wndMain:RemoveEventHandler("WindowSizeChanged")
		
		--Snap to position
		local right = anchors[3]
		if math.abs(right - anchors[1]) < 200 then
			right = anchors[1] + 200
		end
		
		self.wndMain:SetAnchorOffsets(anchors[1], anchors[2], right, anchors[2] + hfoffset - 1 + rows * self.settings.rowHeight)
		
		self.wndMain:AddEventHandler("WindowSizeChanged", "OnWindowSizeChanged", self)
		
		self.settings.viewRowCount = rows
	end
end

function A:OnResizeRight()
	
end

function A:OnCloseWindowButton()
	self.wndMain:Show(false)
end

function A:OnLockWindowButton()
	if self.settings.windowLocked then
		self.settings.windowLocked = false
		self.wndMain:FindChild("Header"):FindChild("LockButton"):SetSprite("CRB_Basekit:kitIcon_Holo_Lock")
		self.wndMain:SetStyle("Sizable", true)
	else
		self.settings.windowLocked = true
		self.wndMain:FindChild("Header"):FindChild("LockButton"):SetSprite("CRB_Basekit:kitIcon_Holo_LockDisabled")
		self.wndMain:SetStyle("Sizable", false)
	end
end

function A:AddRow()
	if not self.rows then
		self.rows = {}
	end
	
	local i = #self.rows + 1
	debugprint("Adding row index " .. i)
	
	local rowView = self.wndMain:FindChild("RowView")
	self.rows[i] = Apollo.LoadForm(self.xmlDoc, "Row", rowView, self)
	self.rows[i]:SetAnchorOffsets(0, (i - 1) * self.settings.rowHeight, 0, i * self.settings.rowHeight)
end

function A:RemoveRow()
	if not self.rows or #self.rows < 1 then return end
	self.rows[#self.rows]:Show(false)
	self.rows[#self.rows] = nil
	debugprint("Removing row index " .. #self.rows)
end

function A:UpdateRows()
	debugprint(tablelength(self.group) .. " group members, " .. #self.rows .. " rows")

	while tablelength(self.group) < #self.rows do
		self:RemoveRow()
	end
	
	while tablelength(self.group) > #self.rows do
		self:AddRow()
	end
end

function A:ClearRows()
	while #self.rows > 0 do
		self:RemoveRow()
	end
end

function A:LoadPlayer(rowIndex, name, color)
	local player = self.group[name]

	local uiname = self.rows[rowIndex]:FindChild("Name")
	uiname:SetText(name)
	uiname:SetTextColor(color)

	self.rows[rowIndex]:FindChild("ClassIcon"):SetSprite(ClassIcons[player.classId])
	
	local uitotal = self.rows[rowIndex]:FindChild("Total")
	uitotal:SetText(player.totalIA)
	uitotal:SetTextColor(color)
	
	for i = 1, 3, 1 do
		local icon = self.rows[rowIndex]:FindChild("Spell" .. i)
		
		icon:SetSprite(nil)
		icon:SetText("")

		if player.spells[i] then
			icon:SetSprite(self.interruptDb[player.classId][player.spells[i].id].sprite)
			
			if player.spells[i].cd > 0 then
				icon:SetBGColor(CColor.new(0.2, 0.2, 0.2))
				icon:SetText(math.floor(player.spells[i].cd) .. "s")
			else
				icon:SetBGColor(CColor.new(1, 1, 1))
			end
		end
	end
end

function A:ChangeViewMode()
	if self.settings.viewMode == 3 then
		self.settings.viewMode = 1
	else
		self.settings.viewMode = A.settings.viewMode + 1
	end
	
	self.wndMain:FindChild("Header"):FindChild("ModeButton"):SetSprite(ViewModeIcons[A.settings.viewMode])
	
	if self.settings.viewMode == 1 then
		self.wndMain:FindChild("Header"):SetText("       All Party Interrupts")
	elseif self.settings.viewMode == 2 then
		self.wndMain:FindChild("Header"):SetText("       Raid Interrupts By Group (TBI)")
	else
		self.wndMain:FindChild("Header"):SetText("       Current Interrupt Group (TBI)")
	end
end

function A:OnOK()
	self.wndMain:Close() -- hide the window
end

function A:OnCancel()
	self.wndMain:Close() -- hide the window
end

function round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

function tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end