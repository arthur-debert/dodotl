-- spec/unit/core/get_packs_spec.lua
local get_packs_module = require("dodot.core.get_packs")
local pl_path = require("pl.path") -- for mkdir, touch, etc.
local pl_file = require("pl.file") -- for write (if needed for touch equivalent)
local test_utils = require("spec.helpers.test_utils")

describe("dodot.core.get_packs", function()
    local temp_dir

    before_each(function()
        temp_dir = test_utils.fs.create_temp_dir()
    end)

    after_each(function()
        test_utils.fs.cleanup_temp_dir(temp_dir) -- Corrected helper name
    end)

    describe("get_pack_candidates()", function()
        it("should return list of directory paths for valid root, excluding non-dirs and hidden", function()
            pl_path.mkdir(temp_dir .. "/pack1")
            pl_path.mkdir(temp_dir .. "/pack2")
            -- Create a file to ensure it's ignored
            local f_ok, f_err = pl_file.write(temp_dir .. "/file.txt", "content", true) -- Added true for create
            assert(f_ok, "Failed to create file.txt: " .. (f_err or ""))

            pl_path.mkdir(temp_dir .. "/.hidden_pack") -- Hidden
            pl_path.mkdir(temp_dir .. "/.another.hidden") -- Hidden with dots

            local candidates, err = get_packs_module.get_pack_candidates(temp_dir)

            assert.is_nil(err, "get_pack_candidates returned an error: " .. (err and err.message or "unknown"))
            assert.is_table(candidates)

            local candidate_names = {}
            for _, p in ipairs(candidates) do table.insert(candidate_names, pl_path.basename(p)) end
            table.sort(candidate_names) -- For consistent order in test

            assert.are.same({ "pack1", "pack2" }, candidate_names)
        end)

        it("should return empty list for empty root", function()
            local candidates, err = get_packs_module.get_pack_candidates(temp_dir)
            assert.is_nil(err)
            assert.are.same({}, candidates)
        end)

        it("should return error for non-existent root", function()
            local candidates, err = get_packs_module.get_pack_candidates(temp_dir .. "/nonexistent")
            assert.is_nil(candidates)
            assert.is_table(err)
            assert.equals("INVALID_DOTFILES_ROOT", err.code)
        end)

        it("should handle root with only hidden items or files", function()
            pl_path.mkdir(temp_dir .. "/.hidden")
            pl_file.write(temp_dir .. "/a_file.txt", "content", true) -- Added true for create
            local candidates, err = get_packs_module.get_pack_candidates(temp_dir)
            assert.is_nil(err)
            assert.is_table(candidates)
            assert.equals(0, #candidates)
        end)
    end)

    describe("get_packs()", function()
        it("should convert candidate paths to Pack objects", function()
            -- Manually create dirs for this test as get_pack_candidates is tested separately
            local packA_path = pl_path.join(temp_dir, "packA")
            local packB_path = pl_path.join(temp_dir, "packB")
            pl_path.mkdir(packA_path)
            pl_path.mkdir(packB_path)

            local candidate_paths = { packA_path, packB_path }
            local packs, err = get_packs_module.get_packs(candidate_paths)

            assert.is_nil(err)
            assert.is_table(packs)
            assert.equals(2, #packs)

            -- Sort packs by name for consistent checking
            table.sort(packs, function(a,b) return a.name < b.name end)

            assert.equals(packA_path, packs[1].path)
            assert.equals("packA", packs[1].name)
            assert.is_nil(packs[1].config)

            assert.equals(packB_path, packs[2].path)
            assert.equals("packB", packs[2].name)
            assert.is_nil(packs[2].config)
        end)

        it("should return empty list for empty candidates", function()
            local packs, err = get_packs_module.get_packs({})
            assert.is_nil(err)
            assert.are.same({}, packs)
        end)

        it("should return error if pack_candidate_paths is nil", function()
            local packs, err = get_packs_module.get_packs(nil)
            assert.is_nil(packs)
            assert.is_not_nil(err)
            assert.equals("UNKNOWN_ERROR_CODE", err.code) -- Or a more specific one like INVALID_INPUT
            assert.matches("pack_candidate_paths cannot be nil", err.message, 1, true) -- Busted's plain match
        end)
    end)
end)
