-- Common Help function for plugins by David Down
-- coding: utf-8

TT_Window = class( Turbine.UI.Window )

function TT_Window:Constructor()
	Turbine.UI.Window.Constructor( self )
	self:SetSize( 90,18 )
	self:SetBackColor( Turbine.UI.Color( 0,0,0 ) )
	self:SetZOrder(1100) -- Always on top
	self:SetVisible(false)

    -- label popup
    local label = Turbine.UI.TextBox()
	label:SetParent(self)
    label:SetPosition( 2,1 )
    label:SetSize( 500, 16 )
    label:SetForeColor( Turbine.UI.Color( 1,1,1 ) )
    label:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 )
    label:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft )
    self.label = label
end

TT_window = TT_Window()

function ToolTip(owner,x,y,tip,len)
    owner.MouseEnter = function( sender,args )
        if owner.skip then return end
        TT_window:SetParent(owner)
        TT_window:SetPosition( x,y )
        TT_window:SetSize( len or #tip*9, 18 )
        TT_window.label:SetText( tip )
        TT_window:SetVisible(true)
    end
    owner.MouseLeave = function( sender,args )
        TT_window:SetVisible(false)
    end
end
