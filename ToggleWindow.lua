--[[
	This class (minus minor edits) was the work of by Chiran,
	written for his excellent plugin Songbook, and used here
	with his gracious permission.
--]]

Toggle = class( Turbine.UI.Window )

function Toggle:Constructor()
	Turbine.UI.Window.Constructor( self );

	-- legacy fix
	if not (Settings.ToggleLeft) then
		Settings.ToggleLeft = tostring(Turbine.UI.Display.GetWidth()-55);
		Settings.ToggleTop = "310";
	end

	self:SetPosition( Settings.ToggleLeft, Settings.ToggleTop );
	self:SetSize(35,35);
	self:SetZOrder(70);
	self:SetVisible( true );


	self.button = Turbine.UI.Control();
	self.button:SetParent(self);
	self.button:SetPosition(0,0);
	self.button:SetSize(32,32);
	self:SetOpacity(1);
	self.button:SetBlendMode( Turbine.UI.BlendMode.AlphaBlend );
	self.button:SetBackground("Carentil/LOTRivia/Resources/img/icon.jpg");
	self.button.MouseEnter = function(sender,args)
		self.button:SetBackground("Carentil/LOTRivia/Resources/img/icon.jpg");
		self:SetOpacity(1);
	end
	self.button.MouseLeave = function(sender,args)
		self.button:SetBackground("Carentil/LOTRivia/Resources/img/icon.jpg");
		self:SetOpacity(.7);
	end
	self.button.MouseDown = function( sender, args )
		if(args.Button == Turbine.UI.MouseButton.Left) then
			sender.dragStartX = args.X;
			sender.dragStartY = args.Y;
			sender.dragging = true;
			sender.dragged = false;
			self:SetBackColor( Turbine.UI.Color(0,0,1,0) );
		end
	end
	self.button.MouseUp = function( sender, args )
		if (args.Button == Turbine.UI.MouseButton.Left) then
			if (sender.dragging) then
				sender.dragging = false;
			end
			if not sender.dragged then
				myGame:SetVisible( not myGame:IsVisible() );
				myScores:SetVisible( myGame:IsVisible() );
				myOptions:SetVisible( false );
			end
			self:SetBackColor( Turbine.UI.Color(0,0,0,0) );
			Settings.ToggleLeft = self:GetLeft();
			Settings.ToggleTop = self:GetTop();
		end
	end
	self.button.MouseMove = function(sender,args)
		if ( sender.dragging ) then
			local left, top = self:GetPosition();
			self:SetPosition( left + ( args.X - sender.dragStartX ), top + args.Y - sender.dragStartY );
			sender:SetPosition( 0, 0 );
			sender.dragged = true;
			-- checks to restrict moving outside the screen space
			if (self:GetLeft() > Turbine.UI.Display.GetWidth() - 35) then
				self:SetLeft(Turbine.UI.Display.GetWidth() - 35);
			end
			if (self:GetLeft() < 0) then
				self:SetLeft(0);
			end
			if (self:GetTop() > Turbine.UI.Display.GetHeight() - 35) then
				self:SetTop(Turbine.UI.Display.GetHeight() - 35);
			end
			if (self:GetTop() < 0) then
				self:SetTop(0);
			end
		end
	end
end
