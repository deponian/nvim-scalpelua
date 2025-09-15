# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-09-16

### Added

- Add `<Plug>(Scalpelua)` normal mode mapping

### Fixed

- Replace deprecated `nvim_buf_add_highlight` function

### Changed

- Drop dehighlighting feature

## [0.2.2] - 2023-06-17

### Fixed

- Overlapping of highlighting zones

## [0.2.1] - 2023-05-28

### Changed

- Ability to enable/disable saving pattern to `/` register with `save_search_pattern` configuration option

## [0.2.0] - 2023-05-28

### Added

- Dehighlighting feature

## [0.1.3] - 2023-05-28

### Fixed

- Fix "a" (replace all) command and change highlighting method

## [0.1.2] - 2023-05-26

### Fixed

- Fix error for situations when replacement contains pattern

## [0.1.1] - 2023-05-16

### Fixed

- Optimize the code. It's much faster for big files now

## [0.1.0] - 2023-05-14

### Added

- Initial release
