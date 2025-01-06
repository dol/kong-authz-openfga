# Backlog items

## Features

- [x] Add retry attempts
- [ ] Add caching capability

## Improvements

- [ ] Add live tests to the OpenFGA server addition to the mock server.
- [ ] Add an example that uses Consumer in conjunction with the Basic Authentication plugin.
- [x] Add build, test, and deploy pipeline (GitHub Actions) to the project
- [x] Add GitHub action to perform a smoke test
- [x] Add GitHub action to publish .rock when a version was tagged. Use LUAROCKS_API_KEY secret.

## Cleanup

- [ ] The OpenFGA store id in the sqlite database is fixed. Make it dynamic when loading the data.
- [ ] Test with PostgreSQL as database backend.
