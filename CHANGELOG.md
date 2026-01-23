# Changelog

## [1.2.1](https://github.com/shabaraba/pile.nvim/compare/v1.2.0...v1.2.1) (2026-01-23)


### Bug Fixes

* make restored buffers navigable with bnext/bprev ([#49](https://github.com/shabaraba/pile.nvim/issues/49)) ([c903e8f](https://github.com/shabaraba/pile.nvim/commit/c903e8f0afa46a6af808067c354a0e5df453dad1))

## [1.2.0](https://github.com/shabaraba/pile.nvim/compare/v1.1.0...v1.2.0) (2026-01-15)


### Features

* session management and vim-like buffer operations ([#46](https://github.com/shabaraba/pile.nvim/issues/46)) ([1ae6d53](https://github.com/shabaraba/pile.nvim/commit/1ae6d538fb8d5801ee8709e80917c929325062af))


### Bug Fixes

* Separate sessions per project ([#48](https://github.com/shabaraba/pile.nvim/issues/48)) ([97463cb](https://github.com/shabaraba/pile.nvim/commit/97463cb67aabfb4703887511ac879aa8dd822cdb))

## [1.2.0] (2026-01-14)

### Features

* **session**: Add session management with auto-save/restore functionality
* **session**: Implement named sessions for multiple project workflows
* **reorder**: Add buffer reordering with persistent order preservation
* **storage**: Add JSON-based data persistence layer (replacing SQLite)
* **api**: Add new commands for session management and buffer reordering

### Breaking Changes

* Remove history tracking and MRU sort features (replaced with session management)
* Change config structure: `history` and `sort` replaced with `session`

### Architecture

* Refactor codebase into layered architecture (storage, features, ui)
* Remove unused SQLite dependency
* Simplify buffer management logic

### Documentation

* Update README with session management features
* Add comprehensive usage examples for sessions and reordering

## [1.1.0](https://github.com/shabaraba/pile.nvim/compare/v1.0.0...v1.1.0) (2026-01-14)


### Features

* add color indicators for buffers displayed in windows ([#45](https://github.com/shabaraba/pile.nvim/issues/45)) ([edeb30d](https://github.com/shabaraba/pile.nvim/commit/edeb30d663c510f86239449eb9c4082c4fa0079c))
* improve duplicate file path display with minimal information ([#26](https://github.com/shabaraba/pile.nvim/issues/26)) ([6401db1](https://github.com/shabaraba/pile.nvim/commit/6401db15ec4375d5ecb4a66f89c0321d1601d55c))


### Bug Fixes

* add nui.nvim dependency check and update documentation ([#31](https://github.com/shabaraba/pile.nvim/issues/31)) ([dfbb9b1](https://github.com/shabaraba/pile.nvim/commit/dfbb9b173a0fcf5f4bb89a050b285f66b51fafe8))
* apply highlight configuration values correctly ([#33](https://github.com/shabaraba/pile.nvim/issues/33)) ([fe6d06b](https://github.com/shabaraba/pile.nvim/commit/fe6d06b173768e23ce671184be4bb6ff821e40d6))
* improve oil.nvim integration with better buffer filtering ([#29](https://github.com/shabaraba/pile.nvim/issues/29)) ([912c3ef](https://github.com/shabaraba/pile.nvim/commit/912c3ef029f9561d39ece293695437a2656d5c96))
* same file display ([#30](https://github.com/shabaraba/pile.nvim/issues/30)) ([7b50dfe](https://github.com/shabaraba/pile.nvim/commit/7b50dfe0ccf648e0645d7a844c8f32b97ef70040))

## 1.0.0 (2024-10-28)


### Features

* delete buffer function ([11fdf55](https://github.com/shabaraba/pile.nvim/commit/11fdf55389eaa25cf914dcba4f167fe075936a54))
* first commit ([28e3989](https://github.com/shabaraba/pile.nvim/commit/28e3989c974e6852f2714539f2cf9eee3e70babd))
