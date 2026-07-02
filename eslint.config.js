import { FlatCompat } from "@eslint/eslintrc";

const compat = new FlatCompat({
  baseDirectory: import.meta.dirname,
});

const eslintConfig = [
  ...compat.extends("next/core-web-vitals", "next/typescript"),
  {
    // Nextra convention files use anonymous default exports by design
    files: ["pages/**/_meta.js", "theme.config.jsx"],
    rules: {
      "import/no-anonymous-default-export": "off",
    },
  },
  {
    ignores: [".next/", "out/", "node_modules/", "next-env.d.ts"],
  },
];

export default eslintConfig;
