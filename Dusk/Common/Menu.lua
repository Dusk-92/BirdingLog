--
--	This class creates a LOTRO style drop-down menu.
-- 	Derived from code by Galuhad.
--
--------------------------------------------------------------------------
--
-- USAGE:
--			myTable = {"First Item", "Second Item", "Third Item"} -- etc..
--
--			myDropDown = DropDown.Create(myTable, "Second Item") -- table that contains the list, default selected value for the list
--		 	myDropDown:SetParent(someParent)
--			myDropDown:ApplyWidth(100) -- set the width of the menu, this is not essential to include as the default is a good size.
--			myDropDown:SetMaxItems(8) -- Number of items to display in the drop down before a scrollbar is needed.. default value is 7 where this is excluded.
--			myDropDown:SetPosition(x,y)
--			myDropDown:SetVisible(true)
--
--			myDropDown.ItemChanged = function () -- The event that's executed when a menu item is clicked.
--				selectedItem = myDropDown:GetText()
--				Turbine.Shell.WriteLine("Selected item " .. selectedItem)
--			end
--
--			If you wish to add or remove items after the original menu is created, use:
--
--			myDropDown:GetItemList() -- Returns the MenuItemList so it can be coded externally, use this when you feel this class isn't flexible enough
--			myDropDown:SetText() -- Selected value shown
--
--			or
--
--			myDropDown:GetItemControls() -- Returns the dropdowns ListBox for even more control,
--				with this you can add different controls to the drop-down instead of just having text labels
--			myDropDown:SetMenuVisible(true or false) -- Sets wether the dropdown is visible.
--
--			Other properties:
--
--			myDropDown:SetMenuColor(Turbine Color Class) -- Sets the back color of the menu.. alpha value used by class default color is 0.8
--			myDropDown:SetBorderColor(Turbine Color Class) -- Sets the frame color of the menu (default is grey)
--			myDropDown:SetMenuEnabled() -- Set's the enabled state of the menu
--			myDropDown:GetMenuColor() -- Returns the menu back color as a Turbine color class
--			myDropDown:GetBorderColor() -- Returns the menu's border color as a Turbine color class
--			myDropDown:GetMaxItems() -- Returns the maximum number of items displayed before the scrollbar is visible
--			myDropDown:GrabWidth() -- Returns the width of the menu.
--			myDropDown:GetMenuEnabled() -- Returns the enabled state of the menu
--
---------------------------------------------------------------------------
local Black = Turbine.UI.Color(0,0,0)
local Bronze = Turbine.UI.Color(229/255,209/255,136/255)
local Highlight = Turbine.UI.Color(0.85,0.65,0)
local Grey = Turbine.UI.Color(0.63,0.63,0.63)
local White = Turbine.UI.Color(1,1,1)

DropDown = {}

-- Functions to set the values for different parameters.
function DropDown.Create(ListTable,Default)

	-- Defined values for the width and height.. These are the same measurements as the drop-downs on the
	-- in-game settings window (159 x 19)
	local MenuWidth = 159
	local MenuHeight = 19
	local MaxItems = 9 -- Number of items before scrollbar is needed.
	local MenuEnabled = true -- Flag to enable the menu.

	if Default == nil then
		if ListTable ~= nil and type(ListTable) == 'table' then
			Default = ListTable[1]
		else
			Default = ""
		end
	end

	local List = {}

	-- Main holder for the drop down, also creates the grey frame.
	local DropDownParent = Turbine.UI.Window()
	DropDownParent:SetSize(MenuWidth,MenuHeight)
	DropDownParent:SetBackColor(Grey)
	DropDownParent:SetPosition(0,0)
	DropDownParent:SetVisible(true)
	DropDownParent:SetMouseVisible(false)

	-- The black window that sits inside the frame.
	local BlackBox = Turbine.UI.Window()
	BlackBox:SetParent(DropDownParent)
	BlackBox:SetSize(DropDownParent:GetWidth()-4,DropDownParent:GetHeight()-4)
	BlackBox:SetPosition(2,2)
	BlackBox:SetBackColor(Black)
	BlackBox:SetVisible(true)

	-- The label that displays the current selected menu item.
	local tempLabel = Turbine.UI.Label()
	tempLabel:SetParent(BlackBox)
	tempLabel:SetSize(BlackBox:GetWidth(),BlackBox:GetHeight())
	tempLabel:SetPosition(0,0)
	tempLabel:SetBackColor(Black)
	tempLabel:SetForeColor(Bronze)
	tempLabel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
	tempLabel:SetFont(Turbine.UI.Lotro.Font.TrajanPro14)
	tempLabel:SetText(Default)
	tempLabel:SetMouseVisible(false)

	-- Drop down arrow shown in the control.
	local arrow = Turbine.UI.Control()
	arrow:SetParent(BlackBox)
	arrow:SetSize(14,14)
	arrow:SetPosition((BlackBox:GetWidth() - 13),(BlackBox:GetHeight() - 14))
	arrow:SetBackground(0x41007e18)
	arrow:SetStretchMode(2)
	arrow:SetMouseVisible(false)

	local listPARENT = Turbine.UI.Window()
	listPARENT:SetSize(Turbine.UI.Display.GetSize())
	listPARENT:SetPosition(0,0)
	listPARENT:SetBackColor(Black)
	listPARENT:SetVisible(false)
	listPARENT:SetZOrder(10000)

	local listBOXParent = Turbine.UI.Window()
	listBOXParent:SetParent(listPARENT)
	listBOXParent:SetSize(MenuWidth,0)
	listBOXParent:SetPosition(0,0)
	listBOXParent:SetBackColor(Grey)
	listBOXParent:SetVisible(false)

	local listBOX = Turbine.UI.ListBox()
	listBOX:SetParent(listBOXParent)
	listBOX:SetSize(MenuWidth-4,0)
	listBOX:SetPosition(2,2)
	listBOX:SetBackColor(Turbine.UI.Color(0.8,0,0,0))
	listBOX:SetVisible(true)

	local listScroll = Turbine.UI.Lotro.ScrollBar()
	listScroll:SetParent(listBOX)
	listScroll:SetOrientation(Turbine.UI.Orientation.Vertical)
	listScroll:SetWidth(8)
	listScroll:SetPosition(listBOX:GetWidth()-9,0)
	listScroll:SetVisible(false)
	listScroll:SetZOrder(200000)
	listBOX:SetVerticalScrollBar(listScroll)

	local greyBox = Turbine.UI.Window()
	greyBox:SetParent(DropDownParent)
	greyBox:SetBackColor(Turbine.UI.Color(0.7,0,0,0))
	greyBox:SetZOrder(10000)
	greyBox:SetVisible(false)


	-- This creates the context menu, it starts by creating a new context menu object
	-- It then searches the supplied table for the elements to add.
	local tempList = Turbine.UI.ContextMenu()
	local listItems = tempList:GetItems()

	if ListTable ~= nil and type(ListTable) == 'table' then

		for k,v in pairs (ListTable) do

			local tempItem = Turbine.UI.MenuItem(v)
			listItems:Add(tempItem)

			tempItem.Click = function (sender, args)

				tempLabel:SetText(v)

				-- External event listener .ItemChanged() caller.
				function ItemChangedListener()
					List:ItemChanged()
				end

				if pcall(ItemChangedListener) == true then
					-- External listener function exists, so execute the code.
					--ItemChangedListener(); -- may not be needed, check if statements are executed twice.
				end

			end

		end

	end


	-- Highlight the menu as the mouse enters.
	BlackBox.MouseEnter = function (sender, args)
		if MenuEnabled then
			arrow:SetBackground(0x41007e1b)
			tempLabel:SetOutlineColor(Highlight)
			tempLabel:SetForeColor(White)
			tempLabel:SetFontStyle(8)
		end
	end

	-- Returns the menu to normal state as the mouse leaves.
	BlackBox.MouseLeave = function (sender, args)
		if MenuEnabled then
			arrow:SetBackground(0x41007e18)
			tempLabel:SetOutlineColor(Black)
			tempLabel:SetForeColor(Bronze)
			tempLabel:SetFontStyle(0)
		end
	end

	-- Mouse down event causes the context menu created above to be displayed.
	BlackBox.MouseDown = function (sender, args)

		if MenuEnabled then
			tempLabel:SetOutlineColor(Black)
			tempLabel:SetForeColor(Turbine.UI.Color(0.45,0.45,0.45))
			tempLabel:SetFontStyle(0)

			--local x, y = DropDownParent:PointToScreen();
			-- The x co-ord that is returned here seems to be broken so am taking the long route to get the position.
			local PARENT = DropDownParent:GetParent()
			local x = DropDownParent:GetLeft()
			local y = DropDownParent:GetTop()

			while PARENT ~= nil do
				x = x + PARENT:GetLeft()
				y = y + PARENT:GetTop()
				PARENT = PARENT:GetParent()
			end

			y = y + DropDownParent:GetHeight() + 2

			listBOXParent:SetPosition(x,y)
			listPARENT:SetVisible(true)
			listBOXParent:SetVisible(true)

			-- Reset the list box first incase the menu items are created on the fly.
			--listBOX:ClearItems();


			local itemCount = listItems:GetCount()
			local listCount = listBOX:GetItemCount()
			local menuCount = 0
			local menuHeightMultipler = 17

			if itemCount == 0 then

				if listCount > 0 then

					menuCount = listCount

					for i=1, listCount, 1 do

						-- Loop through the item children to get the max height..
						local tempChild = listBOX:GetItem(i)
						local tempHeight = tempChild:GetHeight()

						if tempHeight > menuHeightMultipler then menuHeightMultipler = tempHeight end
					end

				end

			else
				menuCount = itemCount
				listBOX:ClearItems() -- For menus created with a preset table it is needed to reset the ListBox otherwise it continues adding and adding
			end


			-- If menu count is less than the max items then display as normal, if it's more then we
			-- need to cut it off at the max limit and make the scrollbar visible.
			if menuCount <= MaxItems then

				listBOXParent:SetHeight((menuCount*menuHeightMultipler)+4)
				listBOX:SetHeight(menuCount*menuHeightMultipler)
				listScroll:SetVisible(false)

			else

				listBOXParent:SetHeight((MaxItems*menuHeightMultipler)+4)
				listBOX:SetHeight(MaxItems*menuHeightMultipler)
				listScroll:SetHeight(MaxItems*menuHeightMultipler)
				listScroll:SetVisible(true)

			end


			-- Add each item to the list.
			if itemCount > 0 then

				for i=1, menuCount, 1 do

					local menuItem = listItems:Get(i)
					local labelValue = menuItem:GetText()

					local tempItemName = Turbine.UI.Label()
					tempItemName:SetSize(listBOX:GetWidth()-4,17)
					tempItemName:SetForeColor(Bronze)
					tempItemName:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
					tempItemName:SetFont(Turbine.UI.Lotro.Font.TrajanPro14)
					tempItemName:SetText(labelValue)


					-- Highlight the menu as the mouse enters.
					tempItemName.MouseEnter = function (sender, args)
						tempItemName:SetOutlineColor(Highlight)
						tempItemName:SetForeColor(White)
						tempItemName:SetFontStyle(8)
					end

					-- Return the menu to normal state as the mouse leaves.
					tempItemName.MouseLeave = function (sender, args)
						tempItemName:SetOutlineColor(Black)
						tempItemName:SetForeColor(Bronze)
						tempItemName:SetFontStyle(0)
					end


					-- Mouse click event - changes the label, executes the ItemChanged() function, and closes the menu.
					tempItemName.MouseClick = function (sender, args)

						tempLabel:SetText(labelValue)

						listPARENT:SetVisible(false)
						listBOXParent:SetVisible(false)

						-- External event listener .ItemChanged() caller.
						function ItemChangedListener()
							List:ItemChanged()
						end

						if pcall(ItemChangedListener) == true then
							-- External listener function exists, so execute the code.
							--ItemChangedListener(); -- may not be needed, check if statements are executed twice.
						end

					end

					listBOX:AddItem(tempItemName)

				end

			end

		end

	end


	-- Close the menu on a click
	listPARENT.MouseClick = function (sender, args)
		listPARENT:SetVisible(false)
		listBOXParent:SetVisible(false)
	end


	-- Mouse up event.
	BlackBox.MouseUp = function (sender, args)
		if MenuEnabled == true then
			tempLabel:SetOutlineColor(Black)
			tempLabel:SetForeColor(Bronze)
			tempLabel:SetFontStyle(0)
		end
	end

	-- This part creates the metatable.
	DropDownParent.__index = DropDownParent
	DropDownParent.__newindex = DropDownParent

	setmetatable(List,DropDownParent)


	-- Returns the text of the menu label
	List.GetText = function ()
		return tempLabel:GetText()
	end


	-- Return the Menu Item List
	List.GetItemList = function ()
		return listItems
	end


	-- Return the controls in the list box
	List.GetItemControls = function ()
		return listBOX
	end


	function List:SetMenuVisible(visible)
		listPARENT:SetVisible(visible)
		listBOXParent:SetVisible(visible)
	end


	-- Set the text of the selected item
	function List:SetLabel(value)
		if value ~= nil then tempLabel:SetText(value) end
	end


	-- Change the menu width
	function List:ApplyWidth(value)
		DropDownParent:SetWidth(value)
		BlackBox:SetWidth(value-4)
		tempLabel:SetWidth(value-4)
		arrow:SetLeft(value-17)
		listBOXParent:SetWidth(value)
		listBOX:SetWidth(value-4)
	end


	-- Returns the menu width
	List.GrabWidth = function ()
		return DropDownParent:GetWidth()
	end


	-- Sets the maximum # of items the menu will display
	function List:SetMaxItems(value)
		MaxItems = value
	end


	-- Returns the maximum # of items the menu will display
	List.GetMaxItems = function ()
		return MaxItems
	end


	-- Set the main body color of the menu (default is black)
	function List:SetMenuColor(color)
		BlackBox:SetBackColor(color)
		tempLabel:SetBackColor(color)
		listBOX:SetBackColor(color)
	end


	-- Return the menu color
	List.GetMenuColor = function ()
		return BlackBox:GetBackColor()
	end


	-- Set the border color of the menu (default is grey)
	function List:SetBorderColor(color)
		DropDownParent:SetBackColor(color)
		listBOXParent:SetBackColor(color)
	end


	-- Return the border color
	List.GetBorderColor = function ()
		return DropDownParent:GetBackColor()
	end


	-- Set the enabled state of the menu
	function List:SetMenuEnabled ( enabled )
		if enabled then
			MenuEnabled = true
			greyBox:SetVisible(false)
		else
			MenuEnabled = false
			greyBox:SetSize(DropDownParent:GetSize())
			greyBox:SetVisible(true)
		end
	end


	-- Return the enabled state of the menu
	List.GetMenuEnabled = function ()
		return MenuEnabled
	end


	return List

end




