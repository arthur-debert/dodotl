-- lua/dodot/ui.lua
-- UI and output formatting module

local M = {}

-- Helper function to truncate and pad strings
local function format_label(text, width)
    if not text then text = "" end
    text = tostring(text)
    if #text > width then
        text = text:sub(1, width)
    end
    return string.format("%-" .. width .. "s", text)
end

-- Helper function to truncate pack names to 10 chars, left-aligned
local function format_pack_name(pack_name, width)
    width = width or 10
    if not pack_name then pack_name = "" end
    pack_name = tostring(pack_name)
    if #pack_name > width then
        pack_name = pack_name:sub(1, width)
    end
    return string.format("%-" .. width .. "s", pack_name)
end

-- Helper function to truncate power-up names to 10 chars, left-aligned
local function format_powerup_name(powerup_name, width)
    width = width or 10
    if not powerup_name then return string.rep(" ", width) end
    powerup_name = tostring(powerup_name)

    -- Shorten common powerup names
    local shortened = {
        shell_profile = "shell_prof",
        shell_add_path = "shell_path",
        script_runner = "script_run",
        symlink = "link"
    }
    powerup_name = shortened[powerup_name] or powerup_name

    if #powerup_name > width then
        powerup_name = powerup_name:sub(1, width)
    end
    return string.format("%-" .. width .. "s", powerup_name)
end

-- Convert action to human-readable description
local function action_to_description(action)
    local desc = action.description or ""

    -- Extract more detailed path information from existing description
    if action.type == "shell_source" then
        if desc:match("Export variables") then
            local filename = desc:match("Export variables from ([^%s]+)")
            if filename then
                local dirname = filename:match("([^/]+)/[^/]+$") or "pack"
                local basename = filename:match("([^/]+)$") or filename
                return "Export vars from " .. dirname .. "/" .. basename
            end
            return "Export variables"
        else
            local filename = desc:match("Source ([^%s]+)")
            if filename then
                local dirname = filename:match("([^/]+)/[^/]+$") or "pack"
                local basename = filename:match("([^/]+)$") or filename
                return "Source " .. dirname .. "/" .. basename
            end
            return "Source file"
        end
    elseif action.type == "shell_add_path" then
        local path = desc:match("Add ([^%s]+) to PATH")
        if path then
            local dirname = path:match("([^/]+)$") or "directory"
            return "Add " .. dirname .. "/ to $PATH"
        end
        return "Add directory to $PATH"
    elseif action.type == "brew_install" then
        local filename = desc:match("Process Brewfile ([^%s]+)")
        if filename then
            local dirname = filename:match("([^/]+)/[^/]+$") or "pack"
            return "Process " .. dirname .. "/Brewfile"
        end
        return "Process Brewfile"
    elseif action.type == "link" then
        local source = desc:match("Link [^%s]+ ([^%s]+) to")
        local target = desc:match("to ([^%s]+)$")
        if source and target then
            local source_name = source:match("([^/]+)$") or source
            if target:match("/.config/") then
                local config_path = target:match("/.config/(.+)")
                return "Link " .. source_name .. " → ~/.config/" .. (config_path or "")
            elseif target:match("/%.") then
                local home_file = target:match("/([^/]+)$")
                return "Link " .. source_name .. " → ~/" .. (home_file or "")
            else
                local target_name = target:match("([^/]+)$") or target
                return "Link " .. source_name .. " → " .. target_name
            end
        end
        return "Create symlink"
    end

    -- Fallback to original description
    return desc
end

-- Group actions by pack for concise output
local function group_actions_by_pack(actions)
    local grouped = {}
    local pack_order = {}

    for _, action in ipairs(actions) do
        local pack_name = action.metadata and action.metadata.pack_name or "unknown"
        if not grouped[pack_name] then
            grouped[pack_name] = {}
            table.insert(pack_order, pack_name)
        end
        table.insert(grouped[pack_name], action)
    end

    return grouped, pack_order
end

-- Print deployment results in concise format (default)
function M.print_deploy_concise(report)
    local grouped_actions, pack_order = group_actions_by_pack(report.actions)

    for _, pack_name in ipairs(pack_order) do
        local pack_actions = grouped_actions[pack_name]
        local formatted_pack = format_pack_name(pack_name, 10)

        -- Print pack processed header
        print(string.format("[ %s ] processed", formatted_pack))

        -- Print each action for this pack
        for _, action in ipairs(pack_actions) do
            local powerup = format_powerup_name(action.metadata and action.metadata.power_up_name or "", 10)
            local description = action_to_description(action)
            print(string.format("[ %s ] %s - %s", formatted_pack, powerup, description))
        end
    end
end

-- Print deployment results in verbose format
function M.print_deploy_verbose(report)
    print("🚀 Running deploy command...")
    print("📁 Dotfiles root: " .. (report.dotfiles_root or ""))
    if report.dry_run then
        print("🔍 DRY RUN MODE - No changes will be made")
    end
    print()

    -- Step 1: Packs
    print("📦 Step 1: Discovering packs...")
    print("   Found " .. #report.packs .. " pack candidates")
    print("   Processing " .. #report.packs .. " packs:")
    for _, pack in ipairs(report.packs) do
        print("   - " .. pack.name .. " (" .. pack.path .. ")")
    end
    print()

    -- Step 2: Triggers
    print("🎯 Step 2: Finding firing triggers...")
    print("   Found " .. #report.trigger_matches .. " trigger matches")
    for _, match in ipairs(report.trigger_matches) do
        print("   - " .. match.trigger_name .. " → " .. match.power_up_name .. " (" .. match.file_path .. ")")
    end
    print()

    -- Step 3: Actions
    print("⚡ Step 3: Generating actions...")
    print("   Generated " .. #report.actions .. " actions")
    for _, action in ipairs(report.actions) do
        print("   - " .. action.type .. ": " .. action.description)
    end
    print()

    -- Step 4: Operations
    print("💾 Step 4: Planning filesystem operations...")
    if report.warnings and #report.warnings > 0 then
        for _, warning in ipairs(report.warnings) do
            print("Warning: " .. warning)
        end
    end
    print("   Created " .. #report.fs_ops .. " filesystem operations")
    for _, op in ipairs(report.fs_ops) do
        print("   - " .. op.type .. ": " .. op.description)
    end
    print()

    if report.dry_run then
        print("🔍 Dry run complete - no changes made")
    else
        print("✅ Deployment complete!")
    end
end

return M
