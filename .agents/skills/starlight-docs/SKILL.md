---
name: starlight-docs
description: Use when authoring, editing, or reviewing Astro Starlight documentation pages, especially MDX pages that should use Starlight Theme Next-style docs components such as asides, badges, cards, code blocks, file trees, link buttons, steps, tabs, details, and tables.
---

# Starlight Docs

## Workflow

Use this skill when creating or improving `.md` or `.mdx` pages in an Astro Starlight docs site.

1. Inspect the local docs structure before editing: `astro.config.*`, `src/content/docs/**`, and nearby pages.
2. Match the page's existing frontmatter, import style, heading depth, and component conventions.
3. Prefer Starlight's built-in Markdown and components before adding custom HTML or CSS.
4. Use MDX (`.mdx`) when the page needs component imports or JSX components.
5. Build or run the site's existing docs check after edits, then visually review pages with component-heavy layouts.

## Page Structure

Use frontmatter for title, sidebar order, badges, and page options:

```mdx
---
title: Page title
sidebar:
  order: 1
  badge: Demo
---
```

Keep the page scannable: short intro, task-oriented sections, and examples close to the concept they explain.

## Component Patterns

Import only the Starlight components used on the page:

```mdx
import {
  Badge,
  Card,
  CardGrid,
  FileTree,
  LinkButton,
  LinkCard,
  Steps,
  TabItem,
  Tabs,
} from '@astrojs/starlight/components'
```

Use admonition directives for asides:

```mdx
:::note
Context the reader should know.
:::

:::tip
A useful recommendation.
:::

:::caution
Something that can cause mistakes.
:::

:::danger
Something destructive or security-sensitive.
:::
```

Use badges sparingly for status, version, stability, or content type:

```mdx
<Badge text="Experimental" variant="danger" />
<Badge text="New" variant="tip" size="small" />
```

Use cards for related concepts, and link cards when the whole item navigates:

```mdx
<Card title="Configure" icon="star">
  Short explanatory body.
</Card>

<CardGrid>
  <LinkCard title="API reference" href="/reference/api/" />
  <LinkCard title="Examples" href="/examples/" />
</CardGrid>
```

Use details for optional information that should not interrupt the main flow:

```mdx
<details>
<summary>Advanced notes</summary>

Additional Markdown content.

</details>
```

Use expressive code fences when teaching changes:

````mdx
```astro title="src/components/Example.astro" {4} ins="new code" del="old code"
---
const name = 'Starlight'
---

<p>{name}</p>
```
````

For before-and-after changes, prefer a diff block:

```diff
- const theme = 'old'
+ const theme = 'next'
```

Use `FileTree` to explain project structure:

```mdx
<FileTree>

- astro.config.mjs
- src
  - content
    - docs
      - **index.mdx**

</FileTree>
```

Use link buttons only for clear actions:

```mdx
<LinkButton href="/start/" icon="rocket">Start</LinkButton>
<LinkButton href="/api/" variant="secondary" icon="external">API</LinkButton>
<LinkButton href="/notes/" variant="minimal">Notes</LinkButton>
```

Use `Steps` for ordered procedures:

````mdx
<Steps>

1. Install the package.

   ```sh
   pnpm add starlight-theme-next
   ```

2. Update the Astro config.

</Steps>
````

Use tabs for equivalent alternatives, such as package managers or frameworks:

````mdx
<Tabs>
<TabItem label="npm" icon="seti:npm">

```sh
npm install package-name
```

</TabItem>
<TabItem label="pnpm" icon="pnpm">

```sh
pnpm add package-name
```

</TabItem>
</Tabs>
````

Use Markdown tables for compact comparisons. Keep columns narrow enough for mobile docs layouts.

## Review Checklist

- The page uses `.mdx` only when components or JSX are needed.
- Imports are deduplicated and placed near the first component use or in the page's established style.
- Aside severity matches the message: `note`, `tip`, `caution`, or `danger`.
- Cards and tabs group parallel choices, not unrelated content.
- Code blocks have meaningful language tags, filenames, and highlights where useful.
- Steps contain actual sequence; tabs contain mutually exclusive alternatives.
- Links are real local docs routes or intentionally temporary placeholders.
- The page builds without MDX parser errors, especially around nested code fences inside components.

## Source

This skill is based on the Starlight Theme Next.js kitchen-sink example:
https://starlight-theme-next.trueberryless.org/examples/kitchen-sink/
