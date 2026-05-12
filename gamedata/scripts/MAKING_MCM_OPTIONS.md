# Making MCM Options in TALKER Expanded

This guide explains how to add new configuration options to the MCM (Mod Configuration Menu) in TALKER Expanded and how to use them in your scripts.

## Table of Contents

1. [Overview](#overview)
2. [Adding Options to MCM](#adding-options-to-mcm)
3. [Reading MCM Values](#reading-mcm-values)
4. [Control Types Reference](#control-types-reference)
5. [Best Practices](#best-practices)

---

## Overview

TALKER Expanded uses an MCM system for user-configurable options. The MCM is defined in `talker_mcm.script` and provides a way for users to configure the mod through a GUI menu.

The MCM system provides:
- A `get(key)` function to retrieve configuration values
- Multiple control types (checkboxes, sliders, radio buttons, text inputs, etc.)
- Localization support via string keys

---

## Adding Options to MCM

### Step 1: Open talker_mcm.script

Navigate to `gamedata/scripts/talker_mcm.script` and locate the `on_mcm_load()` function.

### Step 2: Add Your Option to the Group

Options are added to the `gr` table within the `op` table. Each option is a Lua table with specific properties.

```lua
-- filepath: gamedata/scripts/talker_mcm.script
{
    id = "your_option_id",
    type = "check",  -- control type
    val = 1,         -- value type (1 for boolean, 2 for number)
    def = true,      -- default value
},
```

### Step 3: Add Default Value

Add your default value to the `defaults` table at the bottom of the file:

```lua
local defaults = {
    -- ... existing defaults ...
    ["your_option_id"] = true,
}
```

### Example: Add a precise time option

This example adds a checkbox to the general configuration group and uses it in `talker_game_queries.script` to switch `describe_current_time()` between phrase-based output and exact date/time output.

```lua
-- gamedata/scripts/talker_mcm.script
{
    id = "precise_time",
    type = "check",
    val = 1,
    def = false,
},
```

```lua
-- gamedata/scripts/talker_game_queries.script
if talker_mcm.get("precise_time") then
    -- return "November 19 at 22:34" instead of "morning"/"evening"
end
```

---

## Reading MCM Values

### In gamedata/scripts/*.script Files

In script files located in `gamedata/scripts/`, the MCM is available as a global `talker_mcm` table:

```lua
-- filepath: gamedata/scripts/your_script.script
local my_value = talker_mcm.get("your_option_id")
```

### In bin/lua/*.lua Files

In Lua files located in `bin/lua/`, the MCM is accessed via the global `mcm`:

```lua
-- filepath: bin/lua/your_module.lua
local my_value = mcm.get("your_option_id")
```

### Example: Using MCM in a Trigger Script

```lua
-- filepath: gamedata/scripts/talker_trigger_callout.script
local game = require("infra.game_adapter")
local mcm = talker_mcm  -- Access MCM in gamedata/scripts

-- Read MCM values at script load
local callout_cooldown_ms = mcm.get("callout_cooldown") * 1000
local MAX_CALLOUT_DISTANCE = mcm.get("max_callout_distance")

function on_enemy_eval(npc_obj, target_obj)
    -- Check if trigger is enabled
    if not mcm.get("enable_trigger_callout") then return end
    
    -- Use the values
    local distance = queries.get_distance_between(npc_obj, target_obj)
    if distance > MAX_CALLOUT_DISTANCE then return end
    
    -- ... rest of logic
end
```

---

## Control Types Reference

### Checkbox (Boolean)

```lua
{
    id = "my_checkbox",
    type = "check",
    val = 1,
    def = true,  -- or false
},
```

**Reading:** Returns `true` or `false`

---

### Track (Slider)

```lua
{
    id = "my_slider",
    type = "track",
    val = 2,       -- 2 = numeric
    min = 0,
    max = 100,
    step = 1,
    def = 50,
},
```

**Reading:** Returns a number

---

### Radio Horizontal

```lua
{
    id = "my_radio",
    type = "radio_h",
    val = "0",     -- string value
    def = "0",
    content = {
        {"0", "option_one"},
        {"1", "option_two"},
        {"2", "option_three"},
    },
},
```

**Reading:** Returns the selected key (e.g., "0", "1", "2")

---

### Input (Text)

```lua
{
    id = "my_input",
    type = "input",
    val = "string",
    def = "default_value",
},
```

**Reading:** Returns a string

---

### Key Bind

```lua
{
    id = "my_keybind",
    type = "key_bind",
    val = 2,
    def = DIK_keys.DIK_LMENU,
},
```

**Reading:** Returns a DIK key code

---

### Description (Label)

```lua
{
    id = "my_title",
    type = "desc",
    clr = {200, 200, 255, 200},  -- RGBA color
    text = "ui_mcm_talker_my_title",
},
```

**Note:** Descriptions don't return values; they're purely visual.

---

### Slide (Section Header)

```lua
{
    id = "my_section",
    type = "slide",
    link = "ui_options_slider_player",
    text = "ui_mcm_talker_my_section",
    size = {512, 50},
    spacing = 20,
},
```

**Note:** Slides create visual section headers in the MCM menu.

---

## Best Practices

### 1. Use Descriptive IDs

Choose clear, unique IDs for your options:

```lua
-- Good
id = "enable_trigger_callout"
id = "max_callout_distance"

-- Avoid
id = "opt1"
id = "val"
```

### 2. Add Localization Keys

For user-facing text, use localization keys instead of hardcoded strings:

```lua
-- In your option
text = "ui_mcm_talker_your_option"

-- This requires adding the string to localization files
-- (configs/text/eng/talker_mcm.xml, you can ignore Russian)
```

The XML format for localization strings is:

```xml
<!-- configs/text/eng/talker_mcm.xml -->
<string id="ui_mcm_talker_your_option">
    <text>Your Option Display Text</text>
</string>
```
Always add text to options and keep it up to date when making new ones or updating old ones, even if not asked.

### 3. Set Appropriate Defaults

Choose sensible default values that work for most users:

```lua
-- Good: Reasonable defaults
def = 30          -- 30 seconds for cooldown
def = true        -- Enable by default for useful features

-- Avoid: Extreme or confusing defaults
def = 999999      -- Unreasonably high
def = false       -- Disable important features by default
```

### 4. Document Your Options

Add description fields to help users understand what each option does:

```lua
{
    id = "your_option_title",
    type = "desc",
    clr = {200, 200, 255, 200},
    text = "ui_mcm_talker_your_option_title"
},
{
    id = "your_option_description",
    type = "desc",
    text = "ui_mcm_talker_your_option_description"
},
{
    id = "your_option",
    type = "check",
    val = 1,
    def = true,
},
```

### 5. Group Related Options

Use slides and descriptions to organize related options together:

```lua
-- Section Header
{id = "triggers_title", type = "slide", link = "ui_options_slider_player", text = "ui_mcm_talker_triggers_title", size = {512, 50}, spacing = 20},

-- Group Description
{id = "trigger_callout_title", type = "desc", clr = {200, 200, 255, 200}, text = "ui_mcm_talker_trigger_callout_title"},

-- Options
{id = "enable_trigger_callout", type = "check", val = 1, def = true},
{id = "max_callout_distance", type = "track", val = 2, min = 5, max = 100, step = 1, def = 30},
```

### 6. Handle Value Types Correctly

When reading values, be aware of the return type:

```lua
-- Checkbox returns boolean
local enabled = mcm.get("enable_trigger_callout")
if enabled then
    -- ...
end

-- Track returns number
local distance = mcm.get("max_callout_distance")

-- Radio returns string (even for numbers!)
local method = mcm.get("ai_model_method")  -- Returns "0", "1", "2", etc.
local num_method = tonumber(method)        -- Convert to number if needed

-- Input returns string
local model = mcm.get("custom_ai_model")
```

### 7. Consider Cooldowns and Limits

When adding numeric options, consider adding appropriate limits and cooldowns:

```lua
{
    id = "my_cooldown",
    type = "input",
    val = 2,        -- numeric input
    min = 0,        -- minimum value
    max = 3600,     -- maximum value (1 hour in seconds)
    def = 30,       -- default 30 seconds
},
```

---

## Complete Example

Here's a complete example of adding a new trigger option:

### 1. Add to MCM (talker_mcm.script)

```lua
-- In the triggers group section
{
    id = "trigger_custom_title",
    type = "desc",
    clr = {200, 200, 255, 200},
    text = "ui_mcm_talker_trigger_custom_title"
},
{
    id = "enable_trigger_custom",
    type = "check",
    val = 1,
    def = true,
},
{
    id = "custom_cooldown",
    type = "input",
    val = 2,
    min = 0,
    max = 3600,
    def = 60,
},
```

### 2. Add Defaults

```lua
local defaults = {
    -- ... existing defaults ...
    ["enable_trigger_custom"] = true,
    ["custom_cooldown"] = 60,
}
```

### 3. Use in Your Script

```lua
-- filepath: gamedata/scripts/talker_trigger_custom.script
local mcm = talker_mcm
local event_store = require("domain.repo.event_store")

local last_trigger_time = 0

function on_custom_event()
    -- Check if enabled
    if not mcm.get("enable_trigger_custom") then return end
    
    -- Check cooldown
    local cooldown_ms = mcm.get("custom_cooldown") * 1000
    local current_time = game.get_game_time_ms()
    
    if (current_time - last_trigger_time) < cooldown_ms then
        return
    end
    
    last_trigger_time = current_time
    
    -- ... trigger logic
end
```

---

## Summary

| Task | Method |
|------|--------|
| Add MCM option | Edit `talker_mcm.script`, add to `gr` table |
| Set default | Add to `defaults` table |
| Read in gamedata/scripts | `talker_mcm.get("option_id")` |
| Read in bin/lua | `mcm.get("option_id")` |
| Control types | `check`, `track`, `radio_h`, `input`, `key_bind`, `desc`, `slide` |

For more examples, examine the existing options in [talker_mcm.script](talker_mcm.script) or trigger scripts like [talker_trigger_callout.script](talker_trigger_callout.script).

-- The Above is AI Generated | Take it with a grain of salt --