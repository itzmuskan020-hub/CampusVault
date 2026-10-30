# Testing and QA report

## Executed checks

Fill this table only with the results of checks actually run for the submitted version.

| Check | Result | Notes |
| --- | --- | --- |
| `npm.cmd install --no-audit --no-fund` | Passed | 75 packages installed. npm warned the esbuild install script was blocked; the build succeeded using the installed platform package. |
| `npm.cmd test` | Passed | 6 Node tests cover booking validation, unavailable/past/overlong requests, FairShare, overlap waitlisting, staff/eligibility/self-approval checks, lifecycle transitions, and malformed saved state normalization. |
| `npm.cmd run build` | Passed | Latest production bundle completed successfully. An earlier build caught a JSX syntax error, which was fixed. |
| Vite development HTTP smoke check | Passed | Started Vite in-process and fetched `/`, `/src/main.jsx`, and `/src/App.jsx`; all returned HTTP 200 with expected content. |
| Dashboard render smoke check | Passed | React server render included the CampusVault dashboard and seeded DSLR listing. |
| Browser: open demo and submit an eligible DSLR request | Partial | Local app rendered. Student request submission displayed â€œRequest sent for staff review.â€ and the active request count updated. |
| Browser: staff approval | Not verified | Corrected the requester eligibility check, self-approval guard, and staff-only decision check. Browser approval was not re-run in this session. |
| Staff booking and handover view | Implemented; UI not verified | Staff now see campus bookings and receive checkout/return controls. Students only see requester actions. Unit tests cover the underlying lifecycle transitions. |
| Persistence after page refresh | Not verified end-to-end | Added shape validation for saved demo state and guarded storage access. Automated normalization tests pass, but the browser refresh could not be re-run in this session. |
| Supabase RLS policy matrix | Not run | Requires a configured Supabase project and test users. |

## Manual scenarios for the demo UI

1. Student requests the DSLR for a future window, then refreshes and checks that the request persists.
2. Staff switches role and approves the request; student sees the approved status.
3. Request an overlapping time window for that DSLR and verify it enters the waitlist; confirm staff cannot approve a conflicting reservation.
4. Student requests the electronics test bench and 3D printer with fictional eligibility present; staff approval should work. Remove this browser's localStorage `trained`/`verified` user id in devtools to verify missing eligibility blocks the student action and staff approval.
5. Staff adds a resource, edits its listing, marks it unavailable and reactivates it.
6. Record checkout with condition notes, refresh, record return with final condition notes and confirm both stay on booking/activity.
7. Report damage/late return; staff records a human resolution. Confirm no automatic blame/penalty appears.
8. Try invalid or past request times, a duration beyond resource maximum, and a fourth active request.
9. Switch student accounts in a future authenticated implementation and verify another student's booking/incident and staff-only activity are inaccessible.

## Backend authorization matrix to run before production

| Action | Student | Staff | Admin |
| --- | --- | --- | --- |
| Read active catalogue | Yes | Yes | Yes |
| Insert request for self | Yes | Yes, if acting as requester | Yes, if acting as requester |
| Approve request | No | Yes, with eligibility and no overlap | Yes, with eligibility and no overlap |
| Verify training/membership | No | Yes | Yes |
| Manage owned resource | No | Yes | Yes |
| Manage any resource | No | No | Yes |
| Read audit history | No | Yes | Yes |
| Modify/delete audit records | No | No | No client policy |

No `lint` script is configured in `package.json`. The SQL has not been executed against Supabase in this workspace. RLS, edge behavior and concurrent transaction behavior remain unverified. Staff approval and persistence after refresh remain incomplete QA items; no passed status should be inferred from the scenario list.

