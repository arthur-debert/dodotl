# Dodot Testing Framework

This document describes the comprehensive testing framework for the dodot project.

## Overview

The testing framework is built around `busted` and provides three distinct testing layers:

- **Unit Tests**: Fast, isolated tests for individual modules and functions
- **Integration Tests**: Tests for module interactions and data flow
- **End-to-End Tests**: Full workflow tests including CLI and file system operations

## Test Structure

```
spec/
├── e2e/                     # End-to-end tests
├── fixtures/                # Test data and sample files
│   ├── config/             # Configuration fixtures
│   └── sample_dotfiles/    # Sample dotfile structures
├── helpers/                 # Test utilities and helpers
├── integration/             # Integration tests
└── unit/                   # Unit tests
```

## Running Tests

### All Tests
```bash
busted
```

### Test Categories
```bash
# Unit tests only (with coverage)
busted --config-file=.busted unit

# Integration tests only
busted --config-file=.busted integration

# End-to-end tests only
busted --config-file=.busted e2e
```

### Individual Test Files
```bash
busted spec/unit/dependencies_spec.lua
busted spec/integration/core_pipeline_integration_spec.lua
```

## Test Configurations

The `.busted` file provides multiple test profiles:

- **default**: All tests, no coverage
- **unit**: Unit tests only, with coverage enabled
- **integration**: Integration tests only
- **e2e**: End-to-end tests only

## Test Utilities

The testing framework provides comprehensive utilities in `spec/helpers/test_utils.lua`:

### Filesystem Helpers
```lua
local test_utils = require("spec.helpers.test_utils")

-- Create temporary directory
local temp_dir = test_utils.fs.create_temp_dir()

-- Create test files
test_utils.fs.create_test_files(temp_dir, {
    ["file.txt"] = "content",
    ["dir/file2.txt"] = "content2"
})

-- Cleanup
test_utils.fs.cleanup_temp_dir(temp_dir)
```

### Error Testing Helpers
```lua
-- Test error codes
test_utils.errors.assert_error_code("MISSING_DOTFILES_ROOT", result, err)

-- Test successful operations
test_utils.errors.assert_success(result, err)
```

### Mock Data Generators
```lua
-- Create mock objects
local pack = test_utils.data.create_mock_pack("vim", {"*.vim"})
local trigger = test_utils.data.create_mock_trigger("file_name", "*.txt")
local powerup = test_utils.data.create_mock_powerup("symlink", {})
```

### Environment Isolation
```lua
-- Test with temporary environment variables
test_utils.isolation.with_temp_env({
    DODOT_ROOT = "/tmp/test"
}, function()
    -- Test code that uses environment variables
end)
```

## Test Fixtures

Test fixtures provide realistic data for testing:

### Sample Dotfiles
- `spec/fixtures/sample_dotfiles/vim/.vimrc` - Sample vim configuration
- `spec/fixtures/sample_dotfiles/zsh/.zshrc` - Sample zsh configuration

### Configuration Files
- `spec/fixtures/config/test_config.toml` - Sample dodot configuration

## Testing Patterns

### Unit Testing Pattern
```lua
describe("module.function", function()
    local module
    
    before_each(function()
        module = require("module")
    end)
    
    it("should do something", function()
        local result, err = module.function(input)
        
        test_utils.errors.assert_success(result, err)
        assert.equals(expected, result)
    end)
end)
```

### Integration Testing Pattern
```lua
describe("Module Integration", function()
    local temp_dir
    
    before_each(function()
        temp_dir = test_utils.fs.create_temp_dir()
    end)
    
    after_each(function()
        test_utils.fs.cleanup_temp_dir(temp_dir)
    end)
    
    it("should integrate modules correctly", function()
        -- Test module interactions
    end)
end)
```

### End-to-End Testing Pattern
```lua
describe("Feature End-to-End", function()
    it("should work end-to-end", function()
        test_utils.isolation.with_temp_env({
            DODOT_ROOT = temp_dir
        }, function()
            -- Test complete workflows
        end)
    end)
end)
```

## Error Testing Strategy

All error conditions should be tested using structured error codes:

```lua
it("should return error for invalid input", function()
    local result, err = module.function(nil)
    
    test_utils.errors.assert_error_code("INVALID_INPUT", result, err)
end)
```

## Coverage

Coverage is enabled for unit tests. Generate coverage reports:

```bash
busted --config-file=.busted unit
luacov
```

## Best Practices

1. **Isolation**: Each test should be independent and not affect others
2. **Cleanup**: Always clean up temporary files and directories
3. **Mocking**: Use mock data for external dependencies
4. **Error Testing**: Test both success and error paths
5. **Descriptive Names**: Use clear, descriptive test names
6. **Fast Tests**: Unit tests should run quickly
7. **Real Data**: Use realistic test fixtures

## Test Development Guidelines

### Adding New Tests

1. **Unit Tests**: Add to `spec/unit/` following module structure
2. **Integration Tests**: Add to `spec/integration/` for module interactions
3. **E2E Tests**: Add to `spec/e2e/` for complete workflows

### Test Naming

- Use descriptive `describe` blocks
- Use "should" statements for `it` blocks
- Group related tests with nested `describe` blocks

### Test Data

- Use fixtures for realistic data
- Use test utilities for temporary data
- Clean up all test data after tests

## Current Test Status

As of Phase 1.3:

- ✅ Testing framework established
- ✅ Test utilities implemented
- ✅ Sample tests for all layers created
- ✅ Test fixtures available
- ✅ Multiple test configurations
- ✅ Test documentation complete

**Test Results**: 10+ tests passing across all layers 