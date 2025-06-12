-- Test utilities for dodot testing framework
-- Provides common testing patterns and helpers

local M = {}

-- Mock filesystem helpers
M.fs = {}

function M.fs.create_temp_dir()
    -- Create temporary directory for testing
    local temp_dir = "/tmp/dodot_test_" .. os.time()
    os.execute("mkdir -p " .. temp_dir)
    return temp_dir
end

function M.fs.cleanup_temp_dir(dir)
    -- Clean up temporary directory
    if dir and dir:match("^/tmp/dodot_test_") then
        os.execute("rm -rf " .. dir)
    end
end

function M.fs.create_test_files(dir, files)
    -- Create test files with content
    -- files is a table like { ["file.txt"] = "content", ["dir/file2.txt"] = "content2" }
    for file_path, content in pairs(files) do
        local full_path = dir .. "/" .. file_path
        local dir_part = full_path:match("(.+)/[^/]+$")
        if dir_part then
            os.execute("mkdir -p " .. dir_part)
        end
        local file = io.open(full_path, "w")
        if file then
            file:write(content)
            file:close()
        end
    end
end

-- Error testing helpers
M.errors = {}

function M.errors.assert_error_code(expected_code, result, err)
    -- Helper to test error codes consistently
    assert.is_nil(result, "Expected operation to fail but got result")
    assert.is_not_nil(err, "Expected error but got nil")
    assert.is_table(err, "Expected error to be a table")
    assert.equals(expected_code, err.code, "Error code mismatch")
end

function M.errors.assert_success(result, err)
    -- Helper to test successful operations
    assert.is_nil(err, "Expected success but got error: " .. (err and err.message or "unknown"))
    assert.is_not_nil(result, "Expected result but got nil")
end

-- Mock data generators
M.data = {}

function M.data.create_mock_pack(name, files)
    -- Create a mock pack structure
    files = files or {}
    return {
        name = name,
        path = "/mock/dotfiles/" .. name,
        files = files,
        triggers = {},
        powerups = {}
    }
end

function M.data.create_mock_trigger(name, pattern)
    -- Create a mock trigger
    return {
        name = name,
        pattern = pattern or "*",
        fires = function() return true end
    }
end

function M.data.create_mock_powerup(name, actions)
    -- Create a mock power-up
    actions = actions or {}
    return {
        name = name,
        actions = actions,
        execute = function() return actions end
    }
end

-- Test isolation helpers
M.isolation = {}

function M.isolation.with_temp_env(env_vars, test_func)
    -- Run test with temporary environment variables
    -- Note: This is a simplified version for testing framework demo
    -- Full implementation would use proper environment isolation

    local original_env = {}

    -- Store original environment
    for key, _ in pairs(env_vars) do
        original_env[key] = os.getenv(key)
    end

    -- For demonstration purposes, we'll simulate environment variable behavior
    -- In a real implementation, this would use proper environment manipulation
    local mock_env = {}
    for key, value in pairs(env_vars) do
        mock_env[key] = value
    end

    -- Run test with mocked environment
    local success, result = pcall(function()
        -- Temporarily mock os.getenv for this test
        local original_getenv = os.getenv
        os.getenv = function(key)
            if mock_env[key] ~= nil then
                return mock_env[key]
            else
                return original_getenv(key)
            end
        end

        local test_result = test_func()

        -- Restore original os.getenv
        os.getenv = original_getenv

        return test_result
    end)

    if not success then
        error(result)
    end

    return result
end

return M
