# UWDSC Documentation Site

Documentation website for the UW Data Science Club, built with [Nextra](https://nextra.site/) and deployed to Vercel at [docs.uwdatascience.ca](https://docs.uwdatascience.ca).

Access is restricted to signed-in `exec`/`admin` members via the shared
uwdatascience.ca Supabase session — see `middleware.ts`.

## Development

```bash
# Install dependencies
pnpm install

# Copy env vars (fill in real values from the shared secrets store)
cp .env.example .env.local

# Start dev server
pnpm dev
```

The documentation will be available at http://localhost:3000

## Building

```bash
pnpm build
```

## Linting & Type Checking

```bash
pnpm lint
pnpm exec tsc --noEmit
```

## Adding Documentation

### Create a New Page

1. Create a new `.mdx` file in `pages/` directory
2. Add entry to `_meta.js` for navigation

Example:

```mdx
# My New Page

This is my documentation page content.

## Section

More content here.
```

### Navigation Structure

Edit `_meta.js` files in each `pages/` folder to control navigation:

```javascript
export default {
  index: "Introduction",
  "getting-started": "Getting Started",
  guides: "Guides",
};
```

## Deployment

The documentation is deployed to [Vercel](https://vercel.com/), which deploys on every push to `main` and generates preview deployments for PRs.

### Environment Variables (Vercel Project Settings)

- `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` — same shared Supabase project used by `uwdsc-website-v3` and `estimathon-v2`
- `NEXT_PUBLIC_MAIN_SITE_URL` — `https://uwdatascience.ca`
- `NEXT_PUBLIC_AUTH_COOKIE_DOMAIN` — `.uwdatascience.ca`

## Auth

`middleware.ts` gates every route: it validates the shared
`sb-*-auth-token` cookie (set by uwdatascience.ca on login) via Supabase, and
requires `app_metadata.role` to be `exec` or `admin`. Unauthenticated visitors
are redirected to `https://uwdatascience.ca/login?redirect=...`; signed-in
`member`s are redirected to `/unauthorized`.

## Technologies

- **Nextra**: Documentation framework
- **Next.js 15**: React framework
- **TypeScript**: Type safety
- **MDX**: Markdown with JSX support

## Learn More

- [Nextra Documentation](https://nextra.site/)
- [MDX Documentation](https://mdxjs.com/)
