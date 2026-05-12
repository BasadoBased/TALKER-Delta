package.path = package.path .. ";./bin/lua/?.lua;"
local Item = require("domain.model.item")
-- Event data structure
local Event = {}
Event.TYPE = {
	DIALOGUE = "%s: '%s'",
	ACTION = "%s %s %s",
	KILL = "%s killed %s",
	SPOT = "%s spotted %s",
	HEAR = "%s heard %s",
}

-- Event constructor
function Event.create_event(
	unformatted_description_or_type,
	involved_objects,
	game_time_ms,
	world_context,
	witnesses,
	flags,
	source_event
)
	local event = {}
	event.description = unformatted_description_or_type
	event.involved_objects = involved_objects or {}
	event.game_time_ms = game_time_ms
	event.world_context = world_context
	event.witnesses = witnesses or {}
	event.flags = flags or {} -- Add flags to the event object
	event.source_event = source_event
	event.timestamp = talker_game_queries.current_time_string_precise()
	return event
end

-- Format:
-- [PDA Broadcast | (Name)] News contents
function Event.from_news(news, community, game_time_ms, world_context)
    local sender = news.Se 
    local message = news.Mg or ""

    -- local description
    -- local involved_objects = {}
    -- if sender ~= "" and message ~= "" then
    --     description = "%s: %s"
    --     involved_objects = {sender, message}
    -- elseif message ~= "" then
    --     description = "%s"
    --     involved_objects = {message}
    -- elseif sender ~= "" then
    --     description = "%s"
    --     involved_objects = {sender}
    -- else
    --     description = "News"
    --     involved_objects = {}
    -- end

	local description = "[PDA Broadcast] "
	if sender  and sender ~= "" then
		description = "[PDA Broadcast] " .. sender .. ": "
	end

	description = description .. message


    local flags = {
        is_news = true,
        news_community = community,
        news_type = news.Ty,
        news_icon = news.Ic,
        news_sound = news.Snd,
        news_sender = news.Se,
    }

    local event = Event.create_event(description, involved_objects, game_time_ms, world_context, {}, flags)
    event.news = news
    return event
end

function Event.was_conversation(event)
	return event.source_event ~= nil
end

function table_to_args(table_input)
	local args = {}
	for key, value in pairs(table_input) do
		table.insert(args, value)
	end
	return unpack(args)
end

local function strip_color_codes(text)
	if type(text) ~= "string" then
		return ""
	end
	text = text:gsub("%%c%[.-%]", "")
	return text
end

function Event.describe_event(event)
	local description = strip_color_codes(event.description or "")
	if type(event.involved_objects) ~= "table" or #event.involved_objects == 0 then
		return description
	end

	local involved_object_descriptions = {}
	for _, object in ipairs(event.involved_objects) do
		if type(object) == "string" then
			table.insert(involved_object_descriptions, object)
		else
			table.insert(involved_object_descriptions, Item.describe_short(object))
		end
	end
	return string.format(description, table_to_args(involved_object_descriptions))
end

function Event.describe_short(event)
	if not event then
		return ""
	end

	local ok, result = pcall(Event.describe_event, event)
	if ok and type(result) == "string" then
		return result
	end

	return strip_color_codes(event.description or "")
end

local function get_character_faction(character_id)
	if type(character_id) == "table" then
		if character_id.faction then
			return character_id.faction
		end
		if character_id.raw_faction then
			return character_id.raw_faction
		end
		if character_id.game_id then
			character_id = character_id.game_id
		end
	end

	if not character_id then
		return nil
	end

	local query = rawget(_G, "talker_game_queries")
	if query and query.get_obj_by_id and query.get_faction then
		local game_obj = query.get_obj_by_id(character_id)
		if game_obj then
			return query.get_faction(game_obj)
		end
	end

	return nil
end


local function get_technical_faction_name(display_name)
	local faction_map = {
		["mercenaries"] = "killer",
		["mercs"] = "killer",
		["mercenary"] = "killer",
		["duty"] = "dolg",
		["freedom"] = "freedom",
		["bandit"] = "bandit",
		["monolith"] = "monolith",
		["loner"] = "stalker",
		["stalker"] = "stalker",
		["clear sky"] = "csky",
		["scientist"] = "ecolog",
		["egghead"] = "ecolog",
		["ecolog"] = "ecolog",
		["military"] = "army",
		["army"] = "army",
		["renegade"] = "renegade",
		["trader"] = "trader",
		["sin"] = "greh",
		["unisg"] = "isg",
		["isg"] = "isg",
		["zombie"] = "zombied",
		["zombied"] = "zombied",
	}
	return faction_map[display_name] or faction_map[display_name:lower()] or display_name:lower()
end
local function get_current_game_time_ms()
	local query = rawget(_G, "talker_game_queries")
	if query and type(query.get_game_time_ms) == "function" then
		return query.get_game_time_ms()
	end
	return nil
end

local function is_news_recent(event, max_age_ms)
	if not event or not event.game_time_ms then
		return false
	end
	local current_time = get_current_game_time_ms()
	if not current_time then
		return false
	end
	return current_time - event.game_time_ms <= max_age_ms
end

function Event.was_witnessed_by(event, character_id)
	if not event then
		return false
	end

	local news_community = event.flags and event.flags.news_community
	if news_community then
		local MAX_NEWS_AGE_MS = 3 * 24 * 60 * 60 * 1000
		if not is_news_recent(event, MAX_NEWS_AGE_MS) then
			return false
		end

		if news_community == "general" then
			return true
		end

		if news_community == "escort" then
			return true
		end

		local faction = get_technical_faction_name(get_character_faction(character_id))
		if faction and (faction == news_community) then
			return true
		end
	end

	for _, witness in ipairs(event.witnesses or {}) do
		-- Defensive: check if witness and witness.game_id exist
		if witness and witness.game_id and tostring(witness.game_id) == tostring(character_id) then
			return true
		end
	end
	return false
end

return Event
