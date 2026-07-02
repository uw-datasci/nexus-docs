import { NextResponse, type NextRequest } from "next/server";
import { createSupabaseMiddlewareClient } from "./lib/supabase";

// Only exec/admin (not member) may access these docs. This mirrors
// ADMIN_ROLES in uwdsc-website-v3/packages/common/src/constants/roles.ts.
const ADMIN_ROLES = new Set(["admin", "exec"]);

const MAIN_SITE_URL = process.env.NEXT_PUBLIC_MAIN_SITE_URL ?? "https://uwdatascience.ca";

/**
 * Gates every page behind the shared uwdatascience.ca Supabase session.
 * Unauthenticated visitors are bounced to the main site's login (which
 * redirects back here via ?redirect=); authenticated visitors without an
 * exec/admin role are sent to /unauthorized.
 */
export async function middleware(request: NextRequest) {
  const response = NextResponse.next({ request: { headers: request.headers } });
  const supabase = createSupabaseMiddlewareClient(request, response);

  // getUser() revalidates the token against Supabase (not just a cookie
  // read) and is what triggers @supabase/ssr to rotate cookies when needed.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    const returnTo = new URL(
      request.nextUrl.pathname + request.nextUrl.search,
      request.url,
    ).toString();
    const loginUrl = new URL("/login", MAIN_SITE_URL);
    loginUrl.searchParams.set("redirect", returnTo);
    return NextResponse.redirect(loginUrl);
  }

  const role = user.app_metadata?.role as string | undefined;
  if (!role || !ADMIN_ROLES.has(role)) {
    return NextResponse.redirect(new URL("/unauthorized", request.url));
  }

  return response;
}

export const config = {
  matcher: [
    // Match everything except static assets, Next internals, and the
    // unauthorized page itself (which must stay reachable when redirected to).
    "/((?!_next/static|_next/image|favicon.ico|unauthorized).*)",
  ],
};
