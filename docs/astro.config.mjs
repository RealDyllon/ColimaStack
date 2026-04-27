// @ts-check
import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';
import starlightThemeNext from 'starlight-theme-next';

const site = process.env.DOCS_SITE ?? 'https://colimastack.dyllon.io';
const base = process.env.DOCS_BASE ?? '/';

export default defineConfig({
  site,
  base,
  integrations: [
    starlight({
      title: 'ColimaStack Docs',
      description: 'Documentation for ColimaStack, a native macOS control center for Colima, Docker, and Kubernetes workflows.',
      plugins: [starlightThemeNext()],
      customCss: ['./src/styles/custom.css'],
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/realdyllon/ColimaStack'
        }
      ],
      sidebar: [
        {
          label: 'Get Started',
          items: [
            'index',
            'install',
            'quick-start',
            'compatibility',
            'faq'
          ]
        },
        {
          label: 'Profiles',
          items: [
            'profiles/overview',
            'profiles/configuration',
            'profiles/ssh',
            'profiles/files'
          ]
        },
        {
          label: 'Runtime',
          items: [
            'runtime/overview',
            'runtime/monitor'
          ]
        },
        {
          label: 'Docker',
          items: [
            'docker/containers',
            'docker/images',
            'docker/volumes',
            'docker/networks'
          ]
        },
        {
          label: 'Kubernetes',
          items: [
            'kubernetes/overview',
            'kubernetes/workloads',
            'kubernetes/services'
          ]
        },
        {
          label: 'Features',
          items: [
            'features/menu-bar',
            'features/search',
            'features/diagnostics',
            'features/activity'
          ]
        },
        {
          label: 'Security',
          items: [
            'security-privacy'
          ]
        },
        {
          label: 'Compare',
          items: [
            'compare/orbstack',
            'compare/docker-desktop',
            'compare/colima-cli'
          ]
        },
        {
          label: 'Reference',
          items: [
            'reference/command-api',
            'troubleshooting',
            'architecture',
            'settings'
          ]
        },
        {
          label: 'Contributor',
          items: [
            'contributing/release-readiness',
            'contributing/docs-plan',
            'contributing/screenshot-checklist',
            'roadmap'
          ]
        }
      ]
    })
  ]
});
