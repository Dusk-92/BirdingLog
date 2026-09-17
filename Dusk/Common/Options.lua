-- Plugin manager Options tab.
-- FR4: localized UI/messages when BirdingLog or FishingLog runs on a French client.

local function IsFR()
    return BL_Lang=="FR" or FL_Lang=="FR"
end
local function L(fr,en)
    if IsFR() then return fr else return en end
end

function Options_Box(OP,Ypos,text)
    local Box = Turbine.UI.Lotro.CheckBox()
    Box:SetParent( OP )
    Box:SetPosition( 10, Ypos )
    Box:SetSize( 220, 22 )
    Box:SetText( text )
    return Box
end

function Options_sBar(OP,scale,Window)
    local sBar = Turbine.UI.Lotro.ScrollBar()
    sBar:SetParent( OP )
    sBar:SetPosition( 10, 25 )
    sBar:SetSize( 220, 14 )
    sBar:SetMinimum( 50 )
    sBar:SetMaximum( 200 )
    sBar:SetSmallChange( 10 )
    sBar:SetLargeChange( 50 )
    sBar:SetValue( scale*100 )
    sBar.lbl = Turbine.UI.Label()
    sBar.lbl:SetParent( OP )
    sBar.lbl:SetPosition( 30,10 )
    sBar.lbl:SetSize( 180,15 )
    sBar.lbl:SetText( string.format(L("Échelle de la fenêtre : %.2f","Window scale: %.2f"), scale) )
    Window:SetScale(scale)
    return sBar
end

local YP = 10

function Options_Init(print,Settings,Window,Fname,Window2)
    local OP = Turbine.UI.Control()
    OP:SetBackColor( Turbine.UI.Color(0.0, 0.0, 0.1) )
    OP:SetSize( 240, 260 )
    plugin.GetOptionsPanel = function( self ) return OP end
    if not Window then return OP end
    if not Settings then Settings = {} end

    if Settings.scale and Window.SetScale then
        YP = 45
        local wScale = Options_sBar(OP,Settings.scale,Window)
        wScale.ValueChanged = function(sender, args)
            local scale = wScale:GetValue()/100
            Settings.scale = scale
            wScale.lbl:SetText( string.format(L("Échelle de la fenêtre : %.2f","Window scale: %.2f"), scale) )
            Window:SetScale(scale)
            if Window2 then Window2:SetScale(scale) end
        end
    end

    local autoBox = Options_Box(OP,YP,L(" Ouvrir automatiquement la fenêtre"," Auto-open window"))
    if Settings.pos1 or Settings.auto then
        if Settings.auto then
            Window:SetVisible( true )
            autoBox:SetChecked( true )
        end
        if type(Settings.auto)=="table" and not Settings.pos1 then
            Settings.pos1 = Settings.auto -- patch for old version
        end
    end
    autoBox.CheckedChanged = function( sender, args )
        if not Settings then Settings = {} end
        Settings.auto = sender:IsChecked()
        if Settings.auto then
            local x,y = Window:GetPosition()
            Settings.auto = { x=x, y=y }
            Settings.pos1 = { x=x, y=y }
            if Window2 then
                x,y = Window2:GetPosition()
                Settings.pos2 = { x=x, y=y }
            end
            print(L("Position de la fenêtre enregistrée.","Saved window position."))
        end
        if IsFR() then
            print(Settings.auto and "Ouverture automatique activée." or "Ouverture automatique désactivée.")
        else
            print((Settings.auto and "En" or "Dis").."abled Auto-open.")
        end
        if Fname then
            Turbine.PluginData.Save(Turbine.DataScope.Server,Fname,Settings)
            print(L("Paramètres enregistrés.","Settings saved."))
        end
    end
    if Window2==false then return OP,YP+20 end -- suppress esc?

    OP.noEsc = Options_Box(OP,YP+20,L(" Ignorer la touche Échap"," Ignore Esc key"))
    if Settings and Settings.esc then OP.noEsc:SetChecked( true ) end
    OP.noEsc.CheckedChanged = function( sender, args )
        if not Settings then Settings = {} end
        Settings.esc = sender:IsChecked()
        if IsFR() then
            print(Settings.esc and "Touche Échap ignorée." or "Touche Échap de nouveau active.")
        else
            print((Settings.esc and "En" or "Dis").."abled ignore Esc key.")
        end
        if Fname then
            Turbine.PluginData.Save(Turbine.DataScope.Server,Fname,Settings)
            print(L("Paramètres enregistrés.","Settings saved."))
        end
    end
    return OP,YP+40
end
