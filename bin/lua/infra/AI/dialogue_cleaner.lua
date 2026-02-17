local m = {}
-- Imports
package.path = package.path .. ";./bin/lua/?.lua;"
local logger = require("framework.logger")

----------------------------------------------------------------------------------------------------------------------------
-- FUN POLICE WEE WOO WEE WOO
----------------------------------------------------------------------------------------------------------------------------
-- Checks if the AI responded with a rejection message
-- @param response string -- The response from the AI
local function was_request_too_spicy(response)
	local rejectionStrings = {
		"I'm sorry, but I cannot",
		"I apologize, but I",
		"assist you with that",
		"help with that request",
		"I cannot fulfill",
		"I cannot generate",
		"I cannot complete",
		"As an AI language model",
		"AI assistant",
		"hate speech",
		"safety guidelines",
		"content guidelines",
		"ethical guidelines",
		"usage policies",
		"use-case policy",
		"openAI",
		"I am not able to provide",
		"Content is not allowed",
		"Unable to comply with this request",
		"not programmed",
		"against my programming",
		"inappropriate content",
		"vulgar content",
		"prohibited content",
		"If you have any other inquiries",
	}

	for _, str in ipairs(rejectionStrings) do
		if response:find(str, 1, true) then
			logger.info("FUN POLICE DETECTED: " .. response, 3)
			return true -- Rejected string found
		end
	end

	return false -- No rejected strings found
end

-- Determines if the AI response is valid based on text content
-- @param response_text string -- The response text to validate
function m.was_response_valid(response_text)
	return response_text and not was_request_too_spicy(response_text)
end

----------------------------------------------------------------------------------------------------------------------------
-- RESTORE PROFANITY
----------------------------------------------------------------------------------------------------------------------------

-- Restores profanity and logs changes
-- @param response_text string -- The response text to process
local function uncensor(response_text)
	local swear_map = {
		["s[%*]+h[%*]+i[%*]+t[%*]*"] = "shit",
		["f[%*]+u[%*]+c[%*]+k[%*]*"] = "fuck",
		["f%*%*k"] = "fuck",
		["sh%*t"] = "shit",
		["f%*ck"] = "fuck",
		["b[%*]+a[%*]+s[%*]+t[%*]+a[%*]+r[%*]+d[%*]*"] = "bastard",
		[".expletive."] = "piece of shit",
		["%[expletive%]"] = "piece of shit",
		["wanker"] = "asshole",
	}

	local changes_made = false

	for censored, uncensored in pairs(swear_map) do
		local new_text, changes = response_text:gsub(censored, uncensored)
		if changes > 0 then
			changes_made = true
			response_text = new_text
			logger.debug(
				"UNCENSORED: Replaced '" .. censored .. "' with '" .. uncensored .. "' " .. changes .. " times.",
				1
			)
		end
	end

	if changes_made then
		logger.info("Final uncensored text: " .. response_text, 2)
	else
		logger.spam("No changes made to the text.", 0)
	end

	return response_text
end

-- Improves response text by cleaning quotation marks and uncensoring profanity
-- @param response_text string -- The text to improve
function m.improve_response_text(response_text)
	-- Clean quotation marks as well as an accidental speaker label
	local clean_response = response_text
	-- Handle firstname and lastname with or without quotes
	-- remove "said" if it's in the first part of the string before :
	clean_response = clean_response:gsub(" said:", ":")
	clean_response = clean_response:gsub("^[%w_]+%s*[%w_]*:%s*[\"“”']?(.-)[\"“”']?$", "%1")
	-- Handle strings with leading and trailing quotes, including special quote characters
	clean_response = clean_response:gsub("^[\"“”'](.-)[\"“”']$", "%1")
	-- Remove censorship like asterisks and replace with the uncensored version
	local dirty_response = uncensor(clean_response)
	return dirty_response
end
return m
