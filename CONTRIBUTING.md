# Contributing

Thanks for helping improve ColimaStack. This guide covers local development, tests, documentation, and release workflow details for contributors.

## Local Development

Requirements:

- macOS 14 or later
- Xcode for local development
- Homebrew-managed CLI dependencies for the default Docker workflow:

```sh
brew install colima docker
```

Install `kubectl` only for Kubernetes workflows. Homebrew normally installs Lima with Colima; if diagnostics report that `limactl` is missing, install Lima explicitly.

From the repository root, open the Xcode project:

```sh
open ColimaStack.xcodeproj
```

Run the `ColimaStack` scheme from Xcode, or build it from Terminal:

```sh
xcodebuild -project ColimaStack.xcodeproj -scheme ColimaStack build
```

To verify Colima separately before launching the app:

```sh
colima start
docker context use colima
docker ps
```

For named profiles, Docker contexts usually follow the `colima-<profile>` pattern.

## Project Structure

```txt
ColimaStack/          SwiftUI macOS app
ColimaStackTests/     Unit tests
ColimaStackUITests/   UI tests
docs/                 Astro Starlight documentation
design/               Product and screen notes
```

## Testing

Run tests with:

```sh
xcodebuild test -project ColimaStack.xcodeproj -scheme ColimaStack
```

## Documentation

The documentation site is built with Astro Starlight and lives in [`docs`](docs).

Start the local docs server with:

```sh
cd docs
pnpm install
pnpm dev
```

Build the docs with:

```sh
cd docs
pnpm build
```

## Releases

App CI runs from [`.github/workflows/app-release.yml`](.github/workflows/app-release.yml). Pull requests and pushes to `main` run unit tests, build the macOS app, then upload the packaged `.app` zip as a workflow artifact.

Release Please runs from [`.github/workflows/release-please.yml`](.github/workflows/release-please.yml). Merges to `main` update a release PR from Conventional Commits, bump [`VERSION`](VERSION), and maintain `CHANGELOG.md`; merging that release PR creates a `vX.Y.Z` GitHub Release. The generated tag then triggers the app release workflow, which uploads the app zip and SHA-256 checksum.

Use `fix:` for patch releases, `feat:` for minor releases, and `feat!:` or `BREAKING CHANGE:` for major releases. The Release Please workflow requires a `RELEASE_PLEASE_TOKEN` repository secret backed by a PAT or GitHub App token with permission to write contents, issues, and pull requests; the default `GITHUB_TOKEN` cannot trigger the follow-up tag workflow.

You can also run the app workflow manually from GitHub Actions and provide a `x.y.z` version number. For tag releases, CI derives `MARKETING_VERSION` from the `vX.Y.Z` tag; CI uses the GitHub Actions run number as `CURRENT_PROJECT_VERSION` unless a manual numeric build number is supplied. The GitHub-built artifact is unsigned until Developer ID signing secrets are added to the workflow.
