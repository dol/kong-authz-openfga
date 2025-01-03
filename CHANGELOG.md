# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Initial implementation of plugin
- Added GitHub action build for linting and unit testing
- Added function to handle unexpected errors and exit the plugin
- Added function to make FGA requests with retry logic
- Added unit tests to mock HTTP requests and return different responses based on call count
- Added support for EMMY Debugger with configurable host and port

### Changed

- Extracted `kong.response.exit(500, "An unexpected error occurred")` to its own function
- Extracted the code inside the `repeat ... until` loop into its own function
- Modified `make_fga_request` to return a boolean indicating allow/deny

### Fixed

### Removed

### Deprecated

### Security
