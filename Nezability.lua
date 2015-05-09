-----------------------------------------------------------------------------------------------
-- Client Lua Script for Nezability
-- Copyright (c) NCsoft. All rights reserved	
-- CREATED BY: Nezha, Using Accountability by Allie, DoctorHouse
-----------------------------------------------------------------------------------------------

require "Window"
require "ICCommLib"
 
-----------------------------------------------------------------------------------------------
-- Nezability Module Definition
-----------------------------------------------------------------------------------------------
local Nezability = {}

local ITMsg = {
	Join = 1,
	Update = 2,
	Left = 3
}

--Debugging
local NezabilityDebug = false

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Nezability:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.savedSettings = nil
	o.settings = {
		cdbar = false,
		viewMode = 1,
		rowHeight = 25,
		viewRowCount = 5,
		windowAnchors = {},
		windowLocked = false
	}

	o.group = {}            --Keep track of the group's interrupt
	o.myInterrupts = {}     --Keep track of your own interrupts
	o.partyLeader = nil     --Used for creating unique channels 
	o.channel = nil         --Current group channel, nil if not in a group
	o.inChannel = false     --Flag for tracking channel connection status
	o.message = nil         --Most recent message recieved
	o.classId = 0           --User's class ID
	o.playername = ""       --User's in-game name
	o.player = nil          --User's Player object
	o.onCooldown = false    --Used for tracking interrupt status
	o.onGroupStatus = false --Used for checking group offline/death status
	o.onLASUpdate = false   --Required to properly track LAS updates:
							--The AbilityBookChange event fires BEFORE the LAS changes internally.
							--This flag is set by the event, causing a timer to update myInterrupts
							--AFTER the LAS has been changed internally. If carbine fixes this event,
							--this will no longer be required.
	o.redrawUI = false
	o.uiSlots = {}		    --For updating the UI easily
	o.wmr = false		    --Required due to Carbine event oddities
	o.anchors = {nil}
	
	--Every interrupt in the game, minus bruiser bot (because it sucks)
	--TODO: Write special code for handling Grapple
	o.interruptDb = {  
		-- Warrior
		{
			[18363] = {
				name = "Grapple",
				sprite = "Icon_SkillPhysical_UI_wr_whip",
				iaTiers = {
					1, 1, 1, 1, 2, 2, 2, 2, 2
				}
			},
			
			[18547] = {
				name = "Flash Bang",
				sprite = "Icon_SkillPhysical_UI_wr_grenade",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 1
				}	
			},
			
			[38017] = {
				name = "Kick",
				sprite = "Icon_SkillPhysical_UI_wr_punt",
				iaTiers = {
					1, 1, 1, 1, 2, 2, 2, 2, 2
				}
			},
		},
		
		-- Engineer
		{
			[25635] = {
				name = "Zap",
				sprite = "ClientSprites:Icon_SkillEngineer_Zap",
				iaTiers = {
					1, 1, 1, 1, 2, 2, 2, 2, 2
				}
			},
			
			[34176] = {
				name = "Obstruct Vision",
				sprite = "ClientSprites:Icon_SkillEngineer_Shock_Wave",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 1
				}
			},
		},
		
		-- Esper
		{
			[19022] = {
				name = "Crush",
				sprite = "Icon_SkillMind_UI_espr_crush",
				iaTiers = {
					1, 1, 1, 1, 2, 2, 2, 2, 2
				}
			},
			
			[19355] = {
				name = "Incapacitate",
				sprite = "ClientSprites:Icon_SkillEsper_Sudden_Quiet",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 1
				}
			},
			
			[19029] = {
				name = "Shockwave",
				sprite = "Icon_SkillMind_UI_espr_shockwave",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 1
				}
			},
		},
		
		-- Medic
		{
			[26543] = {
				name = "Paralytic Surge",
				sprite = "ClientSprites:Icon_SkillMedic_paralyticsurge",
				iaTiers = {
					1, 1, 1, 1, 2, 2, 2, 2, 2
				}
			},
			
			[26529] = {
				name = "Magnetic Lockdown",
				sprite = "Icon_SkillMedic_magneticlockdown",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 1
				}
			},
		},
		
		-- Stalker
		{
			[23173] = {
				name = "Stagger",
				sprite = "Icon_SkillShadow_UI_stlkr_staggeringthrust",
				iaTiers = {
					1, 1, 1, 1, 2, 2, 2, 2, 2
				}
			},
			
			[23587] = {
				name = "False Retreat",
				sprite = "Icon_SkillShadow_UI_stlkr_shadowdash",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 1
				}
			},
			
			[23705] = {
				name = "Collapse",
				sprite = "Icon_SkillShadow_UI_stlkr_ragingslash",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 1
				}
			},
		},
		
		-- MYSTERY CLASS (deathknights!??!)
		{
		
		},
	
		-- Spellslinger
		{
			[30160] = {
				name = "Arcane Shock",
				sprite = "Icon_SkillSpellslinger_arcane_shock",
				iaTiers = {
					1, 1, 1, 1, 2, 2, 2, 2, 2
				}
			},
		
			[16454] = {
				name = "Spatial Shift",
				sprite = "Icon_SkillSpellslinger_spatial_shift",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 1
				}
			},
			
			[20325] = {
				name = "Gate",
				sprite = "Icon_SkillSpellslinger_gate",
				iaTiers = {
					1, 1, 1, 1, 1, 1, 1, 1, 2
				}
			},
		}
	}

    return o
end

function Nezability:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- Nezability OnLoad
-----------------------------------------------------------------------------------------------
function Nezability:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Nezability.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	debugprint("Loading...")
end

-----------------------------------------------------------------------------------------------
-- Nezability OnDocLoaded
-----------------------------------------------------------------------------------------------
function Nezability:OnDocLoaded()
	self:InitWindow()

	--Event Handlers/Timers/Slash Commands
	Apollo.RegisterTimerHandler("HalfSecTimer", "OnHalfSecond", self)
	Apollo.RegisterTimerHandler("CheckInChannelTimer", "OnCheckInChannel", self)

	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("Group_Join", "OnGroupJoin", self)
	Apollo.RegisterEventHandler("Group_Left", "OnGroupLeft", self)
	Apollo.RegisterEventHandler("Group_Add", "OnGroupAdd", self)
	Apollo.RegisterEventHandler("Group_Remove", "OnGroupRemove", self)
	Apollo.RegisterEventHandler("Group_MemberPromoted", "OnGroupMemberPromoted", self)
	Apollo.RegisterEventHandler("AbilityBookChange", "OnAbilityBookChange", self)
	
	Apollo.RegisterSlashCommand("acc", "OnNezabilityOn", self)
	debugprint("Event/Slash handlers registered.")
end

-----------------------------------------------------------------------------------------------
-- Nezability Functions
-----------------------------------------------------------------------------------------------
function Nezability:OnWindowManagementReady()
	debugprint("Window Management Ready...")
	--Variables are set here to avoid nil index errors
	self.player = GameLib.GetPlayerUnit()
	self.classId = self.player:GetClassId()
	self.playername = self.player:GetName()

	self:UpdateMyInterrupts()
	self:UpdateUI()
	
	--In case you log on into a group
	if GroupLib.GetMemberCount() > 0 then
		debugprint("Group detected, attempting to join.")
		self:OnGroupJoin()
	end
	
	debugprint("Starting main loop.")
	--Begin 'main loop'
	Apollo.CreateTimer("HalfSecTimer", 0.5, true)

	if self.savedSettings then
		self.settings = self.savedSettings
		self.savedSettings = nil
		self:ApplySettings()
	end
	
	--self.wndMain:Invoke()
	
	--This flag lets the rest of the addon know that WindowManagementReady has been called
	--and resources in GroupLib/GameLib should be available, i.e. not nil
	self.wmr = true
	debugprint("WMR Successful!")
end

function Nezability:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
        return nil
    end

	self.settings.windowAnchors = {self.wndMain:GetAnchorOffsets()}

	local tSave = {
		tSettings = self.settings
	}
	
	return tSave
end

function Nezability:OnRestore(eType, tSave)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
        return nil
    end

	if tSave.tSettings then
		self.savedSettings = tSave.tSettings
	end
end

function Nezability:ApplySettings()
	debugprint("Applying settings...")

	--Move window
	local anchors = self.settings.windowAnchors or {19, 550, 259, 714}
	local hfoffset = self.wndMain:FindChild("Header"):GetHeight() + self.wndMain:FindChild("Footer"):GetHeight()

	--If we dont remove the event handler, the window will do all kinds of funny stuff
	self.wndMain:RemoveEventHandler("WindowSizeChanged")
	self.wndMain:SetAnchorOffsets(anchors[1], anchors[2], anchors[3], anchors[2] + hfoffset + self.settings.viewRowCount * self.settings.rowHeight)
	self.wndMain:AddEventHandler("WindowSizeChanged", "OnWindowSizeChanged", self)
	
	--Change lock icon color
	if self.settings.windowLocked then
		self.wndMain:FindChild("Header"):FindChild("LockButton"):SetSprite("CRB_Basekit:kitIcon_Holo_LockDisabled")
	else
		self.wndMain:FindChild("Header"):FindChild("LockButton"):SetSprite("CRB_Basekit:kitIcon_Holo_Lock")
	end

	debugprint("Settings applied!")
end

function Nezability:OnGroupJoin()
	--Create Entries for everyone in the group when we accept an invite
	local count = GroupLib.GetMemberCount()
	
	debugprint("Detected "  .. count .. " group members.")
	for i = 1, count, 1 do
		local player = GroupLib.GetGroupMember(i)
		
		debugprint("Adding " .. player.strCharacterName .. " to group.")
		
		if not self.group[player.strCharacterName] then
			self.group[player.strCharacterName] = {}
			self.group[player.strCharacterName].classId = player.eClassId
			self.group[player.strCharacterName].spells = {}
		end
		--For creating unique channel names
		if player.bIsLeader then
			debugprint(player.strCharacterName .. " is leader.")
			self.partyLeader = player.strCharacterName
		end
	end
	
	debugprint("Joining channel on " .. self.partyLeader .. "...")
	--Attempt to join the group channel
	self.channel = ICCommLib.JoinChannel("IT_" .. self.partyLeader,ICCommLib.CodeEnumICCommChannelType.Global)
	self.channel:SetJoinResultFunction("OnITChannelMessage",self)
	self.channel:IsReady()
	self.channel:SetReceivedMessageFunction("OnITChannelMessage",self)
	--self.channel = ICCommLib.JoinChannel("IT_" .. self.partyLeader, "OnITChannelMessage", self)
	
	--Start the channel timer (see CheckInChannelTimer() for an explanation)
	Apollo.CreateTimer("CheckInChannelTimer", 1, true)

	self.wndMain:Invoke()
	self:UpdateUI()
end

function Nezability:OnGroupLeft()
	debugprint("You have left the group.")
	--Clear all values
	self.channel = nil
	self.inChannel = false
	self.group = {}
	
	--Sometimes the timer will still be going
	--Probably should figure out why but this fixes it regardless
	Apollo.StopTimer("CheckInChannelTimer")
	
	--Empty Windows are still bad
	self:UpdateMyInterrupts()
	self.wndMain:Show(false)
	
	--In case you exit from an instance group into a normal group
	--NOTE: MIGHT BE BUGGY
	if GroupLib.GetMemberCount() > 0 then
		debugprint("You have left an INSTANCE group, attempting to join old group...")
		self:OnGroupJoin()
		self.wndMain:Invoke()
	end
	
	self:UpdateUI()
end

function Nezability:OnGroupAdd(strNewGroupMember)
	--NOTE: This function only adds new members if they don't send their initial 
	--join/update message. The OnITChannelMessage will *usually* handle adding new group members first,
	--and as such this function is only included for people who do not have the addon.
	debugprint("New party member detected.")
	if not self.group[strNewGroupMember] then
		debugprint("No message recieved from " .. strNewGroupMember .. ". Creating dummy slot.")
		self.group[strNewGroupMember] = {}
		self.group[strNewGroupMember].spells = {}
		
		local count =  GroupLib.GetMemberCount()
		
		for i = 1, count, 1 do
			local player = GroupLib.GetGroupMember(i)
			
			if player.strCharacterName == strNewGroupMember then
				self.group[strNewGroupMember].classId = player.eClassId
				debugprint(self.group[strNewGroupMember].classId)
				break
			end
		end
	end
	self:UpdateUI();
end

function Nezability:OnGroupRemove(playerName)
	debugprint("Removing " .. playerName .. " from group table.")
	self.group[playerName] = nil

	self:UpdateUI();
end

function Nezability:OnGroupMemberPromoted()
	--As the group channel name is based on the party leader's name, when the leader changes
	--all channel information must be deleted and we must join the new channel.
	self.channel = nil
	self.inChannel = false
	self.group = {}
	
	--OnGroupJoin() is written as if we are already in the group table. Since we just erased the group table,
	--we must add ourselves back into it.
	self:UpdateMyInterrupts()
	
	--Same as if we joined a new group
	debugprint("Joining new host channel.")
	self:OnGroupJoin()
end

function Nezability:OnAbilityBookChange()
	--The logic for this flag/event is handled in the CheckLAS() function.
	--An explanation for why it is handled this way can also be found there as well as in
	--the Init() function.
	self.onLASUpdate = true
	debugprint("LAS Change detected.")
end

function Nezability:OnITChannelMessage(channel, Msg, strSender)
	--Prevents people from malicously flooding channel with fake messages.
	local inGroup = false
	--debugprint("Message Recieved from " .. strSender .. ".")
	for name, spells in pairs(self.group) do
		if strSender == name then
			inGroup = true
			break
		end
	end
	
	if not inGroup then return end
	debugprint("Sender validated.")
	
	--Handle message
	loadstring("tMsg ="..Msg)()
	self.message = tMsg

	if not tMsg then
		return
	elseif tMsg.type == ITMsg.Join then
		debugprint("Join message recieved. Sending update.")
		self:SendUpdate()
	elseif tMsg.type == ITMsg.Update then
		debugprint("Update recieved. Updating group table.")
		self:UpdateGroup(strSender)	
	end
end

function Nezability:SendUpdate()
	--Build update table to send
	local update = {}
	update.spells = {}
	update.type = ITMsg.Update
	
	debugprint("Attempting to send update....")
	
	--It is possible (and most likely) that when a new person joins a group, they will send their
	--join/update message before the Group_Add event is handled. Because of this, the message must
	--contain the persons class ID. This is so that UpdateUI() is not erroneously called from
	--OnGroupAdd() without player.classId being set (we will recieve their join/update message before
	--we have access to their class ID through the GroupLib)
	update.classId = self.classId

	for abilityId, interrupt in pairs(self.myInterrupts) do
		table.insert(update.spells, {
			id = abilityId,
			ia = self.interruptDb[self.classId][abilityId].iaTiers[interrupt:GetTier()],
			cd = interrupt:GetCooldownRemaining()
		})
	end
	
	self.group[self.playername].spells = update.spells
	self:UpdateTotalIA(self.playername)
	updateStr = table.tostring(update)
	if self.channel then
		self.channel:SendMessage(updateStr)
		debugprint("Message Sent!")
	else
		debugprint("No channel found.")
	end
end	

function Nezability:UpdateGroup(name)
	--Add/Update their group table entry
	debugprint("Updating " .. name .. "'s group table entry.")
	self.group[name] = {}
	self.group[name].classId = self.message.classId
	self.group[name].spells = self.message.spells
	self:UpdateTotalIA(name)
	
	self:UpdateUI()
end

function Nezability:UpdateTotalIA(name)
	--Calculates total interrupt armor based on tiers and cooldown times
	if not self.group[name] then return end
	debugprint("Updating "  .. name .. "'s total IA.")
	local total = 0
	
	for i, spell in ipairs(self.group[name].spells) do
		if spell.cd ~= 0 then
		else
			total = total + spell.ia
		end
	end
	
	self.group[name].totalIA = total
end

function Nezability:UpdateMyInterrupts()
	--Updates our own group table entry with current spells/cooldowns
	self.myInterrupts = {}
	local abilities = AbilityBook.GetAbilitiesList()
	local las = ActionSetLib.GetCurrentActionSet()
	
	--If this is called before ActionSetLib resources are available, this will be nil
	if not las then return end
	debugprint("Updating interrupts on self.")
	for i, ability in ipairs(las) do
		--Check for what current interrupts we have on our LAS
		if self.interruptDb[self.classId][ability] then
			local abilityData = nil
		
			for j, data in ipairs(abilities) do
				if data.nId == ability then
					abilityData = data.tTiers[data.nCurrentTier].splObject
					break
				end
			end
		
			--Record any interrupts found
			if abilityData then
				self.myInterrupts[ability] = abilityData
			end
		end
	end

	--Rebuild our group table entry
	self.group[self.playername] = {}
	self.group[self.playername].classId = self.classId	
	self.group[self.playername].spells = {}
	debugprint(table.getn(self.group))
	
	for abilityId, interrupt in pairs(self.myInterrupts) do
		table.insert(self.group[self.playername].spells, {
			id = abilityId,
			ia = self.interruptDb[self.classId][abilityId].iaTiers[interrupt:GetTier()],
			cd = interrupt:GetCooldownRemaining()
		})
	end

	self:UpdateTotalIA(self.playername)
end

function Nezability:OnCheckInChannel()
	--The reason we do not immediately send a join/update message upon joining a
	--group is because there is no gaurantee when a channel is created that it will
	--be functional. Instead we start a timer that attempts to send a join/update over the channel
	--until it finally succeeds.
	--Side note: flooding an unopened channel with messages at speeds greater than 10 messages/sec
	--will break a lot of other addons too (lol)
	if self.inChannel then return end
	debugprint("Attempting to join channel.")
	if self.channel and self.channel:SendMessage(ITMsg.Join) then
		self.inChannel = true
		self:SendUpdate()
		Apollo.StopTimer("CheckInChannelTimer")
		debugprint("Channel joined!")
	end
end

function Nezability:CheckLAS()
	--This is due to Carbines wonkiness. You would think an AbilityBookChange event would be
	--fired only when the LAS is actually changed, but NOOOOO, whenever someome switches to a different
	--instance (continent to continent, house to house, anywhere to instance, etc.) Carbines event system
	--fires off TEN BILLION AbilityBookChange events before the UI has had time to load resources for
	--GameLib, ActionSetLib, GroupLib.....you'll notice all the funtions contained in the following if-statement 
	--use ALL of those (This kills the addon). Instead we use a flag and let our 'main loop'  continuously 
	--check if an AbilityBookChange event has been recieved AND WindowManagementReady() has been called.
	-- This *should* gaurantee that nothing breaks (at least it seems to).
	if self.onLASUpdate and self.wmr then
		self:UpdateMyInterrupts()
		self:SendUpdate()
		self.redrawUI = true
		self.onLASUpdate = false
		debugprint("LAS updated.")
	end	
end

function Nezability:CheckGroupStatus()
	--Check if a party member has been killed or gone offline
	for name in pairs(self.group) do
		if not IsAlive(name) or not IsOnline(name) then
			debugprint("Dead/Offline player detected (" .. name .. ").")
			self.redrawUI = true
			self.onGroupStatus = true
			return
		end
	end
	
	--We will only reach here if a group member was dead or offline previously but now no one is
	if self.onGroupStatus then
		self.redrawUI = true
		self.onGroupStatus = false
	end
end

function Nezability:CheckMyCooldowns()
	--Continuously check if we have used an interrupt, and send a message if we have
	for abilityId, interrupt in pairs(self.myInterrupts) do
		if interrupt:GetCooldownRemaining() > 0 then
			self:SendUpdate()
			self.redrawUI = true
			self.onCooldown = true
			debugprint("Interrupt used, sending update to group.")
			return
		end
	end
	
	--Because the UI is only updated for other party members when an update message is recieved,
	--we must send one final update message once all our cooldowns are up, otherwise the UI will
	--display our last used cooldown as being perpetually at 0 seconds left. This is why the 
	--onCooldown flag is used.
	if self.onCooldown then
		debugprint("All interrupts back up, sending final update.")
		self:SendUpdate()
		self.redrawUI = true
		self.onCooldown = false
	end
end

function Nezability:OnHalfSecond()
	--Every half second we check if we have changed our LAS, if a group member has died or gone offline,
	--or if we have used a cooldown.
	self:CheckLAS() 
	self:CheckGroupStatus()
	self:CheckMyCooldowns()
	
	--If any check function has found an update, we will redraw the UI.
	if self.redrawUI then
		self.redrawUI = false
		self:UpdateUI()
	end
end

function Nezability:OnNezabilityOn()
	if self.wndMain:IsVisible() then
		self.wndMain:Close()
	else
	    self.wndMain:Invoke()
	end
end

--Utilities
function IsOnline(strPlayerName)
	local player = GameLib.GetPlayerUnit()
	
	if player and strPlayerName == player:GetName() then
		return true
	end

	local count = GroupLib.GetMemberCount()
	if count > 0 then
		for i = 1, count, 1 do
			local player = GroupLib.GetGroupMember(i)
			
			if player.strCharacterName == strPlayerName then
				return player.bIsOnline
			end
		end
	end
	return false
end	

function IsAlive(strPlayerName)
	local player = GameLib.GetPlayerUnit()
	
	if player and strPlayerName == player:GetName() then
		return not player:IsDead()
	end

	local count = GroupLib.GetMemberCount()
	if count > 0 then
		for i = 1, count, 1 do
			local player = GroupLib.GetGroupMember(i)
			
			if player.strCharacterName == strPlayerName then
				return player.nHealth > 0
			end
		end
	end
	return false
end

function debugprint(str) 
	if NezabilityDebug then
		Print(str)
	end
end

function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end

function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end

function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end
function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end





-----------------------------------------------------------------------------------------------
-- Nezability Instance
-----------------------------------------------------------------------------------------------
local NezabilityInst = Nezability:new()
NezabilityInst:Init()
