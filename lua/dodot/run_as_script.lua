#!/usr/bin/env lua
-- Script to test dodot commands before CLI implementation
-- Usage: lua run_as_script.lua <command> <dotfiles_root> [args...]

-- Add the lua directory to the package path so we can find dodot modules
-- This assumes the script is run from the project root
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local function print_usage()
    print("Usage: lua run_as_script.lua <command> <dotfiles_root> [args...]")
    print("")
    print("Commands:")
    print("  deploy [pack_names...]  - Deploy dotfiles (all packs if none specified)")
    print("  list                    - List available packs")
    print("  info <pack_name>        - Show pack information")
    print("")
    print("Options:")
    print("  --dry-run              - Show what would be done without executing (default)")
    print("  --execute              - Actually execute changes (overrides default dry-run)")
    print("  --verbose              - Show detailed output")
    print("")
    print("Examples:")
    print("  lua run_as_script.lua deploy /path/to/dotfiles")
    print("  lua run_as_script.lua deploy /path/to/dotfiles vim git --execute")
    print("  lua run_as_script.lua list /path/to/dotfiles")
end

local function parse_args(args)
    if #args < 2 then
        return nil, "Not enough arguments"
    end

    local command = args[1]
    local dotfiles_root = args[2]
    local pack_names = {}
    local options = {
        dry_run = true, -- Default to dry run for safety
        verbose = false
    }

    -- Parse remaining arguments
    for i = 3, #args do
        local arg = args[i]
        if arg == "--dry-run" then
            options.dry_run = true
        elseif arg == "--execute" then
            options.dry_run = false
        elseif arg == "--verbose" then
            options.verbose = true
        elseif not string.match(arg, "^%-%-") then
            table.insert(pack_names, arg)
        end
    end

    return {
        command = command,
        dotfiles_root = dotfiles_root,
        pack_names = pack_names,
        options = options
    }, nil
end

local function run_deploy(dotfiles_root, pack_names, options)
    print("🚀 Running deploy command...")
    print("📁 Dotfiles root: " .. dotfiles_root)

    if options.dry_run then
        print("🔍 DRY RUN MODE - No changes will be made")
    end

    if options.verbose then
        print("📝 Verbose mode enabled")
    end

    -- Import core modules
    local get_packs = require("dodot.core.get_packs")
    local get_firing_triggers = require("dodot.core.get_firing_triggers")
    local get_actions = require("dodot.core.get_actions")
    local get_fs_ops = require("dodot.core.get_fs_ops")
    local run_ops = require("dodot.core.run_ops")

    -- Step 1: Get pack candidates and validate packs
    print("\n📦 Step 1: Discovering packs...")
    local pack_candidates, err = get_packs.get_pack_candidates(dotfiles_root)
    if err then
        print("❌ Error getting pack candidates: " .. tostring(err))
        return false
    end

    print("   Found " .. #pack_candidates .. " pack candidates")
    if options.verbose then
        for _, candidate in ipairs(pack_candidates) do
            print("   - " .. candidate)
        end
    end

    local packs, err = get_packs.get_packs(pack_candidates)
    if err then
        print("❌ Error validating packs: " .. tostring(err))
        return false
    end

    -- Filter packs if specific pack names were provided
    if #pack_names > 0 then
        local filtered_packs = {}
        for _, pack in ipairs(packs) do
            for _, requested_name in ipairs(pack_names) do
                if pack.name == requested_name then
                    table.insert(filtered_packs, pack)
                    break
                end
            end
        end

        if #filtered_packs == 0 then
            print("❌ No matching packs found for: " .. table.concat(pack_names, ", "))
            return false
        end

        packs = filtered_packs
        print("   Filtered to " .. #packs .. " requested packs")
    end

    print("   Processing " .. #packs .. " packs:")
    for _, pack in ipairs(packs) do
        print("   - " .. pack.name .. " (" .. pack.path .. ")")
    end

    -- Step 2: Get firing triggers
    print("\n🎯 Step 2: Finding firing triggers...")
    local trigger_matches, err = get_firing_triggers.get_firing_triggers(packs)
    if err then
        print("❌ Error getting firing triggers: " .. tostring(err))
        return false
    end

    print("   Found " .. #trigger_matches .. " trigger matches")
    if options.verbose then
        for _, match in ipairs(trigger_matches) do
            print("   - " .. match.trigger_name .. " → " .. match.power_up_name .. " (" .. match.file_path .. ")")
        end
    end

    -- Step 3: Generate actions
    print("\n⚡ Step 3: Generating actions...")
    local actions, err = get_actions.get_actions(trigger_matches)
    if err then
        print("❌ Error generating actions: " .. tostring(err))
        return false
    end

    print("   Generated " .. #actions .. " actions")
    if options.verbose then
        for _, action in ipairs(actions) do
            print("   - " .. action.type .. ": " .. action.description)
        end
    end

    -- Step 4: Create filesystem operations
    print("\n💾 Step 4: Planning filesystem operations...")
    local operations, err = get_fs_ops.get_fs_ops(actions)
    if err then
        print("❌ Error creating filesystem operations: " .. tostring(err))
        return false
    end

    print("   Created " .. #operations .. " filesystem operations")
    if options.verbose or options.dry_run then
        for _, op in ipairs(operations) do
            print("   - " .. op.type .. ": " .. op.description)
        end
    end

    -- Step 5: Execute operations (unless dry run)
    if not options.dry_run then
        print("\n🔧 Step 5: Executing operations...")
        local success, err = run_ops.run_ops(operations)
        if err then
            print("❌ Error executing operations: " .. tostring(err))
            return false
        end

        if success then
            print("✅ Deploy completed successfully!")
        else
            print("⚠️  Deploy completed with warnings")
        end
    else
        print("\n🔍 Dry run complete - no changes made")
        print("   Would have executed " .. #operations .. " operations")
    end

    return true
end

local function run_list(dotfiles_root, options)
    print("📋 Listing available packs...")
    print("📁 Dotfiles root: " .. dotfiles_root)

    local get_packs = require("dodot.core.get_packs")
    local list_packs = require("dodot.core.list_packs")

    local pack_candidates, err = get_packs.get_pack_candidates(dotfiles_root)
    if err then
        print("❌ Error getting pack candidates: " .. tostring(err))
        return false
    end

    local packs, err = get_packs.get_packs(pack_candidates)
    if err then
        print("❌ Error validating packs: " .. tostring(err))
        return false
    end

    print("\nAvailable packs:")
    for _, pack in ipairs(packs) do
        print("  📦 " .. pack.name)
        if options.verbose then
            print("     Path: " .. pack.path)
        end
    end

    print("\nTotal: " .. #packs .. " packs")
    return true
end

local function run_info(dotfiles_root, pack_name, options)
    print("ℹ️  Showing pack information...")
    print("📁 Dotfiles root: " .. dotfiles_root)
    print("📦 Pack: " .. pack_name)

    -- This is a stub - info command would be implemented in Phase 6
    print("⚠️  Info command not yet implemented (Phase 6 deliverable)")
    print("   Would show what triggers and power-ups would be activated for pack: " .. pack_name)

    return true
end

-- Main execution
local function main(args)
    local parsed, err = parse_args(args)
    if err then
        print("❌ " .. err)
        print()
        print_usage()
        return 1
    end

    local command = parsed.command
    local dotfiles_root = parsed.dotfiles_root
    local pack_names = parsed.pack_names
    local options = parsed.options

    -- Validate dotfiles root exists
    local pl_path = require("pl.path")
    if not pl_path.isdir(dotfiles_root) then
        print("❌ Dotfiles root directory does not exist: " .. dotfiles_root)
        return 1
    end

    local success = false

    if command == "deploy" then
        success = run_deploy(dotfiles_root, pack_names, options)
    elseif command == "list" then
        success = run_list(dotfiles_root, options)
    elseif command == "info" then
        if #pack_names == 0 then
            print("❌ Info command requires a pack name")
            return 1
        end
        success = run_info(dotfiles_root, pack_names[1], options)
    else
        print("❌ Unknown command: " .. command)
        print()
        print_usage()
        return 1
    end

    return success and 0 or 1
end

-- Run if called as script
if arg and arg[0] and arg[0]:match("run_as_script%.lua$") then
    local exit_code = main(arg)
    os.exit(exit_code)
end

-- Also return the main function for require() usage
return { main = main }
