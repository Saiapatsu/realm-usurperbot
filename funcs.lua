-- Read messages
-- Send messages
-- Manage Messages: delete messages and emoji
-- Add emoji

--------------------------------------------------

local env = getfenv()

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
	async(message.delete, message)
	local reply = message.channel:sendf("<@%s> Please, only send images and links in this channel.", message.author.id)
	timer.sleep(4000)
	reply:delete()
end

--------------------------------------------------

guilds = {
	-- Test server
	["517339055831384084"] = {
		upvote = "\xE2\x9A\xA0\xEF\xB8\x8F", -- warning
		downvote = "\xF0\x9F\x90\xB4", -- horse
		weekly = "okbud:1070367873891041351",
		canDoAnything = function(member) return member:hasRole("936745626048294923") end, -- rancid
		canBeDownvoted = function(member) return member:hasRole("1070364517604802671") end, -- redditor
	},
	-- Ideas
	["309088417466023936"] = {
		upvote = "upvote:539111244842532874",
		downvote = "downvote:539111244414844929",
		weekly = "Weekly:742160530353160192",
		canDoAnything = function(member) return member:hasRole("309090145099972608") end, -- unbound
		canBeDownvoted = function(member) return member:hasRole("xxxxxxxxx") end, -- downvote
	}
}

--------------------------------------------------

local channelsMessage = {}

function messageHandlerShowcase(message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end 
	if messageIsImage(message) then
		async(message.addReaction, message, dataGuild.upvote)
		if dataGuild.canBeDownvoted(message.member) then
			message:addReaction(dataGuild.downvote)
		end
	elseif dataGuild.canDoAnything(message.member) then
		-- keep it
	else
		scold(message)
	end
end

function messageHandlerWeekly(message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end
	if messageIsImage(message) then
		message:addReaction(dataGuild.weekly)
	elseif dataGuild.canDoAnything(message.member) then
		-- keep it
	else
		scold(message)
	end
end

channelsMessage["1070158816001396767"] = messageHandlerShowcase -- #qeeqe
channelsMessage["1030063439160295435"] = messageHandlerWeekly -- #emoji

channelsMessage["520457693979213833"] = messageHandlerShowcase -- #showcase
channelsMessage["742157612879183993"] = messageHandlerWeekly -- #weekly

--------------------------------------------------

channelsReaction = {}

function reactionHandlerShowcase(reaction, userId, message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end
	if message.author.id == userId and reaction.emojiHash == dataGuild.upvote and not dataGuild.canDoAnything(message.member) then
		-- Remove user's upvote and own upvote and add downvote
		async(message.removeReaction, message, dataGuild.upvote)
		async(message.removeReaction, message, dataGuild.upvote, userId)
		-- potentially save a http request?
		for _,v in pairs(message.reactions) do
			if v.emojiHash == dataGuild.downvote then return end
		end
		message:addReaction(dataGuild.downvote)
	end
end

function reactionHandlerWeekly(reaction, userId, message)
	local dataGuild = guilds[message.guild.id]
	if dataGuild == nil then return end
	if message.author.id == userId and reaction.emojiHash == dataGuild.weekly and not dataGuild.canDoAnything(message.member) then
		message:removeReaction(dataGuild.weekly, userId)
	end
end

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
	if reaction.message.author.bot then return end
	env.reaction = reaction
	try(channelsReaction[reaction.message.channel.id], reaction, userId, message)
end

--------------------------------------------------

print("Loaded")
