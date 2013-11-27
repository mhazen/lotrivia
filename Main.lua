import "Turbine.UI";
import "Turbine.UI.Lotro";
import "Carentil.LOTRivia.DropDown";
import "Carentil.LOTRivia.Turbine.Type";
import "Carentil.LOTRivia.Turbine.Class";
import "Carentil.LOTRivia.ToggleWindow";
import "Carentil.LOTRivia.Resources.Questions";

--[[
	LOTrivia
	Written by Carentil of Windfola
	email: lotrocare@gmail.com

	A Plug In for hosting trivia games in
	Lord Of The Rings Online

	Thanks to Chiran, Garan, and Galuhad for the code
	resources they provided which made this work easier.
--]]


--[[
	To-Do List:

	Known Bugs:
--]]


-- Debug flag: Just to make my life simpler
--
debug = false

	-- Initialize plugin constants
	--
	lotrivia = {}
	lotrivia.version = "1.0.28"
	lotrivia.majorVersion = "1.0"


	-- Local print wrapper
	--
	function ltprint(text)
		Turbine.Shell.WriteLine(ltColor.purple .. "LOTRivia:</rgb> " .. ltColor.cyan .. text .. "</rgb>")
	end

	-- Standard add and remove callback functions
	--
	function AddCallback(object, event, callback)
		if (object[event] == nil) then
			object[event] = callback;
		else
			if (type(object[event]) == "table") then
				table.insert(object[event], callback);
			else
				object[event] = {object[event], callback};
			end
		end
		return callback;
	end

	function RemoveCallback(object, event, callback)
		if (object[event] == callback) then
			object[event] = nil;
		else
			if (type(object[event]) == "table") then
				local size = table.getn(object[event]);
				for i = 1, size do
					if (object[event][i] == callback) then
						table.remove(object[event], i);
						break;
					end
				end
			end
		end
	end

	-- Basic timer class from LotroInterface (Garan)
	--
	Timer = class( Turbine.UI.Control );
	function Timer:Constructor()
		Turbine.UI.Control.Constructor( self );
		self.EndTime=Turbine.Engine.GetGameTime();
		self.Repeat=false;

		self.SetTime=function(sender, numSeconds, setRepeat)
			numSeconds=tonumber(numSeconds);
			if numSeconds==nil or numSeconds<=0 then
				numSeconds=0;
			end
			self.EndTime=Turbine.Engine.GetGameTime()+numSeconds;
			self.Repeat=false; -- default
			self.NumSeconds=numSeconds;
			if setRepeat~=nil and setRepeat~=false then
				-- any non-false value will trigger a repeat
				self.Repeat=true;
			end
			self:SetWantsUpdates(true);
		end

		self.Update=function()
			if self.EndTime~=nil and Turbine.Engine.GetGameTime()>=self.EndTime then
				-- turn off timer to avoid firing again while processing
				self:SetWantsUpdates(false);
				-- fire whatever event you are trying to trigger
				if self.TimeReached~=nil then
					if type(self.TimeReached)=="function" then
						self.TimeReached();
					elseif type(self.TimeReached)=="table"  then
						for k,v in pairs(self.TimeReached) do
							if type(v)=="function" then
								v();
							end
						end
					end
				end

				if self.Repeat then
					self.EndTime=Turbine.Engine.GetGameTime()+self.NumSeconds;
					self:SetWantsUpdates(true);
				end
			end
		end
	end

	-- handler for plugin unload event
	--
	function unloadHandler()
		if (Settings.timed ) then
			RemoveCallback(Turbine.Chat, "Received", parseChat)
		end

		-- save the options
		saveOptions();

		-- Clear out global data
		_G.LT_Question = nil;
		_G.LT_Answer = nil;
		_G.LT_QuestionCommentary = nil;
	end

	-- Load saved configuration
	--
	function loadOptions(LT_loaded)

		local gwl = Turbine.UI.Display:GetWidth()/2-300
		local gwt= Turbine.UI.Display:GetHeight()/2-400

		-- configuration defaults
		--
		settingsDefaults = {
			channel = "Kinship",
			questionsPerRound = 15,
			timePerQuestion = 30,
			gameVisible = true,
			timed = true,
			showRules = true,
			gameWindowLeft = gwl,
			gameWindowTop = gwt,
			scoresWindowLeft = gwl+620,
			scoresWindowTop = gwt+10,
			ToggleTop = 400,
			ToggleLeft = Turbine.UI.Display.GetWidth()-55
		}

		Settings = Turbine.PluginData.Load( Turbine.DataScope.Account, "LOTRiviaSettings") or settingsDefaults
	end

	loadOptions();

	function saveOptions()
		-- Get the window positions
		Settings.gameVisible = myGame:IsVisible();
		Settings.gameWindowLeft = tonumber(myGame:GetLeft());
		Settings.gameWindowTop = tonumber(myGame:GetTop());
		Settings.scoresWindowLeft = tonumber(myScores:GetLeft());
		Settings.scoresWindowTop = tonumber(myScores:GetTop());
		Settings.ToggleTop = tonumber(myToggle:GetTop());
		Settings.ToggleLeft = tonumber(myToggle:GetLeft());

		Turbine.PluginData.Save( Turbine.DataScope.Account, "LOTRiviaSettings", Settings, function( status, errmsg )
			if ( status ) then
				ltprint("Options saved.");
			else
				ltprint("Options could not be saved: " .. errmsg )
			end
		end)
	end


	function setUpDataStores()
		storedAnswers = {}
		playerScores = {}
		questionId = 1
		usedQuestions = {}
		answeringPlayer = nil
		haveStoredAnswers = false
		gameActive = false
		questionActive = false
		countdownTime = 0;
	end

	setUpDataStores();

	-- returns a sorted list of channel names
	--
	function channelNames()
		local tmpTable= {}
		for k,v in pairs(channels) do
		tmpTable[#tmpTable+1] = k
		end
		table.sort(tmpTable)
		return tmpTable
	end

	channels = {
		["Kinship"] = {
					["channelId"] = Turbine.ChatType.Kinship ,
					["cmd"] = "/k ",
					},
		["Fellowship"] = {
					["cmd"] = "/f ",
					["channelId"] = Turbine.ChatType.Fellowship ,
					},
		["Raid"] = {
					["cmd"] = "/ra ",
					["channelId"] = Turbine.ChatType.Raid ,
					},
		["Officer"] = {
					["cmd"] = "/o ",
					["channelId"] = Turbine.ChatType.Officer ,
					},
		["Regional"] = {
					["cmd"] = "/regional ",
					["channelId"] = Turbine.ChatType.Regional ,
					},
		["UserChat 1"] = {
					["cmd"] = "/1 ",
					["channelId"] = Turbine.ChatType.UserChat1 ,
					},
		["UserChat 2"] = {
					["cmd"] = "/2 ",
					["channelId"] = Turbine.ChatType.UserChat2 ,
					},
		["UserChat 3"] = {
					["cmd"] = "/3 ",
					["channelId"] = Turbine.ChatType.UserChat3 ,
					},
		["UserChat 4"] = {
					["cmd"] = "/4 ",
					["channelId"] = Turbine.ChatType.UserChat4 ,
					}
		}


	announceAllText = ""
	announceTopThreeText = ""

	-- Set up a table of color codes for colorizing ordered results
	--
	scoreColor = {}
	scoreColor[1] = "<rgb=#FFD000>"
	scoreColor[2] = "<rgb=#C0D0FF>"
	scoreColor[3] = "<rgb=#BF8F2F>"
	scoreColor[4] = "<rgb=#7F7F7F>"
	tieColor =  "<rgb=#00D0FF>"

	ltColor = {}
	ltColor.purple = "<rgb=#AF00FF>"
	ltColor.orange = "<rgb=#FF6F00>"
	ltColor.cyan = "<rgb=#00CFFF>"

	LT_color_white = Turbine.UI.Color(1,1,1);
	LT_color_darkgray = Turbine.UI.Color(.1,.1,.1);
	LT_color_ltgray = Turbine.UI.Color(.7,.7,.7);
	LT_color_gold = Turbine.UI.Color(1,.8,.4);
	LT_color_goldOutline = Turbine.UI.Color( .7, .5, 0 );

	helpText = [[Commands
 /lt help -- this message
 /lt options -- shows the options window
 /lt show -- shows game windows (if you close one by accident)
 Plugin can be unloaded with /plugins "unload lotrivia".
 ----
 To play: Click "Start Game", and either Ask the chosen question, or skip it.
 To accept an answer from a player, click it in the "Current Guesses" panel and then click "Accept Answer."
 If no one answers in time, or you wish to cut a question short, click "Reveal Answer".]]

	creditsText = [[written by Carentil of Windfola. Uses Galuhad's Dropdown Library, and ToggleWindow from Chiran. Thanks to the members of LotroInterface.com for all of the feedback. Books written by J.R.R. Tolkien, Movies directed by Peter Jackson, Ring forged by Sauron.

Report Bugs on LotroInterface.com
]]

	rulesText = ltColor.purple .. "The Official LOTRivia Rules:</rgb>\n" .. ltColor.cyan ..
[[1. The quizmaster will ask a question. You must answer in this chat.
2. One answer per player per question. Your first answer is your final answer!
3. Accepting abbreviations or mispellings is up to the quizmaster's discretion.
4. The quizmaster may award extra points for harder questions.</rgb>
]]


-- Window Classes
--

	-- options window class
	--
	optionsWindow=class(Turbine.UI.Lotro.Window);

	function optionsWindow:Constructor()

		Turbine.UI.Lotro.Window.Constructor(self);

		self:SetSize(300,400);
		self:SetPosition(Turbine.UI.Display:GetWidth()/2-200,Turbine.UI.Display:GetHeight()/2-300);
		self:SetZOrder(40);
		self:SetText("LOTRivia Options");

		-- todo: add an option for how many questionsPerRound

		self.timedCheckbox = Turbine.UI.Lotro.CheckBox()

		self.timedCheckbox:SetParent(self);
		self.timedCheckbox:SetMultiline(false);
		self.timedCheckbox:SetPosition(20,40);
		self.timedCheckbox:SetSize(280,20);
		self.timedCheckbox:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.timedCheckbox:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.timedCheckbox:SetText(" Timed questions?");

		-- Timer Length Control
		self.timePerQuestion = Turbine.UI.Lotro.TextBox();
		self.timePerQuestion:SetParent(self);
		self.timePerQuestion:SetMultiline(false);
		self.timePerQuestion:SetEnabled(true);
		self.timePerQuestion:SetPosition(20,68);
		self.timePerQuestion:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.timePerQuestion:SetSize(30,20);
		self.timePerQuestion:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);

		-- Timer Length Label
		self.timePerQuestionLabel = Turbine.UI.Label();
		self.timePerQuestionLabel:SetParent(self);
		self.timePerQuestionLabel:SetMultiline(false);
		self.timePerQuestionLabel:SetEnabled(true);
		self.timePerQuestionLabel:SetPosition(50,68);
		self.timePerQuestionLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.timePerQuestionLabel:SetSize(220,20);
		self.timePerQuestionLabel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.timePerQuestionLabel:SetText(" Timer length (seconds)");

		-- Questions Per Round Control
		self.questionsPerRound = Turbine.UI.Lotro.TextBox();
		self.questionsPerRound:SetParent(self);
		self.questionsPerRound:SetMultiline(false);
		self.questionsPerRound:SetEnabled(true);
		self.questionsPerRound:SetPosition(20,96);
		self.questionsPerRound:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.questionsPerRound:SetSize(30,20);
		self.questionsPerRound:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);

		-- Questions Per Round Label
		self.questionsPerRoundLabel = Turbine.UI.Label();
		self.questionsPerRoundLabel:SetParent(self);
		self.questionsPerRoundLabel:SetMultiline(false);
		self.questionsPerRoundLabel:SetEnabled(true);
		self.questionsPerRoundLabel:SetPosition(50,96);
		self.questionsPerRoundLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
		self.questionsPerRoundLabel:SetSize(220,20);
		self.questionsPerRoundLabel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.questionsPerRoundLabel:SetText(" Questions per round");


		-- Channel Selection Control
		self.channelSelection = DropDown.Create(channelNames(), Settings.channel);
		self.channelSelection:SetParent(self);
		self.channelSelection:SetPosition(20,144)
		self.channelSelection:SetVisible(true);
		self.channelSelection:SetText(Settings.channel);

		-- Channel Selection Label
		self.channelSelection_label = Turbine.UI.Label();
		self.channelSelection_label:SetParent(self);
		self.channelSelection_label:SetMultiline(false);
		self.channelSelection_label:SetEnabled(true);
		self.channelSelection_label:SetPosition(20,124);
		self.channelSelection_label:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
		self.channelSelection_label:SetSize(220,20);
		self.channelSelection_label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.channelSelection_label:SetText("Send To Channel:");


		-- PLugin Title Label
		self.pluginTitleLabel = Turbine.UI.Label();
		self.pluginTitleLabel:SetParent(self);
		self.pluginTitleLabel:SetMultiline(false);
		self.pluginTitleLabel:SetEnabled(true);
		self.pluginTitleLabel:SetPosition(20,175);
		self.pluginTitleLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro20 );
		self.pluginTitleLabel:SetFontStyle( Turbine.UI.FontStyle.Outline )
		self.pluginTitleLabel:SetOutlineColor( LT_color_goldOutline )
		self.pluginTitleLabel:SetForeColor( LT_color_gold )
		self.pluginTitleLabel:SetSize(260,30);
		self.pluginTitleLabel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.pluginTitleLabel:SetText("LOTRivia " .. lotrivia.version);

		-- Credits Label
		self.creditsLabel = Turbine.UI.Label();
		self.creditsLabel:SetParent(self);
		self.creditsLabel:SetMultiline(true);
		self.creditsLabel:SetEnabled(true);
		self.creditsLabel:SetPosition(20,200);
		self.creditsLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 );
		self.creditsLabel:SetSize(260,140);
		self.creditsLabel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
		self.creditsLabel:SetText(creditsText);

		-- Save Button
		self.saveOptionsButton = Turbine.UI.Lotro.Button();
		self.saveOptionsButton:SetParent(self);
		self.saveOptionsButton:SetHeight(30);
		self.saveOptionsButton:SetWidth(140);
		self.saveOptionsButton:SetText("Save Settings");
		self.saveOptionsButton:SetPosition(80,360);
		self.saveOptionsButton:SetVisible(true)

		-- When the timed_cb control is unchecked, the text control for timer length
		-- also needs to be disabled.
		--
		self.timedCheckbox.CheckedChanged = function(sender,args)
			-- Set/Unset enabled flag of timeperq
			if self.timedCheckbox:IsChecked() then
				self.timePerQuestion:SetEnabled(true)
				self.timePerQuestionLabel:SetForeColor(Turbine.UI.Color(1,1,1))
			else
				self.timePerQuestion:SetEnabled(false)
				self.timePerQuestionLabel:SetForeColor(Turbine.UI.Color(.2,.2,.2))
			end
		end

		-- Define action for Save Settings buttons
		--
		self.saveOptionsButton.MouseUp = function(sender,args)

			-- save timed option
			Settings.timed = self.timedCheckbox:IsChecked();

			-- save timer length choice
			if isPositiveNumber( self.timePerQuestion:GetText() ) then
				Settings.timePerQuestion = tonumber( self.timePerQuestion:GetText() );
			else
				ltprint(ltColor.orange .. "That's not a valid number of seconds per question.")
				return;
			end

			-- save questions per round choice
			if isPositiveNumber(self.questionsPerRound:GetText()) then

				if ( tonumber( self.questionsPerRound:GetText() ) > #LT_Question ) then
					ltprint(ltColor.orange .. "You have set " .. Settings.questionsPerRound .. " questions per round, but you only have " .. #LT_Question .. " questions available. "  )
					return false
				end

				-- Don't allow setting the questions per round to less than we've already asked in the current game
				--
				if ( #usedQuestions > tonumber( self.questionsPerRound:GetText() ) ) then
					self.questionsPerRound:SetText(#usedQuestions);
					ltprint("Increasing questions per round to cover the number of questions already asked.")

					-- Complete the game
					myGame.resetGameWindow();
					ltprint("Game completed!");
					gameActive = false;
					questionActive = false;

					-- reset the Start Game button TextBox
					myGame.gamestateButton:SetText("Start Game");
				end


				Settings.questionsPerRound = tonumber( self.questionsPerRound:GetText() );

				-- Also update the panel
				myGame.questionsRemaining:SetText( Settings.questionsPerRound-#usedQuestions );

			else
				ltprint(ltColor.orange .. "That's not a valid number of questions per round.")
				return;
			end

			-- save channel choice option
			Settings.channel = self.channelSelection:GetText();

			-- update the game panel's Send Rules action to match the saved channel
			myGame.sendRulesAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,channels[Settings.channel]["cmd"] .. rulesText))

			self:SetVisible(false)
			saveOptions();
		end

		function self:Closed( sender, args )
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

		self:SetPosition( Settings.scoresWindowLeft, Settings.scoresWindowTop );
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
		self.scoresScrollbar = Turbine.UI.Lotro.ScrollBar();
		self.scoresScrollbar:SetOrientation(Turbine.UI.Orientation.Vertical);
		self.scoresScrollbar:SetParent(self);
		self.scoresScrollbar:SetPosition(self:GetWidth()-54,58);
		self.scoresScrollbar:SetWidth(12);
		self.scoresScrollbar:SetHeight(self.scoresListBox:GetHeight());
		self.scoresScrollbar:SetVisible(true);
		self.scoresListBox:SetVerticalScrollBar(self.scoresScrollbar);


		-- pseudo button for announce all
		self.announceAllText=Turbine.UI.Lotro.Quickslot();
		self.announceAllText:SetParent(self);
		self.announceAllText:SetSize(107,18);
		self.announceAllText:SetPosition(30,360);
		self.announceAllText:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
		self.announceAllText.ShortcutData=""; --save the alias text for later
		self.announceAllText:SetAllowDrop(false); -- turn off drag and drop so the user doesn't accidentally modify our button action
		self.announceAllText.DragDrop=function()
			local sc=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,"");
			sc:SetData(self.announceAllText.ShortcutData);
			self.announceAllText:SetShortcut(sc);
		end

		self.announceAllText.Icon=Turbine.UI.Control();
		self.announceAllText.Icon:SetParent(self);
		self.announceAllText.Icon:SetSize(107,18);
		self.announceAllText.Icon:SetPosition(30,360);
		self.announceAllText.Icon:SetZOrder(self.announceAllText:GetZOrder()+2);
		self.announceAllText.Icon:SetMouseVisible(false);
		self.announceAllText.Icon:SetBlendMode(Turbine.UI.BlendMode.Overlay);

		self.announceAllText.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announceAll.jpg")
		self.announceAllText.MouseEnter=function()
			self.announceAllText.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announceAll_sel.jpg")
		end
		self.announceAllText.MouseLeave=function()
			self.announceAllText.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announceAll.jpg")
		end
		self.announceAllText.MouseDown=function()
			self.announceAllText.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announceAll.jpg")
		end
		self.announceAllText.MouseUp=function()
			self.announceAllText.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announceAll_sel.jpg")
		end


		-- pseudo button for announce top 3
		--
		self.top3=Turbine.UI.Lotro.Quickslot();
		self.top3:SetParent(self);
		self.top3:SetSize(57,18);
		self.top3:SetPosition(30,360);
		self.top3:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
		self.top3.ShortcutData=""; --save the alias text for later
		self.top3:SetAllowDrop(false); -- turn off drag and drop so the user doesn't accidentally modify our button action
		self.top3.DragDrop=function()
			local sc=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,"");
			sc:SetData(self.top3.ShortcutData);
			self.top3:SetShortcut(sc);
		end

		self.top3.Icon=Turbine.UI.Control();
		self.top3.Icon:SetParent(self);
		self.top3.Icon:SetSize(57,18);
		self.top3.Icon:SetPosition(30,360);
		self.top3.Icon:SetZOrder(self.top3:GetZOrder()+2);
		self.top3.Icon:SetMouseVisible(false);
		self.top3.Icon:SetBlendMode(Turbine.UI.BlendMode.Overlay);

		self.top3.Icon:SetBackground("Carentil/LOTRivia/Resources/img/top3.jpg")
		self.top3.MouseEnter=function()
			self.top3.Icon:SetBackground("Carentil/LOTRivia/Resources/img/top3_sel.jpg")
		end
		self.top3.MouseLeave=function()
			self.top3.Icon:SetBackground("Carentil/LOTRivia/Resources/img/top3.jpg")
		end
		self.top3.MouseDown=function()
			self.top3.Icon:SetBackground("Carentil/LOTRivia/Resources/img/top3.jpg")
		end
		self.top3.MouseUp=function()
			self.top3.Icon:SetBackground("Carentil/LOTRivia/Resources/img/top3_sel.jpg")
		end


		self:SetVisible( Settings.gameVisible );
		self:SetSize(270, 400);
		self:SetMaximumSize(400,800);
		self:SetMinimumSize(270,200);
		self:SetResizable(true);

		scoresWindow.SizeChanged = function(sender,args)

			local width, height = self:GetSize();

			-- Resize child elements
			self.headerText:SetSize(width-32,20)
			self.scoresListBox:SetSize(width-32,height-98);
			self.announceAllText:SetPosition(30,height-32);
			self.announceAllText.Icon:SetPosition(30,height-32);

			self.top3:SetPosition(width-90,height-32);
			self.top3.Icon:SetPosition(width-90,height-32);

			-- alter elements in listbox
			--
			for i=1,self.scoresListBox:GetItemCount() do
				local listItem =  self.scoresListBox:GetItem(i)
				listItem:SetWidth(width-70)
			end

			-- resize scrollbar
			self.scoresScrollbar:SetPosition(width-34,58);
			self.scoresScrollbar:SetHeight(height-98);
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
		self.playerScore:SetText( playerScores[self.playerName:GetText()] )
		self.playerScore:SetVisible( true )
		self.playerScore:SetParent( self )

		-- Increment control
		self.increment_button = Turbine.UI.Control();
		self.increment_button:SetParent(self);
		self.increment_button:SetBackground("Carentil/LOTRivia/Resources/img/inc.jpg");
		self.increment_button:SetSize(19,18);
		self.increment_button:SetPosition(245,64);
		self.increment_button:SetVisible(true)

		-- Decrement control
		self.decrement_button = Turbine.UI.Control();
		self.decrement_button:SetParent(self);
		self.decrement_button:SetBackground("Carentil/LOTRivia/Resources/img/dec.jpg");
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
			playerScores[self.playerName:GetText()] = tonumber(playerScores[self.playerName:GetText()])+1
			self.playerScore:SetText( playerScores[self.playerName:GetText()] )
		end

		self.decrement_button.MouseUp = function(sender,args)
			playerScores[self.playerName:GetText()] = tonumber(playerScores[self.playerName:GetText()])-1
			self.playerScore:SetText( playerScores[self.playerName:GetText()] )
		end

		self.revertButton.MouseUp = function(sender,args)
			playerScores[self.playerName:GetText()] = tonumber(self.originalScore)
			self.playerScore:SetText( tonumber(self.originalScore) )
		end

		self.saveButton.MouseUp = function(sender,args)
			myScores:updateList()
			self:SetVisible(false)
			myScores:SizeChanged();
		end

		-- This window should have a high Z order to pop over background windows
		self:SetZOrder(50);
		self:SetVisible(false);
	end


	-- Class for the main game window
	--
	gameWindow = class(Turbine.UI.Lotro.Window)
	function gameWindow:Constructor()
		Turbine.UI.Lotro.Window.Constructor(self);

		self:SetPosition(Settings.gameWindowLeft, Settings.gameWindowTop )
		self:SetText("LOTRivia " .. lotrivia.majorVersion);
		self:SetSize(600, 600);

		-- plugin unload handler
		self.loaded=false;
		self.Update=function()
			if not self.loaded then
				self.loaded=true;
				Plugins["LOTRivia"].Unload = function(self,sender,args)
					unloadHandler();
				end
				self:SetWantsUpdates(false);
			end
		end

		-- set updates for window so it fires, once, when the plugin enters the run state
		self:SetWantsUpdates(true);

		-- define child Elements
		--
		-- question box header text
		self.currentQuestionLabel = Turbine.UI.Label()
		self.currentQuestionLabel:SetParent(self);
		self.currentQuestionLabel:SetSize(260,30)
		self.currentQuestionLabel:SetPosition(22,40)
		self.currentQuestionLabel:SetMultiline(false);
		self.currentQuestionLabel:SetForeColor( LT_color_gold )
		self.currentQuestionLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro20 );
		self.currentQuestionLabel:SetFontStyle( Turbine.UI.FontStyle.Outline )
		self.currentQuestionLabel:SetOutlineColor( LT_color_goldOutline )
		self.currentQuestionLabel:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft )
		--self.currentQuestionLabel:SetBackColor( Turbine.UI.Color(.2, .2, .2) )
		self.currentQuestionLabel:SetText( "Current Question" )
		self.currentQuestionLabel:SetVisible( true )

		-- current question text box
		--
		self.questionText = Turbine.UI.Label()
		self.questionText:SetSize(440,80)
		self.questionText:SetPosition(18,70)
		self.questionText:SetFont( Turbine.UI.Lotro.Font.TrajanPro18 )
		self.questionText:SetForeColor( Turbine.UI.Color(1,1,1) )
		self.questionText:SetTextAlignment( Turbine.UI.ContentAlignment.TopLeft)
		self.questionText:SetMultiline( true )
		self.questionText:SetBackColor( Turbine.UI.Color(0, 0, .3) )
		self.questionText:SetText( "The questions will be shown here before sending them to the channel. Use \"Start Game\" below to begin!" )
		self.questionText:SetVisible( true )
		self.questionText:SetParent( self )

		-- pseudo-button for ask question
		--
		self.askAlias=Turbine.UI.Lotro.Quickslot();
		self.askAlias:SetParent(self);
		self.askAlias:SetSize(117,18);
		self.askAlias:SetPosition(467,74);
		self.askAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
		self.askAlias.ShortcutData=""; --save the alias text for later
		self.askAlias:SetAllowDrop(false); -- turn off drag and drop so the user doesn't accidentally modify our button action
		self.askAlias.DragDrop=function()
			local sc=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,"");
			sc:SetData(self.askAlias.ShortcutData);
			self.askAlias:SetShortcut(sc);
		end

		self.askAlias.Icon=Turbine.UI.Control();
		self.askAlias.Icon:SetParent(self);
		self.askAlias.Icon:SetSize(117,18);
		self.askAlias.Icon:SetPosition(467, 74);
		self.askAlias.Icon:SetZOrder(self.askAlias:GetZOrder()+2);
		self.askAlias.Icon:SetMouseVisible(false);
		self.askAlias.Icon:SetBlendMode(Turbine.UI.BlendMode.Overlay);

		self.askAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/askquestion.jpg")
		self.askAlias.MouseEnter=function()
			self.askAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/askquestion_sel.jpg")
		end
		self.askAlias.MouseLeave=function()
			self.askAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/askquestion.jpg")
		end
		self.askAlias.MouseDown=function()
			self.askAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/askquestion.jpg")
		end
		self.askAlias.MouseUp=function()
			self.askAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/askquestion.jpg")

			if (gameActive) then
				-- We're in a game, and we're about to ask the next question.
				--
				questionActive=true;

				-- Clear any residual accept answer aliases
				self.acceptAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))

				-- Add the current question to the used questions pile
				usedQuestions[#usedQuestions+1] = questionId;

				if ( Settings.timed ) then
					-- Set up and start the countdown
					countdownTime = tonumber(Settings.timePerQuestion);
					AddCallback(myTimer,"TimeReached",timerEvent);
					myTimer:SetTime(1,true);
					self.timeRemaining:SetText(countdownTime);
				end

				-- Reset the stored answers and the listbox
				self.guessesListBox:ClearItems();
				storedAnswers = {}

				-- Set the Reveal Answer alias
				self.setReveal();
			else
				ltprint(ltColor.orange .. "You need to start a game before you can send a question.")
			end
		end

		-- Skip Question Button
		self.skipButton = Turbine.UI.Lotro.Button();
		self.skipButton:SetParent(self);
		self.skipButton:SetHeight(30);
		self.skipButton:SetWidth(120);
		self.skipButton:SetText("Skip Question");
		self.skipButton:SetPosition(467,104);
		self.skipButton:SetVisible(true)

		self.skipButton.MouseUp = function(sender,args)
			if (questionActive) then
				ltprint("Can't skip to the next question until you finish this one!")
			elseif (not gameActive) then
				return;
			else
				prepareQuestion();
			end
		end

		-- question box header text
		self.currentQuestionLabel = Turbine.UI.Label()
		self.currentQuestionLabel:SetParent(self);
		self.currentQuestionLabel:SetSize(260,30)
		self.currentQuestionLabel:SetPosition(22,40)
		self.currentQuestionLabel:SetMultiline(false);
		self.currentQuestionLabel:SetForeColor( LT_color_gold )
		self.currentQuestionLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro20 );
		self.currentQuestionLabel:SetFontStyle( Turbine.UI.FontStyle.Outline )
		self.currentQuestionLabel:SetOutlineColor( LT_color_goldOutline )
		self.currentQuestionLabel:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft )
		--self.currentQuestionLabel:SetBackColor( Turbine.UI.Color(.2, .2, .2) )
		self.currentQuestionLabel:SetText( "Current Question" )
		self.currentQuestionLabel:SetVisible( true )


		-- answer box header text
		self.answerLabel = Turbine.UI.Label()
		self.answerLabel:SetParent(self);
		self.answerLabel:SetSize(260,30)
		self.answerLabel:SetPosition(22,155)
		self.answerLabel:SetMultiline(false);
		self.answerLabel:SetForeColor( LT_color_gold )
		self.answerLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro20 );
		self.answerLabel:SetFontStyle( Turbine.UI.FontStyle.Outline )
		self.answerLabel:SetOutlineColor( LT_color_goldOutline )
		self.answerLabel:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft )
		--self.answerLabel:SetBackColor( Turbine.UI.Color(.2, .2, .2) )
		self.answerLabel:SetText( "Current Answer" )
		self.answerLabel:SetVisible( true )

		-- current answer text box
		--
		self.answerText = Turbine.UI.Label()
		self.answerText:SetSize(440,90)
		self.answerText:SetPosition(18,185)
		self.answerText:SetFont( Turbine.UI.Lotro.Font.TrajanPro18 )
		self.answerText:SetForeColor( Turbine.UI.Color(1,1,1) )
		self.answerText:SetTextAlignment( Turbine.UI.ContentAlignment.TopLeft)
		self.answerText:SetMultiline( true )
		self.answerText:SetBackColor( Turbine.UI.Color(0, .2, 0) )
		self.answerText:SetText( "Answers will be shown here." )
		self.answerText:SetVisible( true )
		self.answerText:SetParent( self )

		-- guesses box header text
		self.guessesLabel = Turbine.UI.Label()
		self.guessesLabel:SetParent(self);
		self.guessesLabel:SetSize(260,30)
		self.guessesLabel:SetPosition(22,280)
		self.guessesLabel:SetMultiline(false);
		self.guessesLabel:SetForeColor( LT_color_gold )
		self.guessesLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro20 );
		self.guessesLabel:SetFontStyle( Turbine.UI.FontStyle.Outline )
		self.guessesLabel:SetOutlineColor( LT_color_goldOutline )
		self.guessesLabel:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft )
		--self.guessesLabel:SetBackColor( Turbine.UI.Color(.2, .2, .2) )
		self.guessesLabel:SetText( "Current Guesses" )
		self.guessesLabel:SetVisible( true )

		-- Listbox for current guesses
		self.guessesListBox = Turbine.UI.ListBox();
		self.guessesListBox:SetParent(self);
		self.guessesListBox:SetSize(440,240);
		self.guessesListBox:SetPosition(16,310);
		self.guessesListBox:SetBackColor( LT_color_darkgray );

		-- Bind a vertical scrollbar to the listbox
		self.guessesScroll = Turbine.UI.Lotro.ScrollBar();
		self.guessesScroll:SetOrientation(Turbine.UI.Orientation.Vertical);
		self.guessesScroll:SetParent(self);
		self.guessesScroll:SetPosition(445,310);
		self.guessesScroll:SetBackColor( LT_color_darkgray );
		self.guessesScroll:SetWidth(12);
		self.guessesScroll:SetHeight(self.guessesListBox:GetHeight());
		self.guessesScroll:SetVisible(true);
		self.guessesListBox:SetVerticalScrollBar(self.guessesScroll);

		-- pseudo-button for accept answer
		--
		self.acceptAlias=Turbine.UI.Lotro.Quickslot();
		self.acceptAlias:SetParent(self);
		self.acceptAlias:SetSize(117,18);
		self.acceptAlias:SetPosition(467,320);
		self.acceptAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
		self.acceptAlias.ShortcutData=""; --save the alias text for later
		self.acceptAlias:SetAllowDrop(false); -- turn off drag and drop so the user doesn't accidentally modify our button action
		self.acceptAlias.DragDrop=function()
			local sc=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,"");
			sc:SetData(self.acceptAlias.ShortcutData);
			self.acceptAlias:SetShortcut(sc);
		end

		--[[
		self.acceptAlias.Backdrop=Turbine.UI.Control(); -- note, if the icon has no transparencies then this backdrop is not needed
		self.acceptAlias.Backdrop:SetParent(self);
		self.acceptAlias.Backdrop:SetSize(117,18);
		self.acceptAlias.Backdrop:SetPosition(467,320);
		self.acceptAlias.Backdrop:SetZOrder(self.acceptAlias:GetZOrder()+1); -- force the icon to be displayed above the quickslot
		self.acceptAlias.Backdrop:SetBackground("Carentil/LOTRivia/Resources/img/accept.jpg");
		self.acceptAlias.Backdrop:SetBackColor(Turbine.UI.Color(1,0,0,0))
		self.acceptAlias.Backdrop:SetMouseVisible(false);
		--]]

		self.acceptAlias.Icon=Turbine.UI.Control();
		self.acceptAlias.Icon:SetParent(self);
		self.acceptAlias.Icon:SetSize(117,18);
		self.acceptAlias.Icon:SetPosition(467,320);
		self.acceptAlias.Icon:SetZOrder(self.acceptAlias:GetZOrder()+2);
		self.acceptAlias.Icon:SetMouseVisible(false);
		self.acceptAlias.Icon:SetBlendMode(Turbine.UI.BlendMode.Overlay);
		self.acceptAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/accept.jpg")

		self.acceptAlias.MouseEnter=function()
			self.acceptAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/accept_sel.jpg")
		end
		self.acceptAlias.MouseLeave=function()
			self.acceptAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/accept.jpg")
		end
		self.acceptAlias.MouseDown=function()
			self.acceptAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/accept.jpg")
		end
		self.acceptAlias.MouseUp=function()
			self.acceptAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/accept_sel.jpg")

		-- disabled the next check for the time being, so that points can be awarded after the timer is done
		-- or the game is over. The check for answeringPlayer will prevent double point awards, but not
		-- reannouncing the player who got it.
		--
		--	if (gameActive and questionActive) then
				if (answeringPlayer ~= nil) then
					stopCountdown();
					awardPoints();
					self.questionsRemaining:SetText(Settings.questionsPerRound - #usedQuestions );
					-- Clear the reveal text
					self.revealAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
				end
		--	end -- end of disabled gameActive/questionActive test
		end

		-- pseudo-button for reveal answer
		--
		self.revealAlias=Turbine.UI.Lotro.Quickslot();
		self.revealAlias:SetParent(self);
		self.revealAlias:SetSize(114,18);
		self.revealAlias:SetPosition(469,350);
		self.revealAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
		self.revealAlias.ShortcutData=""; --save the alias text for later
		self.revealAlias:SetAllowDrop(false); -- turn off drag and drop so the user doesn't accidentally modify our button action
		self.revealAlias.DragDrop=function()
			local sc=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,"");
			sc:SetData(self.revealAlias.ShortcutData);
			self.revealAlias:SetShortcut(sc);
		end

		self.revealAlias.Icon=Turbine.UI.Control();
		self.revealAlias.Icon:SetParent(self);
		self.revealAlias.Icon:SetSize(114,18);
		self.revealAlias.Icon:SetPosition(469,350);
		self.revealAlias.Icon:SetZOrder(self.revealAlias:GetZOrder()+2);
		self.revealAlias.Icon:SetMouseVisible(false);
		self.revealAlias.Icon:SetBlendMode(Turbine.UI.BlendMode.Overlay);

		self.revealAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/reveal.jpg")
		self.revealAlias.MouseEnter=function()
			self.revealAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/reveal_sel.jpg")
		end
		self.revealAlias.MouseLeave=function()
			self.revealAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/reveal.jpg")
		end
		self.revealAlias.MouseDown=function()
			self.revealAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/reveal.jpg")
		end
		self.revealAlias.MouseUp=function()
			self.revealAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/reveal_sel.jpg")
			if (gameActive and questionActive) then
				stopCountdown();
				-- Since we're revealing the current question, pick a new question
				prepareQuestion();
				questionActive=false;
				self.questionsRemaining:SetText(Settings.questionsPerRound - #usedQuestions );
			end
		end



		-- questions Remaining text
		self.questionsRemainingLabel = Turbine.UI.Label()
		self.questionsRemainingLabel:SetParent(self);
		self.questionsRemainingLabel:SetSize(120,30)
		self.questionsRemainingLabel:SetPosition(467,190)
		self.questionsRemainingLabel:SetMultiline(false);
		self.questionsRemainingLabel:SetForeColor( LT_color_gold )
		self.questionsRemainingLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro14 );
		self.questionsRemainingLabel:SetFontStyle( Turbine.UI.FontStyle.Outline )
		self.questionsRemainingLabel:SetOutlineColor( LT_color_goldOutline )
		self.questionsRemainingLabel:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
		self.questionsRemainingLabel:SetText( "Questions Left:" )
		self.questionsRemainingLabel:SetVisible( true )

		-- questions Remaining text box
		--
		self.questionsRemaining = Turbine.UI.Label()
		self.questionsRemaining:SetSize(60,30)
		self.questionsRemaining:SetPosition(500,218)
		self.questionsRemaining:SetFont( Turbine.UI.Lotro.Font.TrajanPro24 )
		self.questionsRemaining:SetForeColor( LT_color_gold )
		self.questionsRemaining:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter)
		self.questionsRemaining:SetMultiline( true )
		self.questionsRemaining:SetBackColor( Turbine.UI.Color(.1, .1, .1) )
		self.questionsRemaining:SetText( Settings.questionsPerRound )
		self.questionsRemaining:SetVisible( true )
		self.questionsRemaining:SetParent( self )



		-- Time Remaining text
		self.timeRemainingLabel = Turbine.UI.Label()
		self.timeRemainingLabel:SetParent(self);
		self.timeRemainingLabel:SetSize(120,30)
		self.timeRemainingLabel:SetPosition(467,400)
		self.timeRemainingLabel:SetMultiline(false);
		self.timeRemainingLabel:SetForeColor( LT_color_gold )
		self.timeRemainingLabel:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 );
		self.timeRemainingLabel:SetFontStyle( Turbine.UI.FontStyle.Outline )
		self.timeRemainingLabel:SetOutlineColor( LT_color_goldOutline )
		self.timeRemainingLabel:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter )
		self.timeRemainingLabel:SetText( "Time Remaining:" )
		self.timeRemainingLabel:SetVisible( true )

		-- Time Remaining text box
		--
		self.timeRemaining = Turbine.UI.Label()
		self.timeRemaining:SetSize(60,30)
		self.timeRemaining:SetPosition(500,428)
		self.timeRemaining:SetFont( Turbine.UI.Lotro.Font.TrajanPro24 )
		self.timeRemaining:SetForeColor( LT_color_gold )
		self.timeRemaining:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter)
		self.timeRemaining:SetMultiline( true )
		self.timeRemaining:SetBackColor( Turbine.UI.Color(.1, .1, .1) )
		self.timeRemaining:SetText( "--" )
		self.timeRemaining:SetVisible( true )
		self.timeRemaining:SetParent( self )

		-- pseudo-button for announceTime answer
		--
		self.announceTimeAlias=Turbine.UI.Lotro.Quickslot();
		self.announceTimeAlias:SetParent(self);
		self.announceTimeAlias:SetSize(117,18);
		self.announceTimeAlias:SetPosition(467,470);
		self.announceTimeAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
		self.announceTimeAlias.ShortcutData=""; --save the alias text for later
		self.announceTimeAlias:SetAllowDrop(false); -- turn off drag and drop so the user doesn't accidentally modify our button action
		self.announceTimeAlias.DragDrop=function()
			local sc=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,"");
			sc:SetData(self.announceTimeAlias.ShortcutData);
			self.announceTimeAlias:SetShortcut(sc);
		end

		self.announceTimeAlias.Icon=Turbine.UI.Control();
		self.announceTimeAlias.Icon:SetParent(self);
		self.announceTimeAlias.Icon:SetSize(117,18);
		self.announceTimeAlias.Icon:SetPosition(467,470);
		self.announceTimeAlias.Icon:SetZOrder(self.announceTimeAlias:GetZOrder()+2);
		self.announceTimeAlias.Icon:SetMouseVisible(false);
		self.announceTimeAlias.Icon:SetBlendMode(Turbine.UI.BlendMode.Overlay);

		self.announceTimeAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announcetime.jpg")
		self.announceTimeAlias.MouseEnter=function()
			self.announceTimeAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announcetime_sel.jpg")
		end
		self.announceTimeAlias.MouseLeave=function()
			self.announceTimeAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announcetime.jpg")
		end
		self.announceTimeAlias.MouseDown=function()
			self.announceTimeAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announcetime.jpg")
		end
		self.announceTimeAlias.MouseUp=function()
			self.announceTimeAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/announcetime_sel.jpg")
		end

		-- Bottom panel buttons
		--

		-- Scores Button
		self.scoresButton = Turbine.UI.Lotro.Button();
		self.scoresButton:SetParent(self);
		self.scoresButton:SetHeight(30);
		self.scoresButton:SetWidth(120);
		self.scoresButton:SetText("Scores");
		self.scoresButton:SetPosition(30,560);
		self.scoresButton:SetVisible(true)

		-- Options Button
		self.optionsButton = Turbine.UI.Lotro.Button();
		self.optionsButton:SetParent(self);
		self.optionsButton:SetHeight(30);
		self.optionsButton:SetWidth(120);
		self.optionsButton:SetText("Options");
		self.optionsButton:SetPosition(152,560);
		self.optionsButton:SetVisible(true)

		-- pseudo-button for send rules
		--
		self.sendRulesAlias=Turbine.UI.Lotro.Quickslot();
		self.sendRulesAlias:SetParent(self);
		self.sendRulesAlias:SetSize(117,18);
		self.sendRulesAlias:SetPosition(274,561);
		self.sendRulesAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
		self.sendRulesAlias.ShortcutData=""; --save the alias text for later
		self.sendRulesAlias:SetAllowDrop(false); -- turn off drag and drop so the user doesn't accidentally modify our button action
		self.sendRulesAlias.DragDrop=function()
			local sc=Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,"");
			sc:SetData(self.sendRulesAlias.ShortcutData);
			self.sendRulesAlias:SetShortcut(sc);
		end

		self.sendRulesAlias.Icon=Turbine.UI.Control();
		self.sendRulesAlias.Icon:SetParent(self);
		self.sendRulesAlias.Icon:SetSize(117,18);
		self.sendRulesAlias.Icon:SetPosition(274,561);
		self.sendRulesAlias.Icon:SetZOrder(self.sendRulesAlias:GetZOrder()+2);
		self.sendRulesAlias.Icon:SetMouseVisible(false);
		self.sendRulesAlias.Icon:SetBlendMode(Turbine.UI.BlendMode.Overlay);

		self.sendRulesAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/sendrules.jpg")
		self.sendRulesAlias.MouseEnter=function()
			self.sendRulesAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/sendrules_sel.jpg")
		end
		self.sendRulesAlias.MouseLeave=function()
			self.sendRulesAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/sendrules.jpg")
		end
		self.sendRulesAlias.MouseDown=function()
			self.sendRulesAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/sendrules.jpg")
		end
		self.sendRulesAlias.MouseUp=function()
			self.sendRulesAlias.Icon:SetBackground("Carentil/LOTRivia/Resources/img/sendrules_sel.jpg")
		end


		-- Start/Stop Game Button
		self.gamestateButton = Turbine.UI.Lotro.Button();
		self.gamestateButton:SetParent(self);
		self.gamestateButton:SetHeight(30);
		self.gamestateButton:SetWidth(120);
		self.gamestateButton:SetText("Start Game");
		self.gamestateButton:SetPosition(394,560);
		self.gamestateButton:SetVisible(true)

		self.optionsButton.MouseUp = function(sender,args)
			-- No changing the options during a question
			if (questionActive) then
				ltprint(ltColor.orange .. "You cannot edit options while a question is active.</rgb>")
			else
				myOptions:SetVisible(not myOptions:IsVisible())
			end
		end

		self.scoresButton.MouseUp = function(sender,args)
			myScores:SetVisible(not myScores:IsVisible())
		end

		self.gamestateButton.MouseUp = function(sender,args)

			if ( not gameActive ) then

				if (haveEnoughQuestions()) then
					ltprint("Starting a new game!")
					self.gamestateButton:SetText("Finish Game")

					-- reset game data
					setUpDataStores();

					-- clear the questions and guesses
					self.resetGameWindow();
					myScores:updateList();

					-- Set the game state
					gameActive = true

					-- Pick the first question
					pickQuestion();
				else
					ltprint("Game not started.");
					return
				end

			else
				ltprint("Ending the current game.");
				self.gamestateButton:SetText("Start Game");

				-- Reset game window
				self.resetGameWindow();

				-- end the countdown, if it's active
				if (questionActive) then
					stopCountdown();
				end

				-- Update the scores, so that we can report them to the channel accurately if desired
				myScores:updateList()

				-- set game and question state
				gameActive = false
				questionActive = false

				-- clear pseudo button aliases
				self.acceptAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
				self.askAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
				self.revealAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
				self.announceTimeAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
			end
		end

		self.resetGameWindow = function ()
			self.questionText:SetText( "The questions will be shown here before sending them to the channel. " )
			self.answerText:SetText( "Answers will be shown here." )
			self.guessesListBox:ClearItems();
		end


		-- function to handle things when closed by the "x"
		--
		function self:Closed( sender, args )
			-- hide other windows if closed
			myOptions:SetVisible( false );
			myScores:SetVisible( false );
		end


		-- function to set up the reveal Answer alias
		--
		self.setReveal = function()
			local sendText=""

			if (debug) then
				sendText = "/say " .. ltColor.cyan .. "The correct answer was: </rgb>" .. ltColor.orange .. " >> " .. LT_Answer[questionId] .. " << </rgb>"
			else
				sendText = channels[Settings.channel]["cmd"] .. ltColor.cyan .. "The correct answer was: </rgb>" .. ltColor.purple .. " >> " .. LT_Answer[questionId] .. " << </rgb>"
			end
			-- Bind to reveal button
			self.revealAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,sendText))
		end

		self:SetResizable(false);
		self:SetVisible( Settings.gameVisible );
	end


	-- function to compare scores when sorting out the top ranks
	--
	function cmpScore(a,b)
		if (a[2] > b[2]) then
			return true
		end
	end


	-- function to fire when clicking player names in the scores list
	--
	function playerEdit(name)
		myEdit.playerName:SetText( name );
		myEdit.playerScore:SetText( playerScores[name] );
		myEdit.originalScore = playerScores[name];
		myEdit:SetVisible(true);
		ltprint("Editing "..name)
	end

	-- populate option controls to match config
	--
	function populateOptions()
		myOptions.timedCheckbox:SetChecked( Settings.timed )
		myOptions.timePerQuestion:SetText( Settings.timePerQuestion );
		myOptions.questionsPerRound:SetText( Settings.questionsPerRound );

		myOptions.channelSelection:SetText( Settings.channel )

		if (not Settings.timed) then
				myOptions.timePerQuestion:SetEnabled(false)
		end
	end


	-- countdown timer event
	--
	timerEvent = function()
		if (countdownTime == nil) then
			return
		end
		-- Update the countdown clock
		countdownTime = countdownTime-1;
		myGame.timeRemaining:SetText(countdownTime);

		if (debug) then
			timeAnnounce = "/say "
		else
			timeAnnounce = channels[Settings.channel]["cmd"]
		end

		timeAnnounce = timeAnnounce .. ltColor.purple .."LOTRivia: </rgb>" .. ltColor.cyan .. countdownTime .. " seconds left!</rgb>"

		myGame.announceTimeAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,timeAnnounce))

		-- If we've hit zero, we need to do a number of things.
		if (countdownTime == 0) then
			questionActive=false;
			RemoveCallback(myTimer,"TimeReached",timerEvent);

			-- Disable the timer repeat
			myTimer.Repeat = false;

			-- Let the user know time has expired
			ltprint("Time's up!");

			-- pick another question to ask
			prepareQuestion();

			-- clear the announce time alias
			myGame.announceTimeAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""));

			-- Update the question count
			myGame.questionsRemaining:SetText(Settings.questionsPerRound - #usedQuestions );
		end
	end



	-- Announce load to chat window
	questionCount = "No questions loaded!"

	if (LT_Question ~= nil) then
		if (#LT_Question ~= nil) then
			questionCount = "Loaded " .. #LT_Question .. " questions."
		end
	end

	ltprint("Version ".. lotrivia.version .. " -- " .. questionCount .. "  -- /lt help for commands.")

	if debug then
		ltprint(ltColor.orange .. "Debugging Mode Active")
	end

	myCommand = Turbine.ShellCommand()

	function myCommand:GetHelp()
		return helpText
	end

	function myCommand:GetShortHelp()
		return helpText
	end

	function myCommand:Execute(cmd,args)

		if (args == "help") then
			ltprint(helpText)

		elseif (args == "") then
			ltprint(helpText)

		elseif (args == "guesses") then

			if (haveStoredAnswers) then
				ltprint("Showing answers")

				for k,v in pairs(storedAnswers) do
					Turbine.Shell.WriteLine("<rgb=#40FF40>" .. k .. "</rgb>:  <rgb=#FFC040>" .. v .. "</rgb>")
				end

			else
				ltprint("No guesses found.")
			end


		elseif (args=="resetanswers") then
			resetAnswers()
			ltprint("Current question answers cleared.")

		elseif (args=="options") then
			LT_setOptions()
			myOptions:SetVisible(not myOptions:IsVisible())

		elseif (args=="pq") then
			pickQuestion()

		elseif (args=="save") then
			saveOptions()

		elseif (args=="load") then
			Settings = Turbine.PluginData.Load( Turbine.DataScope.Account, "LOTRiviaSettings", loadOptions)

		elseif (args=="show") then
			-- Unhide the game windows
			myScores:SetVisible(true);
			myGame:SetVisible(true);

		elseif (args=="sort") then
			myScores:updateList();

		else
			ltprint( "\"" .. args .. "\" is not a recognized command. Try /lt help." )
		end

	end




	-- Instantiate Windows
	--
	myOptions = optionsWindow();
	populateOptions();
	myScores = scoresWindow();
	myEdit = editWindow();
	myGame = gameWindow();
	myToggle = Toggle();

	-- Set up timer
	myTimer = Timer();

	-- Set up Send Rules alias
	myGame.sendRulesAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,channels[Settings.channel]["cmd"] ..rulesText))


	-- Add the shell command
	--
	Turbine.Shell.AddCommand( "lotrivia;lt", myCommand)

	-- Event handler for incoming chat. If the message is for the channel we're playing on
	-- and isn't extraneous (login/logpff messages, things sent from this user) then
	-- we call addToGuesses() to make the player's answer available to accept.
	--
	function parseChat(chatfunc, received)

		-- Continue only for the current channel we're watching
		--
		if (received["ChatType"] ~= channels[Settings.channel]["channelId"]) then
			return;
		end

		-- Strip out any leading text (timestamps, if there) the channel name, and EOLs
		--
		-- [11/24 01:35:15 PM] [glff] Forestgreenthumb: blah blah blah
		-- first, find the start and end positions of the channel name

		-- Strip off a leading timestamp, if there is one
		local pattern = "^[%d+/%d+%s+[%d:%s]+%a%a] "

		_ = string.gsub(tostring(received["Message"]), "<[^>]+>",'')

		-- grab the positions of the channel header
		--
		pattern = "%[%a+%] "
		local channelHeaderStart,channelHeaderEnd = string.find(_,pattern)

		-- Skip any "gone offline" or "come online" messages. These do not have the channel banner,
		-- so they won't have a start and end. This will also bypass messages sent from the player.
		-- The latter works because s apce ("To Kinship") isn't included in the pattern. If Turbine
		-- ever changes this, I hope they give us a method to retrieve a channel's name or I can't
		-- do user channels easily.
		--
		if (channelHeaderStart == nil ) then
			if (debug) then
				ltprint("skipping extraneous in-channel message")
			end
			return;
		end

		-- Chop the header out
		_ = string.sub( _, channelHeaderEnd )

		-- Strip XML and color formatting
		_ = string.gsub(_, "<[^>]+>",'')

		-- Strip linefeeds
		_ = string.gsub(_, "\n",'')

		-- get the sender and the chat text
		local sender,message = string.match(_,"(%a+):%s(.+)")

		-- Save the sender's message but only if they don't currently have one stored
		--
		if (storedAnswers[sender] == nil) then
			storedAnswers[sender] = message
			haveStoredAnswers = true
			-- push the answer to the answers listbox, but only if there's an active question
			--
			if (questionActive) then
				addToGuesses(sender,message);
			end
		end

	end -- end of function parseChat()


	-- Add in our chat processing callback
	--
	AddCallback(Turbine.Chat, "Received", parseChat)


	-- Add an item to the game guesses listbox
	--
	function addToGuesses(player,answer)
		local tmpItem = Turbine.UI.Label()
		tmpItem:SetMultiline(true)
		tmpItem:SetSize(432,30)
		tmpItem:SetLeft(0);
		tmpItem:SetFont( Turbine.UI.Lotro.Font.Verdana14 )
		tmpItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft )
		tmpItem:SetForeColor( LT_color_ltgray );
		local labelText = "  " ..player .. ": " .. answer
		tmpItem:SetText( labelText )
		function tmpItem:MouseUp(sender,args)
			selectPlayer(sender,args,player)
		end
		myGame.guessesListBox:AddItem(tmpItem)
	end

	-- reset the answers stored during the current question
	--
	function resetAnswers()
		storedAnswers = {}
		haveStoredAnswers = false
	end

	-- Function to pick a question we haven't used yet
	--
	function pickQuestion()

		-- sanity check to avoid an infinite loop
		if (#LT_Question == #usedQuestions) then
			ltprint("Uh Oh! You have used all your questions but somehow the the game thinks you should be picking another.")
			return;
		end

		local q = math.random(#LT_Question)
		questionId = nextFree(q)

		-- Update the game window
		myGame.questionText:SetText(LT_Question[questionId]);
		myGame.answerText:SetText(LT_Answer[questionId]);

		-- Update the alias for sending the question
		--
		if (gameActive) then

			sendQuestion = channels[Settings.channel]["cmd"] .. "<rgb=#20FF20>Question " .. (#usedQuestions+1) .. ": </rgb><rgb=#D0A000>" .. LT_Question[questionId] .. "</rgb>"

			if (debug) then
				myGame.askAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,"/say " ..sendQuestion))
			else
				myGame.askAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,sendQuestion))
			end

		else
			myGame.askAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))
		end

	end

	-- Get the next free question following the passed index.
	-- If the search surpasses the question pool length, it will wrap around.
	--
	function nextFree(x)
		for _,v in pairs(usedQuestions) do
			if v==x then
				-- We've already seen x
				x = x+1

				if ( x > #LT_Question ) then
					x = 1
				end
				x=nextFree(x)
			end
		end
		return x
	end

	-- Award a question to a player
	--
	function awardPoints()
		if (playerScores[answeringPlayer] == nil) then
			playerScores[answeringPlayer] = 0
		end

		-- Get another question ready, if need be
		--
		prepareQuestion();

		-- Update scores and scores window
		playerScores[answeringPlayer] = playerScores[answeringPlayer]+1

		myScores:updateList();
		myScores.SizeChanged();

		-- Reset player answers for the next question
		storedAnswers = {};

		-- Clear the answering player field
		answeringPlayer = nil

		-- Set question state to inactive
		questionActive = false;
	end


	-- Sort, redraw the scores
	--
	function scoresWindow:updateList()

		local scoreRL = {}

		if (#playerScores ~= nil) then

			-- Remove the existing list entries
			--
			self.scoresListBox:ClearItems()

			-- Add entries
			--
			for name,score in pairs(playerScores) do
				local tmpItem = Turbine.UI.Label()

				tmpItem:SetSize(440,24)
				tmpItem:SetParent(myGame.scoresListBox);
				tmpItem:SetFont( Turbine.UI.Lotro.Font.TrajanPro16 )
				tmpItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleRight )
				tmpItem:SetForeColor( LT_color_gold )
				tmpItem:SetVisible( true )
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

			-- Update the announceAllText and announceTopThreeText strings

			local sortedScores = {}
			local i=1

			-- build a table for scores with a "tie" field
			for name,score in pairs(playerScores) do
				sortedScores[i] = {name,score, ""};
				i=i+1;
			end

			table.sort(sortedScores, cmpScore)

			-- Add "tie" markers to the table as well
			for i=1,#sortedScores do
				if (i>1 and i<#sortedScores and sortedScores[i][2]==sortedScores[i+1][2]) then
					 sortedScores[i][3] = tieColor .. " (tie)</rgb>"
					 sortedScores[i+1][3] = tieColor .. " (tie)</rgb>"
				end
			end

			announceAllText = ""
			announceTopThreeText = ""

			if (#sortedScores ~= nil and #sortedScores > 0 ) then
				for i=1,#sortedScores do
					announceAllText = announceAllText ..
					scoreColor[1] ..  "[" .. sortedScores[i][1] .. ":"  .. sortedScores[i][2] .. "]</rgb> "
				end
			else

				announceAllText = "No points awarded."
			end

			if (#sortedScores >2) then
				announceTopThreeText =
				scoreColor[1] ..  "[" .. sortedScores[1][1] .. ":"  .. sortedScores[1][2] .. "</rgb>" .. sortedScores[1][3] .. scoreColor[1] .. "]</rgb>" ..
				scoreColor[2] .. " [" ..	sortedScores[2][1] .. ":"  .. sortedScores[2][2] .. "</rgb>" .. sortedScores[2][3] .. scoreColor[2] .. "]</rgb>" ..
				scoreColor[3] .. " [" ..	sortedScores[3][1] .. ":"  .. sortedScores[3][2] .. "</rgb>" .. sortedScores[3][3] .. scoreColor[3] .. "]</rgb>"

				-- If our score for fourth+ place are the same as the third place,
				-- include them as a tie
				if (#sortedScores >3) then
					for i=4,#sortedScores do
						if (sortedScores[i][2] == sortedScores[3][2]) then
							announceTopThreeText = announceTopThreeText ..
								scoreColor[3] .. " [" ..	sortedScores[i][1] .. ":"  .. sortedScores[i][2] .. "</rgb>" .. sortedScores[i][3] .. scoreColor[3] .. "]</rgb>"
						end
					end
				end

			else
				-- Less than three scores, so use all scores in top 3
				announceTopThreeText = announceAllText
			end

			if (debug) then
				announceAllText = "/say Scores: " .. announceAllText
				announceTopThreeText = "/say Top Scorers: " .. announceTopThreeText
			else
				announceAllText = channels[Settings.channel]["cmd"] .. "Scores: " .. announceAllText
				announceTopThreeText = channels[Settings.channel]["cmd"] .. "Top Scorers: " .. announceTopThreeText
			end

			-- set score window pseudo-button aliases
			myScores.announceAllText:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,announceAllText));
			myScores.top3:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,announceTopThreeText));

		end
	end


	-- function to stop countdown timer and reset game window time display
	--
	function stopCountdown()
		if ( Settings.timed ) then
			RemoveCallback(myTimer,"TimeReached",timerEvent);
		end
		myTimer.Repeat = false;
		myGame.timeRemaining:SetText("--");
		countdownTime = nil
	end


	-- function to handle events when a guess is clicked in the guesses ListBox
	--
	function selectPlayer(sender,args,name)
		for i=1,myGame.guessesListBox:GetItemCount() do
			local item = myGame.guessesListBox:GetItem(i)
			item:SetBackColor( LT_color_darkgray );
		end

		-- Tint the selected item
		local selected = myGame.guessesListBox:GetSelectedItem();
		answeringPlayer=string.match(tostring(selected:GetText()),"^%s*([^:]+)");
		selected:SetBackColor( Turbine.UI.Color( .1,.4,.1 ) );

		-- Set up the alias for the "accept answer" quickslot faux button
		myGame.askAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""))

		local acceptText = ""

		if (debug) then
			acceptText = "/say"
		else
			acceptText = channels[Settings.channel]["cmd"]
		end

		acceptText = acceptText .. " " .. ltColor.cyan .. name .. " got the right answer!</rgb> " .. ltColor.purple .. " >> " .. LT_Answer[questionId] .. " << </rgb>"

		-- Bind to alias button
		myGame.acceptAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,acceptText))
	end


	-- Make sure we have enough questions loaded to play a game of the desired length
	--
	function haveEnoughQuestions()
		if (#LT_Question == nil) then
			ltprint(ltColor.orange .. "Uh oh! No questions loaded!")
			return false
		elseif (Settings.questionsPerRound > #LT_Question) then
			ltprint(ltColor.orange .. "You have set " .. Settings.questionsPerRound .. " questions per round, but you only have " .. #LT_Question .. " questions available. "  )
			return false
		end
		return true
	end


	-- Some options require positive numbers to be valid. This function tests that.
	--
	function isPositiveNumber(val)
		if (val == nil) then
			return false
		end

		val = tonumber(val)

		-- Non-numbers come back as nil
		if (val == nil) then return false end

		if (val < 1) then
			return false
		end

		return true
	end

	-- prepares another question, unless we don't need more questions
	-- (i.e. end of game)
	--
	function prepareQuestion()
		if (#usedQuestions < Settings.questionsPerRound) then
			pickQuestion();
		else
			-- If we ARE at the max questions, reset the game window
			myGame.resetGameWindow();
			ltprint("Game completed!");
			gameActive = false;
			questionActive = false;

			-- Clear aliases
			myGame.askAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""));
			myGame.acceptAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""));
			myGame.announceTimeAlias:SetShortcut(Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias,""));

			-- reset the Start Game button TextBox
			myGame.gamestateButton:SetText("Start Game");

		end
	end
