-- UTILS
SLASH_RELOADUI1 = "/rl"; -- for quicker reloading
SlashCmdList.RELOADUI1 = ReloadUI();

SLASH_FRAMESTK1 = "/fs"; -- for quicker access to frame stack
SlashCmdList.FRAMESTK = function()
 LoadAddOn("Blizzard_DebugTools");
 FrameStackTooltip_Toggle();
end

------------------------------------------------------------------------
-- VARS
local mainFrameHeight = 375;
local mainFrameWidth = 350;

local roleFilter = {};
local ilvlFilter = 0;
local ilvlComparator = 0;
local classFilter = {};
local roleSelectActive = false;
local roleCountActive = false;
local classCountActive = false;
local ilvlSelectActive = false
local voiceChatSelectActive = false;

local comparatorStates = {
	"=",
	">",
	"<",
	"?",
}

local comparatorState = {
	TANK=4,
	HEALER=4,
	DAMAGER=4,
}

local comparatorDropdownItems = {
	"equal to",
	"at least",
	"maximum",
}
-- API_CALLS
local function GetGroupDetailInfo(resultID)
	return C_LFGList.GetSearchResultInfo(resultID);
end
local function GetGroupMemberInfo(resultID)
	return C_LFGList.GetSearchResultMemberCounts(resultID);
end
-- HELPERS
local function unfocusAllEditBoxes()
	PGF_tankCountEditBox:ClearFocus();
	PGF_healerCountEditBox:ClearFocus();
	PGF_damagerCountEditBox:ClearFocus();
	PGF_ilvlEditBox:ClearFocus();
end
local function initialize()
	PGF_tankCountEditBox:SetText("");
	PGF_healerCountEditBox:SetText("");
	PGF_damagerCountEditBox:SetText("")
	PGF_ilvlEditBox:SetText("");
	unfocusAllEditBoxes();
end
local function ToggleElementVisibility(element)
	if element:IsShown() then
		element:Hide();
	else
		element:Show();
	end
end
local function ToggleElementAlpha(element)
	if element:GetAlpha() > 0.5 then
		element:SetAlpha(0.5);
		return false;
	else 
		element:SetAlpha(1.0);
		return true;
	end
end
local function clearTable(tab)
	for k,v in pairs(tab) do
		tab[k] = nil;
	end
end
local function tableContainsValue(tab, value)
	for k,v in pairs(tab) do
		if v == value then
		
			return true;
		end
	end
	return false;
end
local function tableContainsKey(tab, key)
	for k,v in pairs(tab) do
		if k == key then
			return true;
		end
	end
	return false;
end
local function addToFilter(tab ,key, value)
	tab[key] = value;
end
local function removeFromFilter(tab, key)
	tab[key] = nil;
end
local function clearFilter(tab)
	clearTable(tab);
end
local function passesRoleFilter(resultID)
	if roleSelectActive then
		local tpasses = false;
		local hpasses = false;
		local dpasses = false;
		local memberInfo = GetGroupMemberInfo(resultID);
		if comparatorState["TANK"] == 1 then
			if memberInfo["TANK"] == roleFilter["TANK"] then
				tpasses = true;
			end
		elseif comparatorState["TANK"] == 2 then
			if memberInfo["TANK"] > roleFilter["TANK"] then
				tpasses = true;
			end
		elseif comparatorState["TANK"] == 3 then
			if memberInfo["TANK"] < roleFilter["TANK"] then
				tpasses = true;
			end
		elseif comparatorState["TANK"] == 4 then
			tpasses = true;
		end
		if comparatorState["HEALER"] == 1 then
			if memberInfo["HEALER"] == roleFilter["HEALER"] then
				hpasses = true;
			end
		elseif comparatorState["HEALER"] == 2 then
			if memberInfo["HEALER"] > roleFilter["HEALER"] then
				hpasses = true;
			end
		elseif comparatorState["HEALER"] == 3 then
			if memberInfo["HEALER"] < roleFilter["HEALER"] then
				hpasses = true;
			end
		elseif comparatorState["HEALER"] == 4 then
			hpasses = true;
		end
		if comparatorState["DAMAGER"] == 1 then
			if memberInfo["DAMAGER"] == roleFilter["DAMAGER"] then
				dpasses = true;
			end
		elseif comparatorState["DAMAGER"] == 2 then
			if memberInfo["DAMAGER"] > roleFilter["DAMAGER"] then
				dpasses = true;
			end
		elseif comparatorState["DAMAGER"] == 3 then
			if memberInfo["DAMAGER"] < roleFilter["DAMAGER"] then
				dpasses = true;
			end
		elseif comparatorState["DAMAGER"] == 4 then
			dpasses = true;
		end
		if tpasses and hpasses and dpasses then
			return true;
		end
		return false;
	end
	return true;
end
local function passesIlvlFilter(resultID)
	if ilvlSelectActive or ilvlComparator == "0" then
		local id, activityID, name, comment, voiceChat, iLvl, age, numBNetFriends, numCharFriends, numGuildMates, isDelisted, leaderName, numMembers = GetGroupDetailInfo(resultID);
		if ilvlComparator == 1 then
			if iLvl == tonumber(ilvlFilter) then
				return true;
			end
		elseif ilvlComparator == 2 then
			if iLvl >= tonumber(ilvlFilter) then
				return true;
			end
		elseif ilvlComparator == 3 then
			if iLvl <= tonumber(ilvlFilter) then
				return true;
			end
		end
		return false;
	end
	return true;
end
local function cycleComparatorState(button, name)
	if(comparatorState[name] < 4) then
		comparatorState[name] = comparatorState[name] + 1;
		button:SetText(comparatorStates[comparatorState[name]]);
	else
		comparatorState[name] = 1
		button:SetText(comparatorStates[comparatorState[name]]);
	end
end
local function getRoleCounts(tankInput, healerInput, damagerInput)
	local tnumber = string.match(tankInput:GetText(), "(%d+)");
	local hnumber = string.match(healerInput:GetText(), "(%d+)");
	local dnumber = string.match(damagerInput:GetText(), "(%d+)");
	roleFilter["TANK"] = tonumber(tnumber);
	roleFilter["HEALER"] = tonumber(hnumber);
	roleFilter["DAMAGER"] = tonumber(dnumber);
end
local function getIlvl(ilvlInput)
	ilvlFilter = PGF_ilvlEditBox:GetText();
end
-- HOOK
local orig_LFGListSearchPanel_UpdateResults = LFGListSearchPanel_UpdateResults;
LFGListSearchPanel_UpdateResults = function(...)
	local args = ...;
	local results = args.results;
	local passResults = {};
	local i = 1;
	for k,v in pairs(results) do
		if passesRoleFilter(v) and passesIlvlFilter(v) then
			passResults[i] = v;
			i = i + 1;
		end	
	end
	args.results = passResults;
	return orig_LFGListSearchPanel_UpdateResults(args);
end
-----------------UI-----------------
-----------------MAINFRAME-----------------
local PGF_MainFrame = CreateFrame("Frame", "PGF_MainFrame", LFGListFrame, "BasicFrameTemplateWithInset");
PGF_MainFrame:SetSize(mainFrameWidth, mainFrameHeight);
PGF_MainFrame:SetPoint("LEFT", LFGListFrame, "RIGHT");
PGF_MainFrame.title = PGF_MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
PGF_MainFrame.title:SetPoint("LEFT", PGF_MainFrame.TitleBg, "LEFT", 5, 0);
PGF_MainFrame.title:SetText("PGFilter");

-----------------COG-----------------
local PGF_Cog = CreateFrame("Button", "PGF_Cog", LFGListPVEStub, "UIPanelSquareButton");
PGF_Cog.icon:SetTexture("Interface/Worldmap/Gear_64Grey");
PGF_Cog.icon:SetTexCoord(0.1,0.9,0.1,0.9);
PGF_Cog:SetSize(22, 22);
PGF_Cog:SetPoint("CENTER", LFGListPVEStub, "BOTTOM", -3, 14);
PGF_Cog:RegisterForClicks("AnyUp", "AnyDown");
PGF_Cog:SetScript("OnMouseDown", function(self, button)
	ToggleElementVisibility(PGF_MainFrame);
end)


-----------------MAINBUTTONS-----------------
PGF_MainFrame.saveButton = CreateFrame("Button", "PGF_saveButton", PGF_MainFrame, "GameMenuButtonTemplate");
PGF_MainFrame.saveButton:SetPoint("LEFT", PGF_MainFrame, "BOTTOM", 0, 20);
PGF_MainFrame.saveButton:SetSize(140, 25);
PGF_MainFrame.saveButton:SetText("Apply");
PGF_MainFrame.saveButton:SetNormalFontObject("GameFontNormalLarge");
PGF_MainFrame.saveButton:SetHighlightFontObject("GameFontHighlightLarge");
PGF_MainFrame.saveButton:RegisterForClicks("AnyUp", "AnyDown");
PGF_MainFrame.saveButton:SetScript("OnMouseDown", function(self, button)
	unfocusAllEditBoxes();
	getRoleCounts(PGF_tankCountEditBox, PGF_healerCountEditBox, PGF_damagerCountEditBox);
	getIlvl(PGF_ilvlEditBox);
end)
--
PGF_MainFrame.resetBtn = CreateFrame("Button", "PGF_resetBtn", PGF_MainFrame, "GameMenuButtonTemplate");
PGF_MainFrame.resetBtn:SetPoint("RIGHT", PGF_MainFrame, "BOTTOM", 0, 20);
PGF_MainFrame.resetBtn:SetSize(140, 25);
PGF_MainFrame.resetBtn:SetText("Reset");
PGF_MainFrame.resetBtn:SetNormalFontObject("GameFontNormalLarge");
PGF_MainFrame.resetBtn:SetHighlightFontObject("GameFontHighlightLarge");
PGF_MainFrame.resetBtn:SetScript("OnMouseDown", function(self, button)
	initialize();
end)


-----------------ROLESELECTION-----------------
-- FRAME
PGF_MainFrame.roleContainer = CreateFrame("Frame", "PGF_roleContainer", PGF_MainFrame, "TranslucentFrameTemplate");
PGF_MainFrame.roleContainer:SetPoint("TOP", PGF_MainFrame, "TOP", 0, -20);
PGF_MainFrame.roleContainer:SetSize(mainFrameWidth, 75);

-- CHECKBUTTON
PGF_MainFrame.roleCheckBtn = CreateFrame("CheckButton", "PGF_roleCheckBtn", PGF_MainFrame.roleContainer, "UICheckButtonTemplate");
PGF_MainFrame.roleCheckBtn:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 10, 0);
PGF_MainFrame.roleCheckBtn.tooltip = "Toggle role filter";
PGF_MainFrame.roleCheckBtn:SetSize(30, 30);
PGF_MainFrame.roleCheckBtn:RegisterForClicks("AnyDown");
ToggleElementAlpha(PGF_MainFrame.roleContainer);
PGF_MainFrame.roleCheckBtn:SetScript("OnMouseDown", function(self, button)
	if self:GetChecked() then
		roleSelectActive = false;
		ToggleElementAlpha(PGF_MainFrame.roleContainer);
	else
		roleSelectActive = true;
		ToggleElementAlpha(PGF_MainFrame.roleContainer);
	end
end)

-- TANK
PGF_MainFrame.tankIcon = CreateFrame("Frame", "PGF_tankIcon", PGF_MainFrame.roleContainer);
PGF_MainFrame.tankIcon:SetSize(40, 40);
local tankIconTexture = PGF_MainFrame.tankIcon:CreateTexture(nil, "BACKGROUND");
tankIconTexture:SetTexture("Interface/LFGFRAME/UI-LFG-ICON-ROLES");
tankIconTexture:SetTexCoord(GetTexCoordsForRole("TANK"));
tankIconTexture:SetAllPoints(PGF_MainFrame.tankIcon);
PGF_MainFrame.tankIcon.texture = tankIconTexture;
PGF_MainFrame.tankIcon:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 40, 0);
PGF_MainFrame.tankIcon:Show();

PGF_MainFrame.roleContainer.tankOperatorButton = CreateFrame("Button", "PGF_tankOperatorButton", PGF_MainFrame.roleContainer, "GameMenuButtonTemplate");
PGF_MainFrame.roleContainer.tankOperatorButton:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 82, 0);
PGF_MainFrame.roleContainer.tankOperatorButton:SetSize(25, 25);
PGF_MainFrame.roleContainer.tankOperatorButton:SetText(comparatorStates[4]);
PGF_MainFrame.roleContainer.tankOperatorButton:RegisterForClicks("AnyUp", "AnyDown");
PGF_MainFrame.roleContainer.tankOperatorButton:SetScript("OnMouseDown", function(self, button)
	cycleComparatorState(self, "TANK");
end)

PGF_MainFrame.roleContainer.tankCountEditBox = CreateFrame("EditBox", "PGF_tankCountEditBox", PGF_MainFrame.roleContainer, "InputBoxTemplate");
PGF_MainFrame.roleContainer.tankCountEditBox:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 115, 0);
PGF_MainFrame.roleContainer.tankCountEditBox:SetAutoFocus(false);
PGF_MainFrame.roleContainer.tankCountEditBox:SetSize(20, 15);
PGF_MainFrame.roleContainer.tankCountEditBox:SetFontObject("GameFontHighlight");

-- HEALER
PGF_MainFrame.healIcon = CreateFrame("Frame", "PGF_healIcon", PGF_MainFrame.roleContainer);
PGF_MainFrame.healIcon:SetSize(40, 40);
local healerIconTexture = PGF_MainFrame.healIcon:CreateTexture(nil, "BACKGROUND");
healerIconTexture:SetTexture("Interface/LFGFRAME/UI-LFG-ICON-ROLES");
healerIconTexture:SetTexCoord(GetTexCoordsForRole("HEALER"));
healerIconTexture:SetAllPoints(PGF_MainFrame.healIcon);
PGF_MainFrame.healIcon.texture = healerIconTexture;
PGF_MainFrame.healIcon:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 140, 0);
PGF_MainFrame.healIcon:Show();

PGF_MainFrame.roleContainer.healerOperatorButton = CreateFrame("Button", "PGF_healerOperatorButton", PGF_MainFrame.roleContainer, "GameMenuButtonTemplate");
PGF_MainFrame.roleContainer.healerOperatorButton:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 182, 0);
PGF_MainFrame.roleContainer.healerOperatorButton:SetSize(25, 25);
PGF_MainFrame.roleContainer.healerOperatorButton:SetText(comparatorStates[4]);
PGF_MainFrame.roleContainer.healerOperatorButton:RegisterForClicks("AnyUp", "AnyDown");
PGF_MainFrame.roleContainer.healerOperatorButton:SetScript("OnMouseDown", function(self, button)
	cycleComparatorState(self, "HEALER");
end)

PGF_MainFrame.roleContainer.healerCountEditBox = CreateFrame("EditBox", "PGF_healerCountEditBox", PGF_MainFrame.roleContainer, "InputBoxTemplate");
PGF_MainFrame.roleContainer.healerCountEditBox:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 215, 0);
PGF_MainFrame.roleContainer.healerCountEditBox:SetAutoFocus(false);
PGF_MainFrame.roleContainer.healerCountEditBox:SetSize(20, 15);
PGF_MainFrame.roleContainer.healerCountEditBox:SetFontObject("GameFontHighlight");

-- DPS
PGF_MainFrame.damagerIcon = CreateFrame("Frame", "PGF_dpsIcon", PGF_MainFrame.roleContainer);
PGF_MainFrame.damagerIcon:SetSize(40, 40);
local damagerIconTexture = PGF_MainFrame.damagerIcon:CreateTexture(nil, "BACKGROUND");
damagerIconTexture:SetTexture("Interface/LFGFRAME/UI-LFG-ICON-ROLES");
damagerIconTexture:SetTexCoord(GetTexCoordsForRole("DAMAGER"));
damagerIconTexture:SetAllPoints(PGF_MainFrame.damagerIcon);
PGF_MainFrame.damagerIcon.texture = dpsIconTexture;
PGF_MainFrame.damagerIcon:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 240, 0);
PGF_MainFrame.damagerIcon:Show();

PGF_MainFrame.roleContainer.damagerOperatorButton = CreateFrame("Button", "PGF_damagerOperatorButton", PGF_MainFrame.roleContainer, "GameMenuButtonTemplate");
PGF_MainFrame.roleContainer.damagerOperatorButton:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 282, 0);
PGF_MainFrame.roleContainer.damagerOperatorButton:SetSize(25, 25);
PGF_MainFrame.roleContainer.damagerOperatorButton:SetText(comparatorStates[4]);
PGF_MainFrame.roleContainer.damagerOperatorButton:RegisterForClicks("AnyUp", "AnyDown");
PGF_MainFrame.roleContainer.damagerOperatorButton:SetScript("OnMouseDown", function(self, button)
	cycleComparatorState(self, "DAMAGER");
end)

PGF_MainFrame.roleContainer.damagerCountEditBox = CreateFrame("EditBox", "PGF_damagerCountEditBox", PGF_MainFrame.roleContainer, "InputBoxTemplate");
PGF_MainFrame.roleContainer.damagerCountEditBox:SetPoint("LEFT", PGF_MainFrame.roleContainer, "LEFT", 315, 0);
PGF_MainFrame.roleContainer.damagerCountEditBox:SetAutoFocus(false);
PGF_MainFrame.roleContainer.damagerCountEditBox:SetSize(20, 15);
PGF_MainFrame.roleContainer.damagerCountEditBox:SetFontObject("GameFontHighlight");

-----------------ITEMLEVELFILTER-----------------
-- FRAME
PGF_MainFrame.ilvlContainer = CreateFrame("Frame", "PGF_ilvlFilterFrame", PGF_MainFrame, "TranslucentFrameTemplate");
PGF_MainFrame.ilvlContainer:SetPoint("TOP", PGF_MainFrame, "TOP", 0, -80);
PGF_MainFrame.ilvlContainer:SetSize(mainFrameWidth, 75);

-- CHECKBUTTON
PGF_MainFrame.ilvlCheckBtn = CreateFrame("CheckButton", "PGF_ilvlCheckBtn", PGF_MainFrame.ilvlContainer, "UICheckButtonTemplate");
PGF_MainFrame.ilvlCheckBtn:SetPoint("LEFT", PGF_MainFrame.ilvlContainer, "LEFT", 10, 0);
PGF_MainFrame.ilvlCheckBtn.tooltip = "Toggle itemlevel filter";
PGF_MainFrame.ilvlCheckBtn:SetSize(30, 30);
PGF_MainFrame.ilvlCheckBtn:RegisterForClicks("AnyDown");
ToggleElementAlpha(PGF_MainFrame.ilvlContainer);
PGF_MainFrame.ilvlCheckBtn:SetScript("OnMouseDown", function(self, button)
	if self:GetChecked() then
		ilvlSelectActive = false;
		ToggleElementAlpha(PGF_MainFrame.ilvlContainer);
	else
		ilvlSelectActive = true;
		ToggleElementAlpha(PGF_MainFrame.ilvlContainer);
	end
end)

-- LABEL
PGF_MainFrame.ilvlContainer.label = PGF_MainFrame.ilvlContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
PGF_MainFrame.ilvlContainer.label:SetPoint("LEFT", PGF_MainFrame.ilvlContainer, "LEFT", 45, 0);
PGF_MainFrame.ilvlContainer.label:SetText("Item Level");

-- COMPARATORDROPDOWN
PGF_MainFrame.ilvlContainer.comparatorDropdown = CreateFrame("Frame", "PGF_comparatorDropdown", PGF_MainFrame.ilvlContainer, "UIDropDownMenuTemplate");
PGF_MainFrame.ilvlContainer.comparatorDropdown:ClearAllPoints();
PGF_MainFrame.ilvlContainer.comparatorDropdown:SetPoint("LEFT", PGF_MainFrame.ilvlContainer, "LEFT", 100, -2);
PGF_MainFrame.ilvlContainer.comparatorDropdown:Show();

local function OnClick(self)
   UIDropDownMenu_SetSelectedID(PGF_comparatorDropdown, self:GetID());
   ilvlComparator = self:GetID();
end
 
local function initialize(self, level)
   local info = UIDropDownMenu_CreateInfo()
   for k,v in pairs(comparatorDropdownItems) do
      info = UIDropDownMenu_CreateInfo()
      info.text = v
      info.value = v
      info.func = OnClick;
      UIDropDownMenu_AddButton(info, level);
   end
end
 
UIDropDownMenu_Initialize(PGF_comparatorDropdown, initialize);
UIDropDownMenu_SetWidth(PGF_comparatorDropdown, 80);
UIDropDownMenu_SetButtonWidth(PGF_comparatorDropdown, 124);
UIDropDownMenu_JustifyText(PGF_comparatorDropdown, "LEFT");

-- EDITBOX
PGF_MainFrame.ilvlContainer.editBox = CreateFrame("EditBox", "PGF_ilvlEditBox", PGF_MainFrame.ilvlContainer, "InputBoxTemplate");
PGF_MainFrame.ilvlContainer.editBox:SetPoint("LEFT", PGF_MainFrame.ilvlContainer, "LEFT", 230, 0);
PGF_MainFrame.ilvlContainer.editBox:SetAutoFocus(false);
PGF_MainFrame.ilvlContainer.editBox:SetNumeric(true);
PGF_MainFrame.ilvlContainer.editBox:SetSize(40, 15);
PGF_MainFrame.ilvlContainer.editBox:SetFontObject("GameFontHighlight");

-----------------ROLECOUNTFILTER-----------------
-- FRAME
PGF_MainFrame.roleCountContainer = CreateFrame("Frame","PGF_roleCountFrame", PGF_MainFrame, "TranslucentFrameTemplate");
PGF_MainFrame.roleCountContainer:SetPoint("TOP", PGF_MainFrame, "TOP", 0, -140);
PGF_MainFrame.roleCountContainer:SetSize(mainFrameWidth, 75);

-- LABEL
PGF_MainFrame.roleCountContainer.label = PGF_MainFrame.ilvlContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
PGF_MainFrame.roleCountContainer.label:SetPoint("LEFT", PGF_MainFrame.roleCountContainer, "LEFT", 45, 0);
PGF_MainFrame.roleCountContainer.label:SetText("Coming soon");

--INIT
initialize();
