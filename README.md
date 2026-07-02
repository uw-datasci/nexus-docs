# UWDSC Documentation Site

Documentation website for the UW Data Science Club, built with [Nextra](https://nextra.site/) and deployed to GitHub Pages at [docs.uwdatascience.ca](https://docs.uwdatascience.ca).

## Development

```bash
# Install dependencies
pnpm install

# Start dev server
pnpm dev
```

The documentation will be available at http://localhost:3000

## Building

```bash
pnpm build
```

The static site will be generated in the `out/` directory.

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

The documentation is automatically deployed to GitHub Pages when changes are pushed to the `main` branch (see `.github/workflows/deploy.yml`).

### GitHub Pages Setup

1. Go to repository Settings → Pages
2. Source: GitHub Actions
3. The site will be available at [docs.uwdatascience.ca](https://docs.uwdatascience.ca)

## Technologies

- **Nextra**: Documentation framework
- **Next.js 15**: React framework
- **TypeScript**: Type safety
- **MDX**: Markdown with JSX support

## Learn More

- [Nextra Documentation](https://nextra.site/)
- [MDX Documentation](https://mdxjs.com/)
