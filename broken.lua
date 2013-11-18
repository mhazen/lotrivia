


--[[
		-- Edit Player window class
	--
	LTEditPlayerWindow = class(Turbine.UI.Lotro.Window);

	function LTEditPlayerWindow:Constructor()
		Turbine.UI.Lotro.Window.Constructor(self);

		self:SetPosition(Turbine.UI.Display:GetWidth()-450,Turbine.UI.Display:GetHeight()/2-250);
		self:SetText("Edit Score");
		self:SetSize(270, 400);
		self:SetResizable(false);

		-- define child Elements

		self.headerText = Turbine.UI.Label()
		self.headerText:SetSize(300,20)
		self.headerText:SetPosition(18,34)
		self.headerText:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 )
		self.headerText:SetForeColor( Turbine.UI.Color(0,.8,.8) )
		self.headerText:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
		self.headerText:SetMultiline( true )
		self.headerText:SetBackColor( Turbine.UI.Color(.8, .2, .8) )
		self.headerText:SetText( "Use the + and - buttons to increase or decrease the player's score. " )
		self.headerText:SetVisible( true )
		self.headerText:SetParent( self )


	end


	-- Initialize an instance
	local myEditPlayer= LTEditPlayerWindow()

	-- Show the scores window
	myEditPlayer:SetVisible(true);

]]--


