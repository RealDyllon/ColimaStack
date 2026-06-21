---
name: starlight-features
description: Use when Codex needs to install, configure, customize, audit, or author documentation using Starlight Theme Next.js (`starlight-theme-next`) in an Astro Starlight site. Trigger for requests about Starlight Theme Next.js setup, Next.js-docs-inspired Starlight styling, Starlight docs components and examples, custom CSS cascade layers, splash pages, heroes, banners, cards, code blocks, file trees, link buttons, steps, tabs, asides, badges, Markdown styling, or reviewing a themed Starlight docs site.
---

# Starlight Features

## Quick Start

Use this skill when working on an Astro Starlight docs site that should use or match `starlight-theme-next`.

1. Inspect the existing Starlight setup: `package.json`, `astro.config.mjs`, `src/content/docs/**`, and any `customCss` files.
2. If installing the theme, use the site's package manager:

```sh
pnpm add starlight-theme-next
```

3. Register the plugin in `astro.config.mjs`:

```js
import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';
import starlightThemeNext from 'starlight-theme-next';

export default defineConfig({
  integrations: [
    starlight({
      plugins: [starlightThemeNext()],
      title: 'My Docs',
    }),
  ],
});
```

4. Build and visually review the site. Check at least the landing page, a normal docs page, a code-heavy page, mobile menu behavior, and search.

## Authoring Guidance

- Prefer native Starlight features and user components over custom HTML where possible.
- Use `template: splash` for landing-style pages, banners, and heroes that should not show sidebars.
- Use Starlight components for structured docs UI: `Aside`, `Badge`, `Card`, `CardGrid`, `LinkCard`, `Code`, `FileTree`, `LinkButton`, `Steps`, `Tabs`, and `TabItem`.
- Keep custom CSS small and scoped. The theme uses CSS cascade layers named `starlight` and `nextjs`; unlayered custom CSS overrides both.
- If using layers, place overrides after the theme layers, e.g. `@layer my-reset, starlight, nextjs, my-overrides;`.
- Do not re-add broad color overrides unless the user explicitly wants to depart from the Next.js-inspired theme.

## Feature Reference

Read [references/features.md](references/features.md) when you need the complete feature inventory, page-by-page examples, review checklist, or companion plugin/resource list from the Starlight Theme Next.js docs.
