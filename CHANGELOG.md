# Changelog

## [2.2.0](https://github.com/shabaraba/pile.nvim/compare/v2.1.0...v2.2.0) (2026-10-26)


### Features

* add tab separators and line-style window indicator ([#87](https://github.com/shabaraba/pile.nvim/issues/87)) ([331b9e5](https://github.com/shabaraba/pile.nvim/commit/331b9e54f46ad2dd2e3f8de3a4db8da49a668929))
* add tabline option to show tab names ([#86](https://github.com/shabaraba/pile.nvim/issues/86)) ([76caf60](https://github.com/shabaraba/pile.nvim/commit/76caf60a382cb21658ec89ac124a9ea3b08534f5))
* edit aliases and tab names directly in the sidebar ([#84](https://github.com/shabaraba/pile.nvim/issues/84)) ([38b385f](https://github.com/shabaraba/pile.nvim/commit/38b385f5e9cd236e47827f310786009b7c392934))
* expose tab_label() for showing tab names in a tabline ([#85](https://github.com/shabaraba/pile.nvim/issues/85)) ([409392e](https://github.com/shabaraba/pile.nvim/commit/409392e9586905f690b0088946f85f1a1baad690))
* keep display names across buffer renames and add :PilePruneAliases ([#73](https://github.com/shabaraba/pile.nvim/issues/73)) ([ca683ab](https://github.com/shabaraba/pile.nvim/commit/ca683ab7e3b4caf844e7ab0b4529fe9cd7e52090))
* move and share buffers between tabs ([#82](https://github.com/shabaraba/pile.nvim/issues/82)) ([688e8c0](https://github.com/shabaraba/pile.nvim/commit/688e8c0e7ecd415919cd96562c3eaf489c1d0ed3))
* name and reorder tabs, persist tab groups in sessions ([#83](https://github.com/shabaraba/pile.nvim/issues/83)) ([88f6c4f](https://github.com/shabaraba/pile.nvim/commit/88f6c4f7c5156c454013e35600b9adb66cf4aaad))
* switch, create and close tabs from sidebar headers ([#81](https://github.com/shabaraba/pile.nvim/issues/81)) ([cef0a9a](https://github.com/shabaraba/pile.nvim/commit/cef0a9a4fcc4a1ff7d2d3e3d47314ff7eb973c1c))
* track tab membership and group the sidebar by tab ([#80](https://github.com/shabaraba/pile.nvim/issues/80)) ([8bc5006](https://github.com/shabaraba/pile.nvim/commit/8bc50065110156d21c3b518bb92a8c0b98fd22ae))

## [2.1.0](https://github.com/shabaraba/pile.nvim/compare/v2.0.0...v2.1.0) (2026-10-16)


### Features

* add floating preview to sidebar ([#67](https://github.com/shabaraba/pile.nvim/issues/67)) ([ec7ab13](https://github.com/shabaraba/pile.nvim/commit/ec7ab13a626dc27f7811be820d71a0426af00a52))
* add PileSort command to sort sidebar buffers ([#66](https://github.com/shabaraba/pile.nvim/issues/66)) ([da1f1f4](https://github.com/shabaraba/pile.nvim/commit/da1f1f44b38de8943e2526361c5bd6a91f795ccf))
* rename files and edit display names from the sidebar ([#68](https://github.com/shabaraba/pile.nvim/issues/68)) ([a84c0b5](https://github.com/shabaraba/pile.nvim/commit/a84c0b59980fed11c03570203b28e9de12ff198a))
* show file icons in sidebar ([#64](https://github.com/shabaraba/pile.nvim/issues/64)) ([5cd3399](https://github.com/shabaraba/pile.nvim/commit/5cd33994c947c888ce86bdc4becc4e8a829d4151))
* show unsaved and git status marks in sidebar ([#65](https://github.com/shabaraba/pile.nvim/issues/65)) ([cb89f59](https://github.com/shabaraba/pile.nvim/commit/cb89f5973a81b2447e94f5da36adcb58eb5ff77c))


### Bug Fixes

* keep split sizes when toggling the sidebar ([#71](https://github.com/shabaraba/pile.nvim/issues/71)) ([1699c3d](https://github.com/shabaraba/pile.nvim/commit/1699c3d1bfdfacea732ad57bdf9cd9357d8c92df))
* keep visual selection after moving buffers in sidebar ([#63](https://github.com/shabaraba/pile.nvim/issues/63)) ([b06cfc4](https://github.com/shabaraba/pile.nvim/commit/b06cfc4138f15c9888891077bf8fe53cd5d7c158))

## [2.0.0](https://github.com/shabaraba/pile.nvim/compare/v1.3.1...v2.0.0) (2026-10-15)


### ⚠ BREAKING CHANGES

* s1n7ax/nvim-window-picker is now a required dependency and nui.nvim is no longer required.

### Features

* add exclude/include options and show only listed buffers in sidebar ([#61](https://github.com/shabaraba/pile.nvim/issues/61)) ([f87e3b7](https://github.com/shabaraba/pile.nvim/commit/f87e3b7e4226ca711d00a6abaf5fbf6a4088ebb4))
* use nvim-window-picker to choose the target window ([#57](https://github.com/shabaraba/pile.nvim/issues/57)) ([a99c5c0](https://github.com/shabaraba/pile.nvim/commit/a99c5c005a53d383894e11e55cd0d376a44e0bba))


### Bug Fixes

* preserve existing winhighlight entries when coloring CursorLineNr ([#60](https://github.com/shabaraba/pile.nvim/issues/60)) ([1312e71](https://github.com/shabaraba/pile.nvim/commit/1312e71e7c70c14e5d5e21d297516932ef1d1024))

## [1.3.1](https://github.com/shabaraba/pile.nvim/compare/v1.3.0...v1.3.1) (2026-08-26)


### Bug Fixes

* use GITHUB_TOKEN for release-please and drop dead tag job ([#55](https://github.com/shabaraba/pile.nvim/issues/55)) ([c2a932c](https://github.com/shabaraba/pile.nvim/commit/c2a932cec8ce44d47bee44a4733a9b9450dbad7c))


### Performance Improvements

* avoid eager buffer loading and redundant work on session restore ([#54](https://github.com/shabaraba/pile.nvim/issues/54)) ([757189d](https://github.com/shabaraba/pile.nvim/commit/757189d611f8ccab390ba81aa6282f53d27d8d38))

## [1.3.0](https://github.com/shabaraba/pile.nvim/compare/v1.2.1...v1.3.0) (2026-01-27)


### Features

* Add window layout preservation to session management ([#51](https://github.com/shabaraba/pile.nvim/issues/51)) ([91de4da](https://github.com/shabaraba/pile.nvim/commit/91de4dab091f1fd839f69101ea378aff857a419b))

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
