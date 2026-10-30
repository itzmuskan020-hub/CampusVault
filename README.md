# CampusVault

CampusVault is a responsive campus resource sharing demo for the â€œUnlock Underused Equipment and Spacesâ€ challenge. The included app is explicitly a **browser-local fictional demo**, not a connected production database. Browser localStorage keeps changes after refresh in that browser. Demo role switching is intentionally a judge convenience and is not authentication or a security boundary.

## Run on Windows

1. Install Node.js LTS from [nodejs.org](https://nodejs.org/).
2. Open PowerShell in this folder.
3. Run `npm install`.
4. Run `npm run dev` and open the local URL Vite prints (usually `http://localhost:5173`).
5. Run the rule tests with `npm test`. To make a production bundle, run `npm run build`; to preview it, run `npm run preview`.

No credentials are needed for the demo. Use the profile menu to switch among fictional student, resource staff and admin roles. The app stores demo records in the current browser only; reset demo data by clearing site storage for the local Vite URL.

## Production Supabase setup

1. Create a Supabase project. Never place a service-role key in the browser.
2. In Supabase SQL Editor, run `supabase/migrations/202610300001_initial.sql`.
3. In Authentication, create each judge account yourself and set its password privately. Disable public signups unless your institution needs them. Create corresponding `profiles` rows with the authenticated user UUID using the SQL Editor. Give only trusted resource owners the `staff` role; use `admin` sparingly. Do not commit credentials.
4. Copy `.env.example` to `.env.local` and set the Supabase project URL and **anon/publishable** key. These are browser configuration values; RLS must protect every table. No service role key belongs here.
5. The current UI remains a local demo even if those environment values are present: Supabase schema and policy groundwork is provided, but the application has not yet been switched to Supabase-backed reads/writes or Supabase Auth. Do not present demo data as persisted server data.
6. Before a real deployment, implement and verify Supabase Auth, bind all UI operations to the schema, add production seed/import procedures, review every RLS policy and execute the matrix in `docs/TESTING.md` against a non-production project.

## Deploy

Build with `npm run build`. Deploy the `dist/` directory to Vercel, Netlify or another static host. Configure `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` only when completing the backend integration. A Vercel `vercel.json` is included for SPA route fallback. The current demo uses no routes beyond the root page.

## Implemented functionality and verification

The UI and local-demo code include catalogue search and filters; fictional resource details; booking requests; staff approval, rejection and waitlisting; overlap detection and a three-active-request FairShare limit; demo eligibility checks; resource create/edit/deactivate; checkout/return condition notes; incident reporting and staff resolution; in-app notices; activity trail; and demo role views. The SQL migration separately defines the intended backend policies and constraints.

Six automated business-rule tests, a React dashboard render smoke check, and the production build pass. A browser session submitted a student request, but staff approval, refresh persistence, checkout/return, incidents, and Supabase authorization policies have not been verified end to end. Review `docs/TESTING.md` for exact results and open scenarios. There is no configured lint script.

## Disclosure

This application and its documentation were generated with AI assistance in response to a user-provided brief. Dependencies are listed in `package.json`; iconography uses Lucide React, and Vite/React are the application framework/tooling. No team member, user research, institutional relationship, real deployment or production security review is claimed. Record the actual hackathon build-window dates and contributions truthfully before submission; see `docs/TEAM_CONTRIBUTIONS.md`.

