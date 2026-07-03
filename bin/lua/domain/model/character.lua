package.path = package.path .. ";./bin/lua/?.lua;"
local backstories = require("domain.repo.backstories")
local personalities = require("domain.repo.personalities")
local log = require("framework.logger")

-- Character class definition
Character = {}

function Character.new(game_id, name, experience, faction, reputation, weapon, visual_faction, weapon_status, game_obj)
	new_char = {
		game_id = game_id,
		game_obj = game_obj,
		name = name,
		faction = faction,
		experience = experience,
		reputation = reputation,
		weapon = weapon,
		visual_faction = visual_faction,
		weapon_status = weapon_status,
	}
	new_char.backstory = backstories.get_backstory(new_char)
	new_char.personality = personalities.get_personality(new_char)
	new_char.health = game_obj.health -- patch for that one injury thing 
	return new_char
end



function Character.set_backstory(character, backstory)
	character.backstory = backstory
end

function Character.set_personality(character, personality)
	character.personality = personality
end

function Character.describe(character)
	local description = string.format(
		"%s, a %s rank member of the %s faction who is %s",
		character.name,
		character.experience,
		character.faction,
		character.personality
	)
	if character.weapon then
		if character.weapon_status == "holstered" then
			description = description .. " with a holstered " .. character.weapon
		else
			description = description .. " wielding a " .. character.weapon
		end
	end
	return description
end

function Character.describe_short(character)
	return character.name
end

return Character

--------------------------
-- Notes (Dan):
-- I decided to use simple data structures for easier serialization and deserialization.
-- I also decided to use a separate module for the personality logic to keep the Character module clean and focused on character-related functionality.

-- Notes (Coelacanth):
-- Character backstory is omitted from the character.describe function to reduce clutter and improve parseability of the speaker picking function.
