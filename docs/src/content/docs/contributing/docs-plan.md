---
title: Documentation Plan
description: Internal maintainer checklist for keeping ColimaStack docs source-verified.
---

This is maintainer documentation. Public user pages should stay task-first and avoid launch blockers or release-engineering caveats.

## Rules

- Verify claims against source before adding them.
- Use exact UI labels from the Swift source.
- Use exact command shapes from services and tests.
- Keep Quick Start short.
- Put release engineering and screenshot TODOs in contributor docs only.
- Do not document future features as current behavior.
- Keep comparison pages date-stamped and conservative.

## Required source areas for future audits

- `ColimaStack/AppState.swift`
- `ColimaStack/Services/ColimaCLI.swift`
- `ColimaStack/Services/DockerResourceService.swift`
- `ColimaStack/Services/KubernetesResourceService.swift`
- `ColimaStack/Services/BackendAggregationService.swift`
- `ColimaStack/Services/CommandRunService.swift`
- `ColimaStack/Services/ToolLocator.swift`
- `ColimaStack/Services/ResourceParsing.swift`
- `ColimaStack/Views/MainWindowView.swift`
- `ColimaStack/Views/MenuBarView.swift`
- `ColimaStack/Views/WorkspaceScreens.swift`
- `.github/workflows/app-release.yml`
- `ColimaStack.xcodeproj/project.pbxproj`

## Public page checklist

Every major feature page should cover:

- what the view shows
- how data appears
- available actions
- empty states
- source commands or a Command API link
- common fixes
