// @ts-check
import starlight from '@astrojs/starlight';
import { defineConfig } from 'astro/config';

const [githubOwner, githubRepo] = process.env.GITHUB_REPOSITORY?.split('/') ?? [];
const isGitHubPagesBuild = process.env.GITHUB_PAGES === 'true';
const isUserOrOrgPagesRepo = githubOwner && githubRepo === `${githubOwner}.github.io`;
const githubPagesBase = isGitHubPagesBuild && githubRepo && !isUserOrOrgPagesRepo ? `/${githubRepo}` : '/';

export default defineConfig({
  site: githubOwner ? `https://${githubOwner}.github.io` : undefined,
  base: githubPagesBase,
  integrations: [
    starlight({
      title: 'ColimaStack Docs',
      description: 'Documentation for ColimaStack, a native macOS control center for Colima, Docker, and Kubernetes workflows.',
      customCss: ['./src/styles/custom.css'],
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/'
        }
      ],
      sidebar: [
        {
          label: 'Get Started',
          items: [
            'index',
            'features',
            'quick-start',
            'install',
            'faq',
            'roadmap'
          ]
        },
        {
          label: 'Learn More',
          items: [
            'architecture',
            'settings',
            'efficiency',
            'troubleshooting'
          ]
        },
        {
          label: 'Features',
          items: [
            'features/diagnostics',
            'features/activity',
            'features/search',
            'features/menu-bar'
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
          label: 'Profiles',
          items: [
            'profiles/overview',
            'profiles/configuration',
            'profiles/ssh',
            'profiles/files'
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
            'reference/release-readiness',
            'reference/docs-plan'
          ]
        }
      ]
    })
  ]
});
