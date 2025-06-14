-- Tests for Matchers module integration

describe("Matchers", function()
    local matchers = require("dodot.matchers")

    describe("create_default_registry", function()
        it("should create a registry with default matchers", function()
            local registry = matchers.create_default_registry()
            assert.is_not_nil(registry)
            assert.is_true(registry:count() > 0)
        end)

        it("should create valid matcher configurations", function()
            local registry = matchers.create_default_registry()
            local configs = registry:get_all_configs()

            assert.is_true(#configs > 0)

            for _, config in ipairs(configs) do
                assert.is_not_nil(config.matcher_name)
                assert.is_not_nil(config.trigger_name)
                assert.is_not_nil(config.power_up_name)
                assert.is_number(config.priority)
                assert.is_table(config.options)
            end
        end)
    end)

    describe("get_matcher_configs", function()
        it("should return default configs when no registry provided", function()
            local configs = matchers.get_matcher_configs()
            assert.is_table(configs)
            assert.is_true(#configs > 0)
        end)

        it("should use provided registry", function()
            local registry = matchers.create_default_registry()
            local configs = matchers.get_matcher_configs(registry)
            assert.is_table(configs)
            assert.is_true(#configs > 0)
        end)

        it("should return configs sorted by priority", function()
            local configs = matchers.get_matcher_configs()

            -- Verify sorting (higher priority first)
            for i = 2, #configs do
                assert.is_true(configs[i - 1].priority >= configs[i].priority,
                    "Config " .. (i - 1) .. " priority should be >= config " .. i .. " priority")
            end
        end)
    end)

    describe("get_simulated_matchers", function()
        it("should return compatibility configs", function()
            local configs, err = matchers.get_simulated_matchers()
            assert.is_nil(err)
            assert.is_table(configs)
        end)

        it("should return configs in expected format", function()
            local configs, err = matchers.get_simulated_matchers()
            assert.is_nil(err)

            if #configs > 0 then
                local config = configs[1]
                assert.is_not_nil(config.matcher_name)
                assert.is_not_nil(config.trigger_name)
                assert.is_not_nil(config.power_up_name)
                assert.is_not_nil(config.priority)
                assert.is_not_nil(config.options)
            end
        end)
    end)

    describe("register_matchers", function()
        it("should register matchers with component registry", function()
            local registry = require("dodot.utils.registry")
            local component_registry = registry.new()

            matchers.register_matchers(component_registry)

            assert.is_true(component_registry.has("basic_matcher"))
        end)
    end)
end)
