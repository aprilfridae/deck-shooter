-- The comments tab of a profile. Comments use a built-in font, because the image fonts have no
-- lowercase or full punctuation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardCore = ReplicatedStorage:WaitForChild("CardCore")
local Comments = require(CardCore:WaitForChild("Comments"))
local CardData = require(script.Parent.CardData)
local MenuPanel = require(script.Parent.MenuPanel)
local PanelKit = require(script.Parent.PanelKit)

local FONT = Enum.Font.Gotham
local BOLD_FONT = Enum.Font.GothamBold
local TEXT_SIZE = 0.0115 -- share of the unit
local BOX_HEIGHT = 0.05
local POST_WIDTH = 0.07
local ROW_GAP = 0.01
local BOTTOM_ROOM = 0.02
local ACTION_WIDTH = 0.06
local ACTION_HEIGHT = 0.02
local MESSAGE_TIME = 2 -- seconds

local MESSAGES = {
	TooSoon = "WAIT A FEW SECONDS",
	CantChat = "YOUR ACCOUNT CANT POST",
	FilterFailed = "COULD NOT POST. TRY AGAIN",
	StoreFailed = "COULD NOT POST. TRY AGAIN",
	CommentsOff = "COMMENTS ARE OFF",
	NoReply = "COULD NOT POST. TRY AGAIN",
	RateLimited = "WAIT A FEW SECONDS",
	BadRequest = "THAT COMMENT CANT BE POSTED",
}

local CommentsPanel = {}

local function textLabel(parent: Instance, text: string, bold: boolean): TextLabel
	local unit = MenuPanel.unit()
	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = if bold then BOLD_FONT else FONT
	label.Size = UDim2.new(1, 0, 0, 0)
	label.Text = text
	label.TextColor3 = PanelKit.INK
	label.TextSize = TEXT_SIZE * unit
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local fill: (Frame, any, number) -> ()

local function act(page: Frame, profile: any, top: number, name: string, request: any)
	task.spawn(function()
		CardData.ask(name, request)
		if page.Parent then
			fill(page, profile, top)
		end
	end)
end

local function row(list: Instance, page: Frame, profile: any, top: number, comment: any, order: number)
	local unit = MenuPanel.unit()
	local viewer = Players.LocalPlayer.UserId
	local frame = Instance.new("Frame")
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local author = textLabel(frame, comment.authorName, true)
	author.LayoutOrder = 1
	textLabel(frame, comment.text, false).LayoutOrder = 2

	local isOwner = viewer == profile.userId
	local isAuthor = viewer == comment.authorId
	if isOwner or not isAuthor then
		local actions = Instance.new("Frame")
		actions.BackgroundTransparency = 1
		actions.LayoutOrder = 3
		actions.Size = UDim2.new(1, 0, 0, (ACTION_HEIGHT + 0.004) * unit)
		actions.Parent = frame
		local target = { owner = profile.userId, author = comment.authorId }
		local x = 0
		if isOwner then
			local delete = PanelKit.button(actions, "DELETE", x, 0.003, ACTION_WIDTH, ACTION_HEIGHT, {
				size = PanelKit.SMALL_SIZE * 0.85,
			})
			delete.Activated:Connect(function()
				act(page, profile, top, "DeleteComment", target)
			end)
			x += ACTION_WIDTH + 0.006
		end
		if not isAuthor then
			local report = PanelKit.button(actions, "REPORT", x, 0.003, ACTION_WIDTH, ACTION_HEIGHT, {
				size = PanelKit.SMALL_SIZE * 0.85,
			})
			report.Activated:Connect(function()
				report.Active = false
				task.spawn(function()
					local reply = CardData.ask("ReportComment", target)
					if report.Parent then
						report.Visible = false
						if reply.ok then
							PanelKit.line(actions, "REPORTED", x, 0.017)
						end
					end
				end)
			end)
		end
	end
end

local function postBox(page: Frame, profile: any, top: number, existing: any?)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	local unit = MenuPanel.unit()
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = PanelKit.PAPER
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = FONT
	box.MultiLine = true
	box.PlaceholderColor3 = PanelKit.INK:Lerp(PanelKit.PAPER, 0.5)
	box.PlaceholderText = "Leave a comment"
	box.Position = UDim2.fromOffset(MARGIN * unit, top * unit)
	box.Size = UDim2.fromOffset((RIGHT - MARGIN - POST_WIDTH - 0.008) * unit, BOX_HEIGHT * unit)
	box.Text = if existing then existing.text else ""
	box.TextColor3 = PanelKit.INK
	box.TextSize = TEXT_SIZE * unit
	box.TextWrapped = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.Parent = page
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = PanelKit.INK
	stroke.Parent = box
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 0.005 * unit)
	padding.PaddingTop = UDim.new(0, 0.004 * unit)
	padding.Parent = box

	local counter = PanelKit.label(page, "Label", PanelKit.SMALL_SIZE * 0.85, RIGHT, top + BOX_HEIGHT + 0.014, true)
	local function count()
		if #box.Text > Comments.MAX_LENGTH + 40 then
			box.Text = string.sub(box.Text, 1, Comments.MAX_LENGTH + 40)
		end
		counter:set(`{utf8.len(box.Text) or #box.Text}/{Comments.MAX_LENGTH}`)
	end
	box:GetPropertyChangedSignal("Text"):Connect(count)
	count()

	local post = PanelKit.button(page, if existing then "EDIT" else "POST", RIGHT - POST_WIDTH, top, POST_WIDTH, BOX_HEIGHT, {
		active = true,
	})
	local sending = false
	post.Activated:Connect(function()
		if sending then
			return
		end
		sending = true
		task.spawn(function()
			local reply = CardData.ask("PostComment", { owner = profile.userId, text = box.Text })
			if not page.Parent then
				return
			end
			if reply.ok then
				fill(page, profile, top)
				return
			end
			sending = false
			local message = PanelKit.line(page, MESSAGES[reply.code] or MESSAGES.BadRequest, PanelKit.MARGIN, top + BOX_HEIGHT + 0.014)
			task.delay(MESSAGE_TIME, function()
				if message.frame.Parent then
					message.frame:Destroy()
				end
			end)
		end)
	end)
end

local function ownerSwitch(page: Frame, profile: any, top: number)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	PanelKit.line(page, "COMMENTS ON YOUR PAGE", MARGIN, top + 0.02)
	local word = if profile.commentsOff then "OFF" else "ON"
	local button = PanelKit.button(page, word, RIGHT - POST_WIDTH, top, POST_WIDTH, 0.03, {
		active = not profile.commentsOff,
	})
	button.Activated:Connect(function()
		profile.commentsOff = not profile.commentsOff
		act(page, profile, top, "SetCommentsOff", profile.commentsOff)
	end)
end

fill = function(page: Frame, profile: any, top: number)
	local MARGIN, RIGHT = PanelKit.MARGIN, PanelKit.RIGHT
	local unit = MenuPanel.unit()
	local viewer = Players.LocalPlayer.UserId
	page:ClearAllChildren()
	PanelKit.line(page, "LOADING", MARGIN, top + 0.02)

	task.spawn(function()
		local reply = CardData.ask("GetComments", profile.userId)
		if not page.Parent then
			return
		end
		page:ClearAllChildren()
		if not reply.ok then
			PanelKit.line(page, "COMMENTS COULD NOT LOAD", MARGIN, top + 0.02)
			return
		end

		local comments = reply.result
		local listTop = top + 0.045
		if viewer == profile.userId then
			ownerSwitch(page, profile, top)
		elseif profile.commentsOff then
			PanelKit.line(page, "COMMENTS ARE OFF", MARGIN, top + 0.02)
		else
			postBox(page, profile, top, Comments.find(comments, viewer))
			listTop = top + BOX_HEIGHT + 0.026
		end
		if profile.commentsOff then
			return
		end

		local list = Instance.new("ScrollingFrame")
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.CanvasSize = UDim2.fromOffset(0, 0)
		list.Position = UDim2.fromOffset(MARGIN * unit, listTop * unit)
		list.ScrollBarImageColor3 = PanelKit.INK
		list.ScrollBarThickness = 3
		list.Size = UDim2.new(0, (RIGHT - MARGIN) * unit, 1, -(listTop + BOTTOM_ROOM) * unit)
		list.Parent = page
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, ROW_GAP * unit)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list

		if #comments == 0 then
			textLabel(list, "No comments yet.", false)
		end
		for order, comment in comments do
			row(list, page, profile, top, comment, order)
		end
	end)
end

function CommentsPanel.fill(page: Frame, profile: any, top: number)
	fill(page, profile, top)
end

return CommentsPanel
