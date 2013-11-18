import "Turbine.UI";
import "Turbine.UI.Lotro";
import "Carentil.LOTRivia.DropDown";
import "Carentil.LOTRivia.Type";
import "Carentil.LOTRivia.Class";
import "Carentil.LOTRivia.Resources.Questions";

--[[

	LOTrivia 1.0
	Written by Carentil of Windfola
	email: lotrocare@gmail.com

	A Plug In for hosting trivia games in
	Lord Of The Rings Online

  ]]--


  --[[

	To-Do List:
		- build the game window
			- needs:
				question display
				answer display
				send question control
					-clicking starts timer and sets update event
				listbox displaying current answers from people in order received
					-clicking will set a background color for highlighting purposes
				control to "accept answer"
					-will send to channel
					-disables timer update event
				send rules button

  ]]--


	-- Initialize plugin constants


	lotrivia = {}
	lotrivia.config = {}
	lotrivia.version = "1.0"

	-- Initialize base configuration

	lotrivia.config.sendToChannel = "Kinship"
	lotrivia.config.questionsPerRound = 15
	lotrivia.config.timePerQuestion = 30
	lotrivia.config.timed = true
	lotrivia.config.showRules = true


	function ltprint(text)
		Turbine.Shell.WriteLine("<rgb=#A000FF>LOTRivia:</rgb> <rgb=#40FFFF>" .. text .. "</rgb>")
	end

	-- look for stored config to override base

		-- todo

	local helptext = [[Commands
 /lt help -- this message
 /lt guesses -- lists the guesses made on the current question
 /lt options -- shows the options window
 /lt resetanswers -- clears answers from all players for the current question
 /lt show -- shows game windows (if you close one by accident)]]

	local creditstext = [[written by Carentil of Windfola
Dropdown Library by Galuhad
Questions collected by multiple members of The Oathsworn of Windfola
Books written by J.R.R. Tolkien
Movies directed by Peter Jackson
Ring forged by Sauron

Report Bugs on LotroInterface.com
]]

	-- Load saved configuration

	function LT_loadOptions(LT_loaded)

		if (LT_loaded == nil) then
			return
		end

		lotrivia.config.sendToChannel = LT_loaded[1]
		lotrivia.config.questionsPerRound = LT_loaded[2]
		lotrivia.config.timePerQuestion = LT_loaded[3]
		lotrivia.config.timed = LT_loaded[4]
		lotrivia.config.showRules = LT_loaded[5]
	end

	function LT_saveOptions()
		local LT_saveData = {
			lotrivia.config.sendToChannel,
			lotrivia.config.questionsPerRound,
			lotrivia.config.timePerQuestion,
			lotrivia.config.timed,
			lotrivia.config.showRules }
		Turbine.PluginData.Save( Turbine.DataScope.Account, "LOTRiviaSettings", LT_saveData )
		ltprint("Options saved.")
	end

	Turbine.PluginData.Load( Turbine.DataScope.Account, "LOTRiviaSettings", LT_loadOptions)

	-- Set up data stores
	local LT_storedAnswers = {}
	local LT_playerScores = {}
	local LT_questionWinners = {}
	local LT_UsedQuestions = {}
	local LT_currentQuestion = ""
	local LT_currentAnswer = ""
	local LT_currentCommentary = ""
	local LT_haveStoredAnswers = false
	local LT_questionActive = false
	local LT_channelNames = {"Kinship","Fellowship","Raid","Officer","Say","Regional","Roleplay","UserChat1","UserChat1","UserChat2","UserChat3","UserChat4"}
	local LT_announceAll = ""
	local LT_announceTopThree = ""


	LT_playerScores["Joeschmoe"] = 9
	LT_playerScores["KimiaKane"] = 7
	LT_playerScores["Carentil"] = 1
	LT_playerScores["Rotifano"] = 4
	LT_playerScores["Shockforwords"] = 6
	LT_playerScores["Nimdollas"] = 4
	LT_playerScores["Argonauts"] = 6
	LT_playerScores["Meriaegar"] = 3
	LT_playerScores["Versus"] = 7
	LT_playerScores["OscarMike"] = 4
	LT_playerScores["Drudgeoverseer"] = 6
	LT_playerScores["Fenrithnir"] = 5

	-- Set up a table of color codes for colorizing ordered results
	--
	LT_scoreColor = {}
	LT_scoreColor[1] = "<rgb=#FFD000>"
	LT_scoreColor[2] = "<rgb=#C0D0FF>"
	LT_scoreColor[3] = "<rgb=#BF8F2F>"
	LT_scoreColor[4] = "<rgb=#7F7F7F>"
	LT_tieColor =  "<rgb=#00D0FF>"

	LT_color_gold = Turbine.UI.Color(1,.8,.4)

	-- initialize options windows

	optionsWindow=class(Turbine.UI.Lotro.Window);

	function optionsWindow:Constructor()

		Turbine.UI.Lotro.Window.Constructor(self);

		self:SetSize(300,400);
		self:SetPosition(30,Turbine.UI.Display:GetHeight()/2-100);
		self:SetText("LOTRivia Options");

		-- todo: add an option for how many questionsPerRound

		self.LT_timed_cb = Turbine.UI.Lotro.CheckBox()

		self.LT_timed_cb:SetParent(self);
		self.LT_timed_cb:SetMultiline(false);
		self.LT_timed_cb:SetPosition(20,40);
		self.LT_timed_cb:SetSize(280,20);
		self.LT_timed_cb:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.LT_timed_cb:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.LT_timed_cb:SetText(" Timed questions?");

		-- Timer Length Control
		self.LT_timeperq_tb = Turbine.UI.Lotro.TextBox();
		self.LT_timeperq_tb:SetParent(self);
		self.LT_timeperq_tb:SetMultiline(false);
		self.LT_timeperq_tb:SetEnabled(true);
		self.LT_timeperq_tb:SetPosition(20,68);
		self.LT_timeperq_tb:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.LT_timeperq_tb:SetSize(30,20);
		self.LT_timeperq_tb:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);

		-- Timer Length Label
		self.LT_timeperq_label = Turbine.UI.Label();
		self.LT_timeperq_label:SetParent(self);
		self.LT_timeperq_label:SetMultiline(false);
		self.LT_timeperq_label:SetEnabled(true);
		self.LT_timeperq_label:SetPosition(50,68);
		self.LT_timeperq_label:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.LT_timeperq_label:SetSize(220,20);
		self.LT_timeperq_label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.LT_timeperq_label:SetText(" Timer length (seconds)");



		-- Questions Per Round Control
		self.LT_questionsperround_tb = Turbine.UI.Lotro.TextBox();
		self.LT_questionsperround_tb:SetParent(self);
		self.LT_questionsperround_tb:SetMultiline(false);
		self.LT_questionsperround_tb:SetEnabled(true);
		self.LT_questionsperround_tb:SetPosition(20,96);
		self.LT_questionsperround_tb:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.LT_questionsperround_tb:SetSize(30,20);
		self.LT_questionsperround_tb:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);

		-- Questions Per Round Label
		self.LT_questionsperround_label = Turbine.UI.Label();
		self.LT_questionsperround_label:SetParent(self);
		self.LT_questionsperround_label:SetMultiline(false);
		self.LT_questionsperround_label:SetEnabled(true);
		self.LT_questionsperround_label:SetPosition(50,96);
		self.LT_questionsperround_label:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.LT_questionsperround_label:SetSize(220,20);
		self.LT_questionsperround_label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.LT_questionsperround_label:SetText(" Questions per round");


		-- Channel Selection Control
		self.LT_channelselection = DropDown.Create(LT_channelNames);
		self.LT_channelselection:SetParent(self);
		self.LT_channelselection:SetPosition(20,144)
		self.LT_channelselection:SetVisible(true);
		self.LT_channelselection:SetText(lotrivia.config.sendToChannel);

		-- Channel Selection Label
		self.LT_channelselection_label = Turbine.UI.Label();
		self.LT_channelselection_label:SetParent(self);
		self.LT_channelselection_label:SetMultiline(false);
		self.LT_channelselection_label:SetEnabled(true);
		self.LT_channelselection_label:SetPosition(20,124);
		self.LT_channelselection_label:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
		self.LT_channelselection_label:SetSize(220,20);
		self.LT_channelselection_label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.LT_channelselection_label:SetText("Send To Channel:");


		-- PLugin Title Label
		self.LT_PluginTitle_label = Turbine.UI.Label();
		self.LT_PluginTitle_label:SetParent(self);
		self.LT_PluginTitle_label:SetMultiline(false);
		self.LT_PluginTitle_label:SetEnabled(true);
		self.LT_PluginTitle_label:SetPosition(20,175);
		self.LT_PluginTitle_label:SetFont( Turbine.UI.Lotro.Font.TrajanPro20 );
		self.LT_PluginTitle_label:SetFontStyle( Turbine.UI.FontStyle.Outline )
		self.LT_PluginTitle_label:SetOutlineColor( Turbine.UI.Color( .8, .7, 0 ) )
		self.LT_PluginTitle_label:SetForeColor( Turbine.UI.Color( 1, .8, 0 ) )
		self.LT_PluginTitle_label:SetSize(260,30);
		self.LT_PluginTitle_label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.LT_PluginTitle_label:SetText("LOTRivia " .. lotrivia.version);

		-- Credits Label
		self.LT_Credits_label = Turbine.UI.Label();
		self.LT_Credits_label:SetParent(self);
		self.LT_Credits_label:SetMultiline(true);
		self.LT_Credits_label:SetEnabled(true);
		self.LT_Credits_label:SetPosition(20,200);
		self.LT_Credits_label:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 );
		self.LT_Credits_label:SetSize(260,140);
		self.LT_Credits_label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.LT_Credits_label:SetText(creditstext);

		-- Save Button
		self.LT_Options_Ok_button = Turbine.UI.Lotro.Button();
		self.LT_Options_Ok_button:SetParent(self);
		self.LT_Options_Ok_button:SetHeight(30);
		self.LT_Options_Ok_button:SetWidth(140);
		self.LT_Options_Ok_button:SetText("Save Settings");
		self.LT_Options_Ok_button:SetPosition(80,360);
		self.LT_Options_Ok_button:SetVisible(true)

		-- When the timed_cb control is unchecked, the text control for timer length
		-- also needs to be disabled.
		--
		self.LT_timed_cb.CheckedChanged = function(sender,args)
			-- Set/Unset enabled flag of timeperq
			if self.LT_timed_cb:IsChecked() then
				self.LT_timeperq_tb:SetEnabled(true)
				self.LT_timeperq_label:SetForeColor(Turbine.UI.Color(1,1,1))
			else
				self.LT_timeperq_tb:SetEnabled(false)
				self.LT_timeperq_label:SetForeColor(Turbine.UI.Color(.2,.2,.2))
			end
		end

		-- Define action for Save Settings buttons
		--
		self.LT_Options_Ok_button.MouseUp = function(sender,args)

			-- save timed option
			lotrivia.config.timed = self.LT_timed_cb:IsChecked();

			-- save timer length choice
			if (tonumber(self.LT_timeperq_tb:GetText()) ~= nil) then
				lotrivia.config.timePerQuestion = tonumber( self.LT_timeperq_tb:GetText() );
			end
			-- save questions per round choice
			if (tonumber(self.LT_questionsperround_tb:GetText()) ~= nil) then
				lotrivia.config.questionsPerRound = tonumber( self.LT_questionsperround_tb:GetText() );
			end

			-- save channel choice option
			lotrivia.config.sendToChannel = self.LT_channelselection:GetText();
			self:SetVisible(false)
			LT_saveOptions();
		end

		function self:Closed( sender, args )
			ltprint("options closed")
				-- Nothing to do here
		end

		-- hide the options window
		--
		self:SetVisible(false);
	end



	-- scores windows class
	--
	scoresWindow = class(Turbine.UI.Lotro.Window);

	function scoresWindow:Constructor()
		Turbine.UI.Lotro.Window.Constructor(self);

		self:SetPosition(Turbine.UI.Display:GetWidth()-350,Turbine.UI.Display:GetHeight()/2-300);
		self:SetText("LOTRivia Scores");

		-- define child Elements
		self.headerText = Turbine.UI.Label()
		self.headerText:SetSize(240,20)
		self.headerText:SetPosition(16,34)
		self.headerText:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 )
		self.headerText:SetForeColor( Turbine.UI.Color(0,.8,.8) )
		self.headerText:SetBackColor(Turbine.UI.Color(.2,.1,.6));

		self.headerText:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
		self.headerText:SetText( "Click A Player To Edit Score" )
		self.headerText:SetVisible( true )
		self.headerText:SetParent( self )

		self.scoresListBox = Turbine.UI.ListBox();

		self.scoresListBox:SetParent(self);
		self.scoresListBox:SetSize(240,280);
		self.scoresListBox:SetPosition(16,58);
	 --self.scoresListBox:SetBackColor(Turbine.UI.Color(.1,.1,.1));

		-- Bind a vertical scrollbar to the listbox
		self.VScroll = Turbine.UI.Lotro.ScrollBar();
		self.VScroll:SetOrientation(Turbine.UI.Orientation.Vertical);
		self.VScroll:SetParent(self);
		self.VScroll:SetPosition(self:GetWidth()-54,58);
		self.VScroll:SetWidth(12);
		self.VScroll:SetHeight(self.scoresListBox:GetHeight());
		self.VScroll:SetVisible(true);
		self.scoresListBox:SetVerticalScrollBar(self.VScroll);

		-- Send Scores Button
		self.AnnounceAll_button = Turbine.UI.Lotro.Button();
		self.AnnounceAll_button:SetParent(self);
		--self.AnnounceAll_button:SetHeight(30);
		self.AnnounceAll_button:SetWidth(110);
		self.AnnounceAll_button:SetText("Announce All");
		self.AnnounceAll_button:SetPosition(30,360);
		self.AnnounceAll_button:SetVisible(true)

		-- Send Top 3 Scores Button
		self.Announce3_button = Turbine.UI.Lotro.Button();
		self.Announce3_button:SetParent(self);
		--self.Announce3_button:SetHeight(30);
		self.Announce3_button:SetWidth(60);
		self.Announce3_button:SetText("Top 3");
		self.Announce3_button:SetPosition(30,360);
		self.Announce3_button:SetVisible(true)

		self.AnnounceAll_button.MouseUp = function(sender,args)
			ltprint("Announce all")
		end

		self.Announce3_button.MouseUp = function(sender,args)
			ltprint("announce top three")
		end

		self:SetVisible(true);
		self:SetSize(270, 400);
		self:SetMaximumSize(400,800);
		self:SetMinimumSize(270,200);
		self:SetResizable(true);

		scoresWindow.SizeChanged = function(sender,args)

			local width, height = self:GetSize();

			-- Resize child elements
			self.headerText:SetSize(width-32,20)
			self.scoresListBox:SetSize(width-32,height-98);
			self.AnnounceAll_button:SetPosition(30,height-32);
			self.Announce3_button:SetPosition(width-90,height-32);
			-- alter elements in listbox
			--
			for i=1,self.scoresListBox:GetItemCount() do
				local listItem =  self.scoresListBox:GetItem(i)
				listItem:SetWidth(width-70)
			end

			-- resize scrollbar
			self.VScroll:SetPosition(width-34,58);
			self.VScroll:SetHeight(height-98);
		end

	end


			-- Edit Player window class
	--
	editWindow = class(Turbine.UI.Lotro.Window);

	function editWindow:Constructor()
		Turbine.UI.Lotro.Window.Constructor(self);

		self:SetPosition(Turbine.UI.Display:GetWidth()-450,Turbine.UI.Display:GetHeight()/2-250);
		self:SetText("Edit Score");
		self:SetSize(300, 130);
		self:SetResizable(false);

		self.originalScore = 6;
		-- define child Elements

		self.headerText = Turbine.UI.Label()
		self.headerText:SetSize(260,20)
		self.headerText:SetPosition(18,34)
		self.headerText:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 )
		self.headerText:SetForeColor( Turbine.UI.Color(1,1,1) )
		self.headerText:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
		self.headerText:SetMultiline( true )
		--self.headerText:SetBackColor( Turbine.UI.Color(.2, .2, .2) )
		self.headerText:SetText( "Use + and - to adjust player's score" )
		self.headerText:SetVisible( true )
		self.headerText:SetParent( self )

		self.playerName = Turbine.UI.Label()
		self.playerName:SetSize(180,20)
		self.playerName:SetPosition(18,64)
		self.playerName:SetFont( Turbine.UI.Lotro.Font.TrajanPro18 )
		self.playerName:SetForeColor( Turbine.UI.Color(1,1,1) )
		self.playerName:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
		self.playerName:SetMultiline( false )
		--self.playerName:SetBackColor( Turbine.UI.Color(.2, .2, .2) )
		self.playerName:SetText( "Versus" )
		self.playerName:SetVisible( true )
		self.playerName:SetParent( self )

		self.playerScore = Turbine.UI.Label()
		self.playerScore:SetSize(40,20)
		self.playerScore:SetPosition(200,64)
		self.playerScore:SetFont( Turbine.UI.Lotro.Font.TrajanPro18 )
		self.playerScore:SetForeColor( LT_color_gold )
		self.playerScore:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
		self.playerScore:SetMultiline( false )
		--self.playerScore:SetBackColor( Turbine.UI.Color(.2, .2, .2) )
		self.playerScore:SetText( LT_playerScores[self.playerName:GetText()] )
		self.playerScore:SetVisible( true )
		self.playerScore:SetParent( self )

		-- Increment control
		self.increment_button = Turbine.UI.Control();
		self.increment_button:SetParent(self);
		self.increment_button:SetBackground("Carentil/LOTRivia/Resources/inc.jpg");
		self.increment_button:SetSize(19,18);
		self.increment_button:SetPosition(245,64);
		self.increment_button:SetVisible(true)

		-- Decrement control
		self.decrement_button = Turbine.UI.Control();
		self.decrement_button:SetParent(self);
		self.decrement_button:SetBackground("Carentil/LOTRivia/Resources/dec.jpg");
		self.decrement_button:SetSize(19,18);
		self.decrement_button:SetPosition(270,64);
		self.decrement_button:SetVisible(true)

		-- Revert Button
		self.revertButton = Turbine.UI.Lotro.Button();
		self.revertButton:SetParent(self);
		self.revertButton:SetHeight(30);
		self.revertButton:SetWidth(120);
		self.revertButton:SetText("Revert Score");
		self.revertButton:SetPosition(30,92);
		self.revertButton:SetVisible(true)

		-- Save Button
		self.saveButton = Turbine.UI.Lotro.Button();
		self.saveButton:SetParent(self);
		self.saveButton:SetHeight(30);
		self.saveButton:SetWidth(120);
		self.saveButton:SetText("Save Score");
		self.saveButton:SetPosition(152,92);
		self.saveButton:SetVisible(true)



		self.increment_button.MouseUp = function(sender,args)
			LT_playerScores[self.playerName:GetText()] = tonumber(LT_playerScores[self.playerName:GetText()])+1
			self.playerScore:SetText( LT_playerScores[self.playerName:GetText()] )
		end

		self.decrement_button.MouseUp = function(sender,args)
			LT_playerScores[self.playerName:GetText()] = tonumber(LT_playerScores[self.playerName:GetText()])-1
			self.playerScore:SetText( LT_playerScores[self.playerName:GetText()] )
		end

		self.revertButton.MouseUp = function(sender,args)
			LT_playerScores[self.playerName:GetText()] = tonumber(self.originalScore)
			self.playerScore:SetText( tonumber(self.originalScore) )
		end

		self.saveButton.MouseUp = function(sender,args)
			myScores:updateList()
			self:SetVisible(false)
		end

		-- This window should have a high Z order to pop over background windows
		self:SetZOrder(50);
		self:SetVisible(false);
	end











	-- Instantiate Windows
	myOptions = optionsWindow();
	myScores = scoresWindow();
	myEdit = editWindow();



	-- Announce load to chat window

	Turbine.Shell.WriteLine("<rgb=#A000FF>LOTRivia Version ".. lotrivia.version .. " loaded.</rgb>")
	ltprint("/lt help for commands")

	LT_Command = Turbine.ShellCommand()

	function LT_Command:GetHelp()
		return helptext
	end

	function LT_Command:GetShortHelp()
		return helptext
	end

	function LT_Command:Execute(cmd,args)

		if (args == "help") then
			ltprint(helptext)


		elseif (args == "") then
			ltprint(helptext)


		elseif (args == "guesses") then

			if (LT_haveStoredAnswers) then
				ltprint("Showing answers")

				for k,v in pairs(LT_storedAnswers) do
					Turbine.Shell.WriteLine("<rgb=#40FF40>" .. k .. "</rgb>:  <rgb=#FFC040>" .. v .. "</rgb>")
				end

			else
				ltprint("No guesses found.")
			end


		elseif (args=="resetanswers") then
			LT_resetAnswers()
			ltprint("Current question answers cleared.")


		elseif (args=="options") then
			LT_showOptions()

		elseif (args=="pq") then
			ltprint( pickQuestion() )

		elseif (args=="save") then
			LT_saveOptions()

		elseif (args=="load") then
		ltprint("trying to load data")
			Turbine.PluginData.Load( Turbine.DataScope.Account, "LOTRiviaSettings", LT_loadOptions)

		elseif (args=="show") then
			myScores:SetVisible(true);

		elseif (args=="sort") then
			myScores:updateList();

		else
			ltprint( "\"" .. args .. "\" not a valid command, Try /lt help." )
		end

	end

	Turbine.Shell.AddCommand( "lotrivia;lt", LT_Command)







	-- Parse received chat

	function Turbine.Chat.Received(chatfunc, chatargs)
		local msgKey = ""
		local msgVal = ""
		local currMessage = ""
		local currType = 0
		local currSender = ""

		for msgKey,msgVal in pairs(chatargs) do

			if (msgKey=="Message") then


				-- Note: Kinship messages  also
				-- include login notifications which do
				-- NOT start with "[Kinship]"
				local channelNameStart,channelNameEnd = string.find(tostring(msgVal),"%[".. lotrivia.config.sendToChannel .."%]")

				if (channelNameStart ~= nil ) then
					-- The current text was from our trivia channel

					-- Strip out any leading text (timestamps, if there) the channel name, and eol
					local channelStrippedMessage = string.sub(tostring(msgVal),channelNameEnd+2)
					channelStrippedMessage = string.gsub(channelStrippedMessage,"\n",'')

					-- Now, the message looks something like this:
					-- <Select:IID:0x0206000000FFFFFFF>Joeschmoe<\Select>: Message Text Here"

					-- Remove XML elements
					channelStrippedMessage = string.gsub(channelStrippedMessage, "<[^>]+>",'')

					-- Grab sender and message
					currSender,currMessage = string.match(channelStrippedMessage,"(%a+):%s(.+)")

					-- Save the sender's message but only if they don't currently have one stored
					if (LT_storedAnswers[currSender] == nil) then
						LT_storedAnswers[currSender] = currMessage
						LT_haveStoredAnswers = true
					end

				end

			elseif (msgKey=="ChatType") then
				currType=tonumber(msgVal)
			end


		end

	end


	function LT_resetAnswers()
		LT_storedAnswers = {}
		LT_haveStoredAnswers = false
	end

	function pickQuestion()
		local questionNumber = math.random(#LT_Question)
		questionNumber = nextFree(questionNumber)
		ltprint("Next free question: " .. questionNumber)
		return questionNumber
	end

	function nextFree(x)
		-- Get the next free question from a passed number.
		-- If the question has been used, it will be incremented.
		-- If the increment surpasses the question pool, it will wrap around.
		if (LT_UsedQuestions[x] ~= nil) then
			x = x+1
			if ( x > #LT_Question ) then
				x = 1
			end
		else
			return x
		end
		nextFree(x)
		return x
	end

	function LT_showOptions()

		-- Change options to match config

		myOptions.LT_timed_cb:SetChecked( false )

		if ( lotrivia.config.timed ) then
			myOptions.LT_timed_cb:SetChecked( true )
		end

		myOptions.LT_timeperq_tb:SetText( lotrivia.config.timePerQuestion );
		myOptions.LT_questionsperround_tb:SetText( lotrivia.config.questionsPerRound );
		myOptions:SetVisible( true )
	end


	function scoresWindow:updateList()

		local scoreRL = {}

		if (#LT_playerScores ~= nil) then


			-- Remove the existing list entries
			--
			self.scoresListBox:ClearItems()

			-- Add entries
			--
			for name,score in pairs(LT_playerScores) do
				local tmpItem = Turbine.UI.Label()

				tmpItem:SetSize(200,24)
				tmpItem:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
				tmpItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleRight )
				tmpItem:SetForeColor( LT_color_gold )
				local labelText = "  " ..name .. "   " .. score
				scoreRL[labelText] = score
				tmpItem:SetText( labelText )
				function tmpItem:MouseUp(sender,args)
					playerEdit(name)
				end
				self.scoresListBox:AddItem(tmpItem)
			end


			-- Sort the elements in the listbox
			--
			self.scoresListBox:Sort(
				function(elem1,elem2)
					if scoreRL[elem1:GetText()] > scoreRL[elem2:GetText()] then return true
				end
			end)

			-- Update the AnnounceAll and AnnounceTopThree strings

			local sortedScores = {}
			local i=1

			for name,score in pairs(LT_playerScores) do
				sortedScores[i] = {name,score, ""};
				i=i+1;
			end


			table.sort(sortedScores, cmpScore)

			-- Add tie markers to the table as well
			for i=1,#sortedScores do
				if (i>1 and i<#sortedScores and sortedScores[i][2]==sortedScores[i+1][2]) then
					 sortedScores[i][3] = LT_tieColor .. " (tie)</rgb>"
					 sortedScores[i+1][3] = LT_tieColor .. " (tie)</rgb>"
				end
			end


			LT_announceAll = ""
			LT_announceTopThree = ""

			ltprint("score count: " .. #sortedScores)
			if (#sortedScores) then
				for i=1,#sortedScores do
					LT_announceAll = LT_announceAll ..
					LT_scoreColor[1] ..  "[" .. sortedScores[i][1] .. ":"  .. sortedScores[i][2] .. "]</rgb> "
				end
			else
				LT_announceAll = "No points awarded."
			end


			if (#sortedScores >2) then
				LT_announceTopThree =
				LT_scoreColor[1] ..  "[" .. sortedScores[1][1] .. ":"  .. sortedScores[1][2] .. "</rgb>" .. sortedScores[1][3] .. LT_scoreColor[1] .. "]</rgb>" ..
				LT_scoreColor[2] .. " [" ..	sortedScores[2][1] .. ":"  .. sortedScores[2][2] .. "</rgb>" .. sortedScores[2][3] .. LT_scoreColor[2] .. "]</rgb>" ..
				LT_scoreColor[3] .. " [" ..	sortedScores[3][1] .. ":"  .. sortedScores[3][2] .. "</rgb>" .. sortedScores[3][3] .. LT_scoreColor[3] .. "]</rgb>"


				-- If our score for fourth+ place are the same as the third place,
				-- include them as a tie
				if (#sortedScores >3) then
					for i=4,#sortedScores do
						if (sortedScores[i][2] == sortedScores[3][2]) then
							LT_announceTopThree = LT_announceTopThree ..
								LT_scoreColor[3] .. " [" ..	sortedScores[i][1] .. ":"  .. sortedScores[i][2] .. "</rgb>" .. sortedScores[i][3] .. LT_scoreColor[3] .. "]</rgb>"
						end
					end
				end


			else
				LT_announceTopThree = LT_announceAll
			end

			LT_announceAll = "Scores: " .. LT_announceAll
			LT_announceTopThree = "Top Three Scorers: " .. LT_announceTopThree

			ltprint("top three: " .. LT_announceTopThree)
			ltprint("all scores: " .. LT_announceAll)

		end
	end


	-- function to compare scores when sorting out the top ranks
	--
	function cmpScore(a,b)
		if (a[2] > b[2]) then
			return true
		end
	end



	function playerEdit(name)
		myEdit.playerName:SetText( name );
		myEdit.playerScore:SetText( LT_playerScores[name] );
		myEdit.originalScore = LT_playerScores[name];
		myEdit:SetVisible(true);
		ltprint("Editing "..name)
	end