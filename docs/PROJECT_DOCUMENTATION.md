# CampusVault — Project documentation

## Use case and problem

Colleges own equipment and spaces that can sit idle while student teams struggle to access them. CampusVault provides a shared catalogue and a reviewable workflow to request, approve, hand over and return those resources.

## Users

- **Student:** discover resources, request a time window, view status, cancel, record a return in the demo flow and report booking issues.
- **Resource staff:** manage listings, review eligibility, approve/reject/waitlist, record checkouts and returns, and resolve incident reports.
- **Administrator:** the database role can read audit records and manage all resource records; demo navigation exposes activity history only to the admin role.

The browser demo role switcher is a shortcut for judging, not identity verification. Demo identities and listings are fictional. No real student qualifications are asserted.

## Solution and features

Responsive resource catalogue with search/category/availability filters; detailed use and safety requirements; requests with time windows; staff decisions with explanations; overlap checks; FIFO-style waitlist labels; three active request/booking FairShare cap; required demo eligibility checks; resource CRUD and availability toggles; checkout and return condition notes; incident reports and human staff resolution; local notifications and ProofTrail activity timeline. There is no AI decision feature. Matching is a transparent filter/search experience and staff make safety decisions.

## Architecture and data flow

React 19 + Vite JavaScript frontend, Lucide icons and custom responsive CSS. In current demo mode, `src/App.jsx` initializes fictional seed records and persists state in `localStorage`. Request and decision operations update browser state and the local timeline. Refresh persistence is local to one browser profile and is not shared with other users. `supabase/migrations/202610300001_initial.sql` specifies the intended PostgreSQL/Auth backend with RLS, state constraints, eligibility checks, an exclusion constraint for approved booking overlaps, audit triggers and role policies. The frontend has not yet connected to Supabase Auth or database operations.

## Security and privacy

The local role switcher is insecure by design and must not be used for real users. There are no secrets in frontend code. Production schema provisions role values in `profiles`, not user-editable metadata, and has staff-gated management/eligibility policies and no client write policy for audit rows. Review the SQL before production: any security-definer functions and RLS policies need a real authenticated multi-role test. Evidence photos and storage buckets are not implemented. Keep real personal data out of this demo.

## Fairness, trust and safety

Booking conflicts are checked before local approval; the SQL exclusion constraint handles concurrent approved overlaps in the intended backend. Waitlist reason shows request-time ordering, but the current demo requires staff to decide each waitlist entry; it does not automatically promote one. A three-active-item cap exists in the demo and intended SQL approval trigger. Eligibility blocks demo approvals when training or membership is missing. Sample student training and membership are fictional seed state. No automated blame or penalties are assigned. Audit activity is append-like in demo UI; browser storage can be edited by its owner, so it is not a tamper-proof production audit record.

## Limitations and next steps

Supabase Auth/data integration, end-user invitations, secure staff verification UI, transactional waitlist promotion, real authorization testing, email/push, photo evidence and private storage, accessibility audit, automated component/e2e tests and production monitoring remain to be completed. Demo records persist only in the browser. The app is not deployed. Add only verified contribution/build-window information before submission.

## AI and third-party disclosure

AI assistance was used to generate the application and supporting text. Runtime dependencies: React, React DOM, Supabase JS client (integration-ready dependency), Lucide React. Build tooling: Vite and its React plugin. Google Fonts are loaded over the network for DM Sans and Manrope; browser fallback sans-serif remains available. No paid AI service is used by the application.
