-- BirdingLog FR7.25 deed-progress window.
-- Uses BirdingLog's existing zone -> bird mappings and character totals only;
-- it does not attempt to read LOTRO's native Deed Log.

import "Turbine.UI.Lotro"
import "Dusk.Common.noAccent"

local Button = Turbine.UI.Lotro.Button
local Label = Turbine.UI.Label
local Window = Turbine.UI.Lotro.Window
local font = Turbine.UI.Lotro.Font.Verdana14
local white = Turbine.UI.Color(1.0,1.0,1.0)
local green = Turbine.UI.Color(0.35,1.0,0.35)
local grey = Turbine.UI.Color(0.72,0.72,0.72)

local UI = {
    title = "Birding Deeds",
    summary = "Completed zones: ",
    reward = "Known reward: ",
    noReward = "Not documented in BirdingLog",
    back = "Back",
    close = "Close",
    birds = "Birds seen: ",
}
if BL_Lang=="FR" then
    UI = {
        title = "Prouesses d'ornithologie",
        summary = "Zones terminées : ",
        reward = "Récompense connue : ",
        noReward = "Non renseignée dans BirdingLog",
        back = "Retour",
        close = "Fermer",
        birds = "Oiseaux vus : ",
    }
elseif BL_Lang=="DE" then
    UI = {
        title = "Vogelbeobachtungs-Taten",
        summary = "Abgeschlossene Gebiete: ",
        reward = "Bekannte Belohnung: ",
        noReward = "In BirdingLog nicht dokumentiert",
        back = "Zurück",
        close = "Schließen",
        birds = "Beobachtete Vögel: ",
    }
end

local function BL_DeedsSafeCount(value)
    local n=tonumber(value)
    if not n or n~=n or n<=0 then return 0 end
    return math.floor(n)
end

local function BL_DeedsZoneProgress(zone)
    local total,seen=0,0
    for id in pairs((zone and zone.id) or {}) do
        total=total+1
        if BL_DeedsSafeCount(BL_Totals and BL_Totals[id])>0 then seen=seen+1 end
    end
    return seen,total
end

local function BL_DeedsZoneName(zone)
    if not zone then return "" end
    return zone.ln or zone.z or ""
end

local function BL_DeedsReward(zone)
    if not zone then return nil,nil end
    for id,t in pairs(BL_GID or {}) do
        if type(t)=="table" and t.z==zone.z then return id,t end
    end
    return nil,nil
end

BL_DeedsWindow = class(Window)

function BL_DeedsWindow:_Track(control)
    table.insert(self.dynamic,control)
    return control
end

function BL_DeedsWindow:_Clear()
    for _,control in ipairs(self.dynamic) do
        pcall(function()
            control:SetVisible(false)
            control:SetParent(nil)
        end)
    end
    self.dynamic={}
end

function BL_DeedsWindow:_Label(text,x,y,w,h,align,color)
    local label=Label()
    label:SetParent(self)
    label:SetPosition(x,y)
    label:SetSize(w,h)
    label:SetText(text or "")
    label:SetFont(font)
    label:SetForeColor(color or white)
    label:SetTextAlignment(align or Turbine.UI.ContentAlignment.MiddleLeft)
    label:SetMouseVisible(false)
    return self:_Track(label)
end

function BL_DeedsWindow:_Button(text,x,y,w,h)
    local button=Button()
    button:SetParent(self)
    button:SetPosition(x,y)
    button:SetSize(w,h)
    button:SetText(text or "")
    return self:_Track(button)
end

function BL_DeedsWindow:Constructor()
    Window.Constructor(self)
    self:SetSize(540,470)
    self:SetText(UI.title)
    self:SetVisible(false)
    self.dynamic={}
    self.mode="summary"
    self.selectedZone=nil

    local sw,sh=Turbine.UI.Display.GetWidth(),Turbine.UI.Display.GetHeight()
    local saved=BL_Options and BL_Options.pos2
    local scale=(BL_Options and tonumber(BL_Options.scale)) or 1
    local maxX=math.max(0,sw-math.floor(self:GetWidth()*scale+0.5))
    local maxY=math.max(0,sh-math.floor(self:GetHeight()*scale+0.5))
    if type(saved)=="table" and tonumber(saved.x) and tonumber(saved.y) then
        self:SetPosition(
            math.max(0,math.min(tonumber(saved.x),maxX)),
            math.max(0,math.min(tonumber(saved.y),maxY))
        )
    else
        self:SetPosition(
            math.max(0,math.floor(maxX/2)),
            math.max(0,math.floor(maxY/2))
        )
    end

    self.closeButton=Button()
    self.closeButton:SetParent(self)
    self.closeButton:SetPosition(390,438)
    self.closeButton:SetSize(125,20)
    self.closeButton:SetText(UI.close)
    self.closeButton.Click=function()
        self:SetVisible(false)
    end

    self:SetWantsKeyEvents(false)
    self.VisibleChanged=function(sender,args)
        sender:SetWantsKeyEvents(sender:IsVisible())
        if sender:IsVisible() then sender:Refresh() end
    end
    self.KeyDown=function(sender,args)
        if args.Action==Turbine.UI.Lotro.Action.Escape and not (BL_Options and BL_Options.esc) then
            sender:SetVisible(false)
        end
    end
end

function BL_DeedsWindow:ShowSummary()
    self:_Clear()
    self.mode="summary"
    self.selectedZone=nil
    self:SetText(UI.title)

    local zones={}
    local completed=0
    for code,zone in pairs(BL_Zone or {}) do
        local seen,total=BL_DeedsZoneProgress(zone)
        if total>0 and seen>=total then completed=completed+1 end
        table.insert(zones,{code=code,zone=zone,name=BL_DeedsZoneName(zone),seen=seen,total=total})
    end
    table.sort(zones,function(a,b)
        if a.name==b.name then return a.code<b.code end
        return a.name<b.name
    end)

    self:_Label(
        UI.summary..completed.."/"..#zones,
        20,30,495,22,Turbine.UI.ContentAlignment.MiddleCenter,
        completed==#zones and #zones>0 and green or white
    )

    for index,entry in ipairs(zones) do
        local col=(index-1)%2
        local row=math.floor((index-1)/2)
        local marker=(entry.total>0 and entry.seen>=entry.total) and "[OK] " or ""
        local button=self:_Button(
            marker..entry.name.."  "..entry.seen.."/"..entry.total,
            20+col*255,62+row*22,245,20
        )
        local code=entry.code
        button.Click=function()
            self:ShowZone(code)
        end
    end
end

function BL_DeedsWindow:ShowZone(code)
    local zone=BL_Zone and BL_Zone[code]
    if not zone then
        self:ShowSummary()
        return false
    end

    self:_Clear()
    self.mode="zone"
    self.selectedZone=code
    local name=BL_DeedsZoneName(zone)
    self:SetText(UI.title.." — "..name)

    local back=self:_Button(UI.back,20,30,110,20)
    back.Click=function() self:ShowSummary() end

    local seen,total=BL_DeedsZoneProgress(zone)
    self:_Label(
        UI.birds..seen.."/"..total,
        145,30,370,20,Turbine.UI.ContentAlignment.MiddleRight,
        total>0 and seen>=total and green or white
    )

    local _,reward=BL_DeedsReward(zone)
    local rewardText=reward and (UI.reward..(reward.ln or reward.n)) or UI.noReward
    self:_Label(rewardText,20,60,495,22,Turbine.UI.ContentAlignment.MiddleLeft,grey)

    local birds={}
    for id in pairs(zone.id or {}) do
        local bird=BL_ID and BL_ID[id]
        if bird then
            table.insert(birds,{id=id,name=bird.ln or bird.n or id})
        end
    end
    table.sort(birds,function(a,b)
        if a.name==b.name then return a.id<b.id end
        return a.name<b.name
    end)

    local rows=math.ceil(#birds/2)
    if rows<1 then rows=1 end
    for index,entry in ipairs(birds) do
        local col=math.floor((index-1)/rows)
        local row=(index-1)%rows
        local count=BL_DeedsSafeCount(BL_Totals and BL_Totals[entry.id])
        local prefix=count>0 and "[OK] " or "[  ] "
        local suffix=count>1 and (" x"..count) or ""
        self:_Label(
            prefix..entry.name..suffix,
            20+col*255,105+row*34,245,28,
            Turbine.UI.ContentAlignment.MiddleLeft,
            count>0 and green or grey
        )
    end
    return true
end

local function BL_DeedsNormalize(value)
    local text=tostring(value or ""):gsub("^%s+",""):gsub("%s+$","")
    if type(noAccent)=="function" then text=noAccent(text) end
    return string.lower(text)
end

function BL_DeedsWindow:OpenZoneByName(name)
    local query=BL_DeedsNormalize(name)
    if query=="" then return false end

    local matches={}
    for code,zone in pairs(BL_Zone or {}) do
        local native=BL_DeedsNormalize(zone.z)
        local localized=BL_DeedsNormalize(zone.ln)
        if native==query or (localized~="" and localized==query) then
            table.insert(matches,code)
        end
    end
    if #matches~=1 then return false end

    self:ShowZone(matches[1])
    self:SetVisible(true)
    self:SetZOrder(2)
    return true
end

function BL_DeedsWindow:Refresh()
    if self.mode=="zone" and self.selectedZone and BL_Zone and BL_Zone[self.selectedZone] then
        self:ShowZone(self.selectedZone)
    else
        self:ShowSummary()
    end
end

BL_deedsWindow=BL_DeedsWindow()

function BL_OpenDeeds(zoneCode)
    if not BL_deedsWindow then return false end
    if BL_Options and tonumber(BL_Options.scale) then
        BL_deedsWindow:SetScale(tonumber(BL_Options.scale))
    end
    if zoneCode and BL_Zone and BL_Zone[zoneCode] then
        BL_deedsWindow:ShowZone(zoneCode)
    else
        BL_deedsWindow:ShowSummary()
    end
    BL_deedsWindow:SetVisible(true)
    BL_deedsWindow:SetZOrder(2)
    return true
end

function BL_OpenDeedByName(name)
    if not BL_deedsWindow then return false end
    return BL_deedsWindow:OpenZoneByName(name)
end
