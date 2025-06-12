# Agent Contribution Guidelines for dodot

Welcome, agent! This document provides the guidelines for contributing to the `dodot` project. Adhering to these rules will ensure that your contributions are effective, consistent, and aligned with the project's vision.

## 1. Core Philosophy

Before making any changes, it is critical to understand the core philosophy of `dodot`.

*   **Simplicity and Statelessness:** The primary goal is to keep the tool simple and stateless. Avoid any solution that requires storing state on disk or introduces complex, "magical" behavior. The user should always be in control.
*   **Functional Approach:** The codebase favors a functional style with pure functions where possible. This is key to ensuring testability and clarity.
*   **Convention over Configuration:** The tool uses sensible defaults and file-naming conventions to drive its logic. Customization is possible but should not be the default path.

## 2. Foundational Documents

Your primary source of truth for the project's design, architecture, and API is located in the `docs/design/` directory. You **must** review and understand these documents before implementing any features.

*   `docs/design/concepts-and-design.txxt`: The "why" of the project. Explains the core ideas and user-facing concepts.
*   `docs/design/execution.txxt`: The "how" of the project. Outlines the implementation roadmap, milestones, and technical architecture. You must follow the phased implementation described here.
*   `docs/design/apiv1.txxt`: The detailed specification for the v1 API, including data structures and the interfaces for Triggers, Power-ups, and Actions.

All documentation uses the `.txxt` format, which is a simple, header-oriented plain text format. Maintain this style in any documentation changes.

## 3. Development Workflow

Follow this general workflow for all tasks:

1.  **Understand the Task:** Thoroughly analyze the user's request.
2.  **Consult the Docs:** Re-read the relevant sections of the design documents to ensure your plan aligns with the established architecture.
3.  **Propose a Plan:** Briefly explain your implementation plan before writing code.
4.  **Implement Changes:** Write clean, readable Lua code that follows the existing style.
5.  **Run Tests:** All changes must be accompanied by tests, and all existing tests must pass.

## 4. Testing

We use `busted` for testing.

To run the entire test suite, execute the following command from the project root:

```bash
busted
```

When adding a new feature, you are expected to add corresponding unit and/or integration tests. When fixing a bug, first write a failing test that reproduces the bug, then implement the fix to make the test pass.

## 5. Code Style and Structure

*   **Project Layout:** Follow the project structure and implementation phases laid out in `docs/design/execution.txxt`.
*   **Lua Style:** Maintain a consistent code style. Follow the general principles of the [Lua Style Guide](https://github.com/olivine-labs/lua-style-guide).
*   **Dependencies:** All external dependencies are managed via `luarocks`. If you need to add a dependency, update the rockspec file accordingly.

## 6. Communication

*   **Be Clear:** Clearly state your intentions before taking action.
*   **Reference Sources:** When making a design decision, reference the part of the design documentation that supports it.
*   **Explain Your Reasoning:** If you deviate from the documentation or have to make an assumption, clearly explain why.

## 7 Don't litter

If you need to create temporary files use the $PROJECT_ROOT/tmp for that, not the roo.


## 8 Env vars

We use .envrc    with direnv, so these are always available. Path names , when needed , should use those, too


By following these guidelines, you will help build `dodot` into a robust, well-designed tool. 