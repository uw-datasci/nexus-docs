import { createServerClient } from "@supabase/ssr";
import type { CookieOptionsWithName } from "@supabase/ssr";
import type { NextRequest, NextResponse } from "next/server";

// When set (e.g. `.uwdatascience.ca`), Supabase auth cookies are scoped to the
// parent domain so this app shares the session set by the main site at
// uwdatascience.ca. Leave unset for localhost dev — the browser rejects a
// `Domain` attribute on hostnames without a public-suffix dot.
const authCookieDomain = process.env.NEXT_PUBLIC_AUTH_COOKIE_DOMAIN;
const sharedCookieOptions: CookieOptionsWithName | undefined = authCookieDomain
  ? {
      domain: authCookieDomain,
      sameSite: "lax",
      secure: true,
      path: "/",
    }
  : undefined;

/**
 * Supabase client for Next.js middleware. Reads the shared session cookie set
 * by the main club site (Domain=.uwdatascience.ca) from the incoming request,
 * and writes refreshed cookies onto both the rewritten request and the
 * outgoing response — keeping them scoped to the same shared domain so the
 * session stays valid across all uwdatascience.ca subdomains.
 *
 * We never sign users in here - the main site at uwdatascience.ca owns the
 * login flow.
 */
export function createSupabaseMiddlewareClient(request: NextRequest, response: NextResponse) {
  return createServerClient(process.env.SUPABASE_URL!, process.env.SUPABASE_PUBLISHABLE_KEY!, {
    cookieOptions: sharedCookieOptions,
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        for (const { name, value, options } of cookiesToSet) {
          request.cookies.set({ name, value, ...options });
          response.cookies.set({ name, value, ...options });
        }
      },
    },
  });
}
