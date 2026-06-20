# Starlight Theme Next.js Feature Inventory

Source docs read from `https://starlight-theme-next.trueberryless.org/`:
`/getting-started/`, `/customization/`, `/examples/kitchen-sink/`,
`/examples/asides/`, `/examples/badges/`, `/examples/banner/`,
`/examples/banner-splash/`, `/examples/cards/`, `/examples/code-blocks/`,
`/examples/file-tree/`, `/examples/hero/`, `/examples/link-buttons/`,
`/examples/markdown/`, `/examples/steps/`, `/examples/tabs/`,
`/resources/sites/`, `/resources/plugins/`, and `/resources/hideoo/`.

## Core Theme Setup

- Package: `starlight-theme-next`.
- Install into a Starlight site with `pnpm add starlight-theme-next`.
- Import default export from `starlight-theme-next`.
- Register with Starlight plugins:

```js
plugins: [starlightThemeNext()]
```

- The package includes Geist Sans and Geist Mono font CSS and `starlight-theme-next/styles.css`.
- The plugin appends theme CSS to Starlight `customCss` and adjusts Expressive Code defaults unless `expressiveCode: false`.
- The theme sets Expressive Code themes to `vitesse-dark` and `vitesse-light` by default and adjusts frame border/radius/shadow styling.

## Customization Model

- The theme uses CSS cascade layers: `@layer starlight, nextjs;`.
- Unlayered project CSS has higher priority than layered theme CSS.
- To manage override order explicitly, define layers in project CSS:

```css
@layer my-reset, starlight, nextjs, my-overrides;
```

- Use a later custom layer for targeted project overrides:

```css
@layer my-overrides {
  .hero img {
    border-radius: 8px;
  }
}
```

- Avoid broad resets of `--sl-color-*`, fonts, header, sidebar, and code styling unless intentionally changing the theme identity.

## Built-In Starlight Examples

### Kitchen Sink

- Use the kitchen sink page as a combined visual QA reference for asides, badges, blockquotes, cards, details/disclosures, code blocks, file trees, link buttons, steps, tabs, and tables.
- When reviewing a themed docs site, include at least one page that combines several Markdown and component patterns, because spacing issues often appear only when components are adjacent.

### Banner

- A page banner is configured in page frontmatter:

```yaml
banner:
  content: |
    This is a banner message.
```

- Banner content supports inline HTML. Use banners for page-scoped notices, not for persistent global announcements unless the site has a consistent policy.

### Banner Splash

- Banners can be used on `template: splash` pages.
- Validate splash pages separately because splash pages do not use the same sidebar layout as normal docs pages.

### FileTree

- Import `FileTree` from `@astrojs/starlight/components`.
- Use it to show repository, package, or docs structures.

```astro
import { FileTree } from '@astrojs/starlight/components';

<FileTree>
- src
  - content
    - docs
      - index.md
- astro.config.mjs
</FileTree>
```

- Use concise trees. Prefer showing only relevant folders/files.

### Steps

- Import `Steps` from `@astrojs/starlight/components`.
- Use for sequential instructions.

```astro
import { Steps } from '@astrojs/starlight/components';

<Steps>
1. Install dependencies.
2. Configure `astro.config.mjs`.
3. Run `pnpm build`.
</Steps>
```

- Keep each step actionable and ordered.

### Badges

- Import `Badge` from `@astrojs/starlight/components`.
- Use for small labels such as status, version, category, or feature maturity.

```astro
import { Badge } from '@astrojs/starlight/components';

<Badge text="New" variant="success" />
```

- Common variants include `note`, `tip`, `caution`, `danger`, `success`, and `default`.

### Code Blocks

- Inline code and fenced code blocks inherit the theme and Expressive Code styling.
- Prefer fenced code with language identifiers:

````md
```js
console.log('Hello');
```
````

- Use concise code samples and avoid huge snippets on docs overview pages.
- The example set includes plain Markdown code blocks, the Starlight `<Code>` component, text markers, labels, diff-like highlighting, editor frames with filenames, and terminal frames.

### Cards

- Import `Card` and `CardGrid` from `@astrojs/starlight/components`.
- Use cards for feature groups, next steps, comparison highlights, and navigation summaries.

```astro
import { Card, CardGrid } from '@astrojs/starlight/components';

<CardGrid>
  <Card title="Fast setup">Install and configure the docs theme.</Card>
  <Card title="Search">Use built-in Starlight search.</Card>
</CardGrid>
```

- Do not nest cards inside cards.

### Link Buttons And Links

- Use normal Markdown links for inline content.
- Use `LinkCard` for navigational cards.
- Use `LinkButton` for hero or call-to-action links.

```astro
import { LinkButton, LinkCard } from '@astrojs/starlight/components';

<LinkButton href="/getting-started/">Get Started</LinkButton>
<LinkCard title="Customization" href="/customization/" />
```

- Link buttons support `primary`, `secondary`, and `minimal` variants, with or without Starlight icons.

### Expressive Code

- The theme integrates with Starlight's Expressive Code setup.
- Use filename metadata and highlighted lines when helpful:

````md
```js title="astro.config.mjs" {4}
import starlightThemeNext from 'starlight-theme-next';
```
````

- The theme removes heavy frame shadows and uses Next-like borders/radius.

### Hero

- Configure page heroes in frontmatter.

```yaml
template: splash
hero:
  title: My Docs
  tagline: A concise description.
  actions:
    - text: Get Started
      link: /getting-started/
      variant: primary
```

- Hero images can be provided as local image files or raw HTML. Use real product/screenshots when documenting a product.
- The theme docs demonstrate heroes on splash pages with an image, title, tagline, and primary/secondary/minimal actions.

### Asides

- Use Markdown-style Starlight directives for callouts:

```md
:::note
Useful contextual information.
:::

:::tip
Recommended approach.
:::

:::caution
Risk or caveat.
:::

:::danger
High-risk warning.
:::
```

- Use asides sparingly so warnings retain weight.

### Tabs

- Import `Tabs` and `TabItem` from `@astrojs/starlight/components`.
- Use for package-manager commands, OS-specific instructions, or alternate configurations.

```astro
import { Tabs, TabItem } from '@astrojs/starlight/components';

<Tabs>
  <TabItem label="pnpm">
    `pnpm add starlight-theme-next`
  </TabItem>
  <TabItem label="npm">
    `npm install starlight-theme-next`
  </TabItem>
</Tabs>
```

- Keep tab labels short and mutually exclusive.

### Markdown Content

- The theme styles standard Markdown content: paragraphs, lists, headings, tables, blockquotes, links, inline code, code blocks, and horizontal rules.
- The Markdown example also covers heading levels 2-6, bold/italic/strikethrough, subscript/superscript, nested unordered and ordered lists, tables, and details/disclosures.
- Keep docs pages scannable with clear heading hierarchy.
- Use tables for compact reference data, but verify mobile layout.

## Companion Resources

### Starlight Plugins

The theme docs point to the wider Starlight plugin ecosystem and trueberryless packages. Consider plugins/components/tools when a docs site needs behavior beyond the base theme, such as:

- View mode capabilities.
- Credits in the table-of-contents area.
- Showing the latest released package version.
- Swipeable mobile sidebars.
- Sidebar topic dropdowns.
- Save-file/download components.
- Contributor lists.
- Plugin translation status tooling.

Always check plugin compatibility with the installed Starlight and Astro versions before adding dependencies.

### Showcase

The showcase page is currently an invitation to add the first public site using the theme. Use it as a cue that there may not be many production examples yet; rely on the docs examples and local visual QA.

When a showcase exists, use it as visual reference for:

- Dark, minimal, Next.js-inspired docs aesthetics.
- Dense but readable sidebars.
- Header search and theme controls.
- Product-like landing pages layered on top of docs.

### Content From HiDeoo

The theme docs reference reusable Starlight plugins/components/tools from HiDeoo. Treat these as optional inspiration and verify package/API details before using them in a project.

Referenced plugins include link validation, TypeDoc generation, blog support, OpenAPI page generation, Obsidian publishing, image zoom, docs versioning, heading badges, sidebar topics, videos, keyboard shortcut docs, auto-sidebar helpers, draft handling, changelogs, GitHub alerts as asides, and vintage/rapide themes.

Referenced components/tools include package-manager command displays, showcase components, i18n tooling, head tag generation, override maps, plugin scaffolding, and content-link IntelliSense.

## Review Checklist For A Themed Site

1. Build succeeds with the theme installed and registered.
2. Generated output uses the expected deployment base URL.
3. Landing or splash pages render hero, screenshot/media, CTAs, and lower content without overlap.
4. Regular docs pages show header, sidebar or mobile menu, table of contents, and pagination correctly.
5. Search opens, accepts input, and renders results.
6. Code blocks, inline code, tables, and asides match the theme.
7. Cards, tabs, steps, file trees, and badges are used where they improve scanning.
8. Mobile viewport has no clipped text, hidden controls, or unusable menu/search states.
9. Custom CSS is scoped and does not accidentally override core theme color/font/layout tokens.
10. Browser console has no errors on landing, normal docs page, search, and code-heavy pages.
