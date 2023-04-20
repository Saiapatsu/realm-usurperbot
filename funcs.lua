-- Read messages
-- Send messages
-- Add emoji

-- Moderation perms, unusable without verification >:(
-- Manage Messages: delete messages and emoji
-- Manage roles (to add/remove the role)

--------------------------------------------------

local fs = require "fs"
local env = getfenv()

local staticRope = {}

--------------------------------------------------

function async(fn, ...)
	return coroutine.wrap(fn)(...)
end

function try(fn, ...)
	if fn == nil then return end
	local success, err = pcall(fn, ...)
	if not success then
		print("Error: " .. err)
		-- stop()
	end
end

function messageIsImage(message)
	return message.attachment or message.embed or message.content:find("https?://")
end

function scold(message)
	-- async(message.delete, message)
	local reply = message.channel:sendf("<@%s> Please, only send images and links in this channel.", message.author.id)
	timer.sleep(4000)
	reply:delete()
end

function messageHasReaction(message, hash)
	for _,v in pairs(message.reactions) do
		if v.emojiHash == hash then return true end
	end
	return false
end

function alertme()
	print(os.date() .. " /!\\ Bot is alive\a")
end

--------------------------------------------------

local function parseListFromFile(path)
	local list = {}
	for line in fs.readFileSync(path):gmatch("[^\r\n]+") do
		-- completely ignoring bayonet for now
		line = line:match("^[ \t]*([^;#]*)") -- strip leading tabs, comment and trailing ;bayonet
		line = line:match("(.-) *$") -- strip trailing spaces from bayonet
		if line ~= "" then
			table.insert(list, line)
		end
	end
	return list
end

local function pick(tbl)
	return tbl[math.random(#tbl)]
end

--------------------------------------------------

function status()
	print("\n\n\n" .. os.date() .. "\n\n\n")
end
s = status

--------------------------------------------------

guilds = {
	-- Test server
	["517339055831384084"] = {
		upvote = "\xE2\x9A\xA0\xEF\xB8\x8F", -- warning
		downvote = "\xF0\x9F\x90\xB4", -- horse
		weekly = "okbud:1070367873891041351",
		roleFreedom = "936745626048294923", -- rancid
		roleDownvote = "1070364517604802671", -- redditor
	},
	-- Ideas
	["309088417466023936"] = {
		upvote = "upvote:539111244842532874",
		downvote = "downvote:539111244414844929",
		weekly = "Weekly:742160530353160192",
		roleFreedom = "1075535787363410022", -- unbound
		roleDownvote = "1075535787363410022", -- downvote
	}
}

function messageCanDoAnything(dataGuild, message)
	return message.member:hasRole(dataGuild.roleFreedom)
end

function messageCanBeDownvoted(dataGuild, message)
	return message.member:hasRole(dataGuild.roleDownvote) or message.content:find(dataGuild.downvote, 1, true)
end

--------------------------------------------------

channelsMessage = {}

function messageHandlerShowcase(message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end
	alertme()
	if messageIsImage(message) then
		async(message.addReaction, message, dataGuild.upvote)
		if messageCanBeDownvoted(dataGuild, message) then
			message:addReaction(dataGuild.downvote)
		end
	elseif messageCanDoAnything(dataGuild, message) then
		-- keep it
	else
		scold(message)
	end
end

function messageHandlerWeekly(message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end
	alertme()
	if messageIsImage(message) then
		message:addReaction(dataGuild.weekly)
	elseif messageCanDoAnything(dataGuild, message) then
		-- keep it
	else
		scold(message)
	end
end

--------------------------------------------------

local chances = {} -- [()->()]: number
local function commit(chance, fn)
	chances[fn] = chance
	return fn
end

local listModObject = parseListFromFile "mod object"
local listModLocation = parseListFromFile "mod location"
local listLocations = parseListFromFile "locations"
local listObjects = parseListFromFile "objects"

local makeItemModObject = commit(#listModObject * #listObjects, function()
	return string.format(
		"%s %s",
		pick(listModObject),
		pick(listObjects))
end)
local makeItemObjectOfTheMod = commit(#listModObject * #listObjects, function()
	return string.format(
		"%s of the %s",
		pick(listObjects),
		pick(listModObject))
end)
local makeDungeonModObject = commit(#listModLocation * #listLocations, function()
	return string.format(
		"%s %s",
		pick(listModLocation),
		pick(listLocations))
end)
local makeDungeonPlaceOfTheMod = commit(#listModLocation * #listLocations, function()
	return string.format(
		"%s of the %s",
		pick(listLocations),
		pick(listModLocation))
end)

local function makeItem()
	local aaa = chances[makeItemModObject]
	local max = aaa + chances[makeItemObjectOfTheMod]
	local n = math.random(max)
	if n > aaa then
		return makeItemObjectOfTheMod()
	else
		return makeItemModObject()
	end
end

local function makeDungeon()
	local n = math.random(2)
	if n == 1 then
		return makeDungeonPlaceOfTheMod()
	else
		return makeDungeonModObject()
	end
end

local function generator(fn, message, str, pos)
	-- .command
	-- .command 1
	-- .command asdasd
	local count, pos = string.match(str, "^%s*([^ ]*)()", pos)
	count = math.min(8, tonumber(count) or 1)
	
	for i = 1, count do
		staticRope[i] = fn()
	end
	staticRope[count + 1] = nil
	
	message:reply(table.concat(staticRope, "\n"))
end

--------------------------------------------------

function messageHandlerBots(message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end
	local str = message.content
	if str:sub(1, 1) ~= "." then return end
	local word, pos = str:match("^(%S+)()", 2)
	if word == nil then
		-- space between dot and word
		return
		
	elseif word == "item" then
		generator(makeItem, message, str, pos)
	elseif word == "dungeon" then
		generator(makeDungeon, message, str, pos)
	end
end

--------------------------------------------------

function reactionHandlerShowcase(reaction, userId, message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end
	if messageCanDoAnything(dataGuild, message) then return end
	if message.author.id == userId and reaction.emojiHash == dataGuild.upvote then
		-- On self-upvote:
		-- If there is no downvote, add one, otherwise remove own upvote.
		-- Afterward, remove user's upvote.
		if messageHasReaction(message, dataGuild.downvote) then
			async(message.removeReaction, message, dataGuild.upvote)
		else
			async(message.addReaction, message, dataGuild.downvote)
		end
		-- Can't have shit without Manage Messages
		-- message:removeReaction(dataGuild.upvote, userId)
	end
end

function reactionHandlerWeekly(reaction, userId, message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end
	if messageCanDoAnything(dataGuild, message) then return end
	if message.author.id == userId and reaction.emojiHash == dataGuild.weekly then
		message:removeReaction(dataGuild.weekly, userId)
	end
end

--------------------------------------------------

-- channelsMessage["1070158816001396767"] = messageHandlerShowcase -- #boten
-- channelsMessage["1030063439160295435"] = messageHandlerWeekly -- #emoji
channelsMessage["1070158816001396767"] = messageHandlerBots -- #boten

channelsMessage["520457693979213833"] = messageHandlerShowcase -- #showcase
channelsMessage["742157612879183993"] = messageHandlerWeekly -- #weekly
channelsMessage["309121149592403980"] = messageHandlerBots -- #bots

channelsReaction = {}

channelsReaction["1070158816001396767"] = reactionHandlerShowcase -- #qeeqe
channelsReaction["1030063439160295435"] = reactionHandlerWeekly -- #emoji

channelsReaction["520457693979213833"] = reactionHandlerShowcase -- #showcase
channelsReaction["742157612879183993"] = reactionHandlerWeekly -- #weekly

--------------------------------------------------

function onReady()
	print("Logged in as ".. client.user.username)
end

function onMessageCreate(message)
	if message.author.bot then return end
	env.message = message
	try(channelsMessage[message.channel.id], message)
end

function onReactionAdd(reaction, userId)
	local message = reaction.message
	if message.author.bot then return end
	env.reaction = reaction
	try(channelsReaction[message.channel.id], reaction, userId, message)
end

--------------------------------------------------

print("Loaded")
