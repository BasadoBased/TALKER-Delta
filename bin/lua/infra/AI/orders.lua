-- orders.lua
-- Order system for managing AI dialogue requests with queue control
-- Inspired by Agent.ts from the TypeScript implementation

local logger = require("framework.logger")
local transformations = require("infra.AI.transformations")
local prompt_builder = require("infra.AI.prompt_builder")
local dialogue_cleaner = require("infra.AI.dialogue_cleaner")
local memory_store = require("domain.repo.memory_store")
local game = require("infra.game_adapter")

-- Game interface
local query = talker_game_queries

------------------------------------------------------------------------------------------
-- Order class
------------------------------------------------------------------------------------------
local Order = {}
Order.__index = Order

-- Order states
local OrderState = {
	NEW = "new",
	IN_PROGRESS = "in_progress",
	COMPLETE = "complete",
	ERROR = "error",
}

function Order.new(speaker_id, callback)
	local self = setmetatable({}, Order)
	self.speaker_id = speaker_id
	self.callback = callback
	self.state = OrderState.NEW
	self.response = nil
	self.error = nil
	return self
end

function Order:is_active()
	return self.state == OrderState.IN_PROGRESS
end

function Order:is_complete()
	return self.state == OrderState.COMPLETE
end

function Order:has_error()
	return self.state == OrderState.ERROR
end

function Order:mark_in_progress()
	self.state = OrderState.IN_PROGRESS
	logger.info("Order marked as in_progress for speaker: " .. self.speaker_id)
end

function Order:mark_complete()
	self.state = OrderState.COMPLETE
	logger.info("Order marked as complete for speaker: " .. self.speaker_id)
end

function Order:mark_error(err)
	self.state = OrderState.ERROR
	self.error = err
	logger.error("Order marked as error for speaker: " .. self.speaker_id .. " - " .. tostring(err))
end

------------------------------------------------------------------------------------------
-- OrderManager class
------------------------------------------------------------------------------------------
local OrderManager = {}
OrderManager.__index = OrderManager

-- Singleton instance
local instance = nil

function OrderManager.get_instance()
	if not instance then
		instance = setmetatable({}, OrderManager)
		instance.orders = {} -- All orders
		instance.active_per_speaker = {} -- Track active orders per speaker
	end
	return instance
end

-- Check if an order already exists for a speaker (queued or in progress)
function OrderManager:is_speaker_queued(speaker_id)
	for _, order in ipairs(self.orders) do
		if order.speaker_id == speaker_id and not order:is_complete() then
			return true
		end
	end
	return false
end

-- Check if a speaker currently has an active order
function OrderManager:is_speaker_active(speaker_id)
	return self.active_per_speaker[tostring(speaker_id)] ~= nil
end

-- Add a new order to the queue
-- Duplicates are allowed - they'll run after the speaker's current order finishes
function OrderManager:add_order(speaker_id, callback)
	-- Allow duplicate orders - they'll be processed after current order completes
	-- The queue processing ensures only one active order per speaker at a time

	local order = Order.new(speaker_id, callback)
	table.insert(self.orders, order)
	logger.info("Added order for speaker: " .. speaker_id .. " (queue size: " .. #self.orders .. ")")

	-- Try to process the queue
	self:process_queue()

	return order
end

-- Mark an order as complete and process next orders
function OrderManager:complete_order(order)
	if order then
		order:mark_complete()
		-- Clear active status for this speaker
		self.active_per_speaker[tostring(order.speaker_id)] = nil
		logger.info("Order completed for speaker: " .. order.speaker_id)
	end

	-- Process remaining orders in queue
	self:process_queue()
end

-- Mark an order as errored and process next orders
function OrderManager:error_order(order, err)
	if order then
		order:mark_error(err)
		-- Clear active status for this speaker
		self.active_per_speaker[tostring(order.speaker_id)] = nil
	end

	-- Process remaining orders in queue
	self:process_queue()
end

-- Process the queue: start orders for speakers that don't have active orders
function OrderManager:process_queue()
	-- Clean up completed orders from the list
	local new_orders = {}
	for _, order in ipairs(self.orders) do
		if not order:is_complete() then
			table.insert(new_orders, order)
		end
	end
	self.orders = new_orders

	-- Find the next order to process
	for _, order in ipairs(self.orders) do
		local speaker_id_str = tostring(order.speaker_id)

		-- Skip if this speaker already has an active order
		if self.active_per_speaker[speaker_id_str] then
		-- Skip if order is already complete or errored
		elseif order:is_complete() or order:has_error() then
			-- skip
		else
			-- Mark this speaker as active
			self.active_per_speaker[speaker_id_str] = order
			order:mark_in_progress()

			-- Execute the order
			self:execute_order(order)
		end
	end
end

-- Execute a single order (generate dialogue)
function OrderManager:execute_order(order)
	local speaker_id = order.speaker_id

	logger.info("Executing order for speaker: " .. speaker_id)

	-- Get memory context
	local memory_context = memory_store:get_memory_context(speaker_id)

	-- Inject time gap if applicable
	local current_game_time = query and query.get_game_time_ms() or 0
	memory_context.new_events = transformations.inject_time_gaps(
		memory_context.new_events,
		memory_context.last_update_time_ms,
		current_game_time
	)

	-- SLICING OPTIMIZATION
	local MAX_DIALOGUE_EVENTS = 5000
	if memory_context.new_events and #memory_context.new_events > MAX_DIALOGUE_EVENTS then
		logger.info(
			"Too many new events for dialogue context ("
				.. #memory_context.new_events
				.. "). Slicing to last "
				.. MAX_DIALOGUE_EVENTS
		)
		local sliced_events = {}
		local start_index = #memory_context.new_events - MAX_DIALOGUE_EVENTS + 1
		for i = start_index, #memory_context.new_events do
			table.insert(sliced_events, memory_context.new_events[i])
		end
		memory_context.new_events = sliced_events
	end

	-- Safety check
	if (not memory_context.new_events or #memory_context.new_events == 0) and not memory_context.narrative then
		logger.info("Requesting dialogue with absolutely no context (no narrative, no events).")
	end

	logger.info("Requesting prompt generation. IF YOU JUST CRASHED, DISABLE LOG TO CONSOLE IN MCM===================================================================")

	-- Get speaker character
	local speaker_character = self:get_character_by_id(speaker_id, memory_context.new_events)
	local messages, timestamp_to_delete = prompt_builder.create_dialogue_request_prompt(speaker_character, memory_context)

	-- Get the model
	local model = self:get_model()


	-- Call the model to generate dialogue
	model.generate_dialogue(messages, function(generated_dialogue)
		-- Handle response
		if generated_dialogue == nil then
			logger.error("Error generating dialogue for speaker: " .. speaker_id)
			order:mark_error("nil response")
			self.active_per_speaker[tostring(speaker_id)] = nil
			self:process_queue()
			return
		end

		-- Validate response against policy/junk filters
		if not dialogue_cleaner.was_response_valid(generated_dialogue) then
			logger.warn("AI response rejected by validation filter for speaker: " .. speaker_id)
			order:mark_error("validation failed")
			self.active_per_speaker[tostring(speaker_id)] = nil
			self:process_queue()
			return
		end

		logger.info("Received dialogue for speaker " .. speaker_id .. ": " .. generated_dialogue)
		generated_dialogue = dialogue_cleaner.improve_response_text(generated_dialogue)

		-- Mark order complete and call callback
		order:mark_complete()
		self.active_per_speaker[tostring(speaker_id)] = nil

		if order.callback then
			order.callback(generated_dialogue, timestamp_to_delete)
		end

		-- Process next orders
		self:process_queue()
	end)
end

-- Helper to get character by ID (moved from AI_request)
function OrderManager:get_character_by_id(speaker_id, search_events)
	logger.info("Getting character name for ID: " .. speaker_id)

	-- 1. Prefer Engine Lookup
	local engine_char = game.get_character_by_id(speaker_id)
	if engine_char then
		logger.info("Character found via Engine Lookup: " .. speaker_id)
		return engine_char
	end

	-- 2. Fallback to Local Context
	if search_events then
		for _, event in ipairs(search_events) do
			if event.witnesses then
				for _, witness in ipairs(event.witnesses) do
					if tostring(witness.game_id) == tostring(speaker_id) then
						return witness
					end
				end
			end
			if event.involved_objects then
				for _, obj in ipairs(event.involved_objects) do
					if tostring(obj.game_id) == tostring(speaker_id) then
						return obj
					end
				end
			end
		end
	end

	-- 3. Fallback to global witnesses (if available)
	local witnesses = AI_request and AI_request.witnesses or {}
	for _, witness in ipairs(witnesses) do
		if tostring(witness.game_id) == tostring(speaker_id) then
			return witness
		end
	end

	error("No character found for ID: " .. tostring(speaker_id))
end

-- Helper to get the current model
function OrderManager:get_model()
	local config = require("interface.config")
	local gpt_model = require("infra.AI.GPT")
	local openrouter = require("infra.AI.OpenRouterAI")
	local local_model = require("infra.AI.local_ollama")
	local proxy_model = require("infra.AI.proxy")

	local ModelList = {
		[0] = gpt_model,
		[1] = openrouter,
		[2] = local_model,
		[3] = proxy_model,
	}

	return ModelList[config.modelmethod()]
end

-- Check if any order has errored
function OrderManager:has_errors()
	for _, order in ipairs(self.orders) do
		if order:has_error() then
			return true
		end
	end
	return false
end

-- Check if any order is in progress
function OrderManager:is_any_in_progress()
	for _, order in ipairs(self.orders) do
		if order:is_active() then
			return true
		end
	end
	return false
end

-- Get queue status for debugging
function OrderManager:get_status()
	local status = {
		total_orders = #self.orders,
		active_speakers = {},
		errors = 0,
	}

	for speaker_id, _ in pairs(self.active_per_speaker) do
		table.insert(status.active_speakers, speaker_id)
	end

	for _, order in ipairs(self.orders) do
		if order:has_error() then
			status.errors = status.errors + 1
		end
	end

	return status
end



-- Export
return {
	Order = Order,
	OrderManager = OrderManager,
	get_manager = OrderManager.get_instance,
}