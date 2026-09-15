# Host Boarded on Linux with native PostgreSQL

Boarded is the standalone route-setting web app. The implemented target is Ubuntu 26.04, native PostgreSQL 18, persistent local uploads, same-origin Next.js API/Better Auth, and Caddy HTTPS under systemd. Hosted Supabase, Supabase containers, Vercel and Netlify are not required.

**Deployment NOT YET verified.** The coordinator's supplied inventory reports existing Node 22 and PostgreSQL 18 installed/listening on loopback 5432 on `memorized-server`. This operations packet did not access the server or run deployment, migrations, backup, restore, or application acceptance. Package installation alone is not an accepted application deployment.

```text
Browser: Boarded UI and origin-local drafts
  -> canonical HTTPS origin
  -> Caddy (public 80/443)
  -> Next.js UI/API/auth (127.0.0.1:3000, boarded.service)
       -> PostgreSQL 18 (loopback/socket only)
       -> /var/lib/boarded/uploads (authorized application file reads)
       -> authenticated TLS SMTP relay
```

## 1. Access, infrastructure, and preservation prerequisites

1. Confirm actual OS/architecture, PostgreSQL clusters/ports, disk/inodes, other services and backup arrangements. Do not reinstall an existing database, replace other applications' roles, or touch unrelated Docker monitoring services. Leave room for builds, releases, database/uploads and a separate restored copy.
2. Preserve the actual SSH port and permitted administration sources, existing firewall rules, and an independent recovery console. Keep a working SSH session and confirm another login before access changes. General sudo currently requires interactive administrator authentication; package/service wrappers do not grant account, filesystem, database-role or helper-install authority. Obtain the narrow reviewed administrator capability; do not bypass policy.
3. Choose the canonical hostname and verify A/AAAA/NAT/provider/host firewall reachability for Caddy's 80/443. Publish AAAA only with working IPv6. DNS alone does not solve CGNAT or blocked inbound traffic. Never expose 3000, 5432 or Caddy administration.
4. Use existing Node 22.18+ and PostgreSQL 18 where compatible. The scripts/units expect `/usr/bin/node`, `/usr/bin/npm`, Python 3 and PostgreSQL clients. Review Caddy installation only if missing; preserve its existing sites and certificate state. Systemd does not load interactive shell/version-manager configuration.
5. Keep PostgreSQL loopback/socket-only. Review local peer administration and exact SCRAM database/role rules, including separate restore targets. Do not use `trust`, unrestricted internet HBA rules, or open port 5432.
6. Choose a verified SMTP sender and authenticated, certificate-validated TLS relay, with required SPF/DKIM/DMARC and delivery limits. `SMTP_PORT` accepts any integer from 1 through 65535; set `SMTP_SECURE=true` for implicit TLS or `false` for required STARTTLS. Ports 465/587 are conventional examples, not restrictions, and high-port capture relays remain authenticated and TLS-protected. Never disable verification to bypass mail setup. Record deployment, DNS/mail, migration, backup and rollback owners, recovery objectives and approvals; keep secrets in protected custody, not the record.
7. Inventory existing remote data, local drafts and public origins before initializing anything. An empty target does not transfer existing users/content. Take a coherent protected source backup and preserve every referenced file's bytes.

## 2. Follow the implemented operations sequence

Use [native PostgreSQL operations](backend-self-hosting.md) for the exact commands and failure handling. The sequence is:

1. Install the reviewed root-owned helper at `/usr/local/sbin/boarded-ops`; never invoke deploy-user-writable scripts under sudo.
2. `initialize --origin ... --confirm initialize-empty-boarded` only for an empty target. The helper creates the fixed `boarded` database, least-privilege roles/accounts, protected configuration and persistent paths. Do not create those roles manually first: initialization deliberately refuses existing identities/paths. On a partial failure inspect/reconcile; do not delete data to retry.
3. Configure the actual private runtime SMTP/origin values. `/etc/boarded/runtime.env` contains `DATABASE_URL`, `APP_ORIGIN`, `BETTER_AUTH_SECRET`, `UPLOAD_DIR`, and `SMTP_HOST/PORT/SECURE/USER/PASSWORD/FROM`; `/etc/boarded/migration.env` contains only `DATABASE_MIGRATION_URL`. Both are root-owned 0600, never browser configuration.
4. Build committed source as an unprivileged Linux deploy user with `build-release`; install with `install-release` after initialization. Builds use target-architecture dependencies and the commit as `NEXT_PUBLIC_BUILD_ID`, copy standalone static/public assets and keep migrations/dependencies. Installation publishes immutable root-owned `/srv/boarded/releases/<sha>` only after private staging and dependency-path validation. Runtime writes remain confined to uploads/cache.
5. Install reviewed `boarded.service` and optional `boarded-restore@.service`, preserving unrelated units/sites, then reload systemd. A fresh empty installation has no active release to back up. Before upgrades, obtain a coherent native backup and freeze writes.
6. `migrate` explicitly stops the unit and invokes the ledgered `npm run db:migrate` through the separate migration identity. Never migrate during application startup. `activate` changes `/srv/boarded/current`, starts the service and waits for `/api/health`. Failed readiness is not an automatic SQL rollback.
7. Merge/validate the supplied Caddy site, reload only the validated configuration, enable the verified app at boot, and prove external HTTPS and mail. Do not serve the upload directory directly. Local HTTP 200 is readiness evidence only, not acceptance of DNS, certificates, mail or browser behavior.

The Caddy proxy must retain `header_up X-Real-IP {remote_host}` from the template, including for isolated staging. It overwrites attacker-supplied client-IP headers for the backend's auth rate limits. Keep Next.js loopback-only; adding an upstream CDN/tunnel requires an explicit reviewed trusted-proxy policy, not blindly trusting forwarded headers.

## 3. Existing-data conversion is a separate controlled operation

**Never run historical `supabase/migrations/001`–`013` against plain PostgreSQL.** They depend on platform Auth/Storage schemas, API roles, RLS helpers and security-definer contracts. The new `db/migrations` chain and runner are the deployment path; historical SQL remains requirements/history only.

There is no automatic old-platform importer in these operations. If existing data must move:

1. Export through approved source administration: identity/users/metadata, all application tables, migration history, moderator assignments, and an inventory plus **every referenced uploaded byte**. A database dump is not an image backup. Encrypt exports outside the checkout.
2. Use purpose-built, reviewed conversion into an isolated staging database/upload root. Preserve IDs/FKs or a complete recorded identity mapping, nullable historical ownership, timestamps, holds/grades, visibility, comments/ascents/likes, profile/home-area values, share tokens, and wall/route/avatar snapshots. Reconcile counts, ownership, relationships and checksums; map old absolute URLs to the new opaque file URLs. Do not assign orphaned rows to an arbitrary account.
3. Verify credential-hash compatibility through the maintained auth library's supported mechanism; otherwise preserve identity/content and require secure recovery/re-enrollment after ownership verification. Do not invent hash conversion, carry old sessions forward, or allow signup with an existing email to claim imported content.
4. Retain migration-013 `climbing_sessions`, `climb_attempts`, `session_posts`, timeline snapshots, post likes/comments, meetups/attendees/comments and social-media files in conversion or an explicitly approved restorable archive. Their absence from this standalone UI is not permission to delete or expose private timelines.
5. Rehearse full conversion and restore, then freeze **all** source writes/uploads for the final coherent export and reconciliation. Prevent old bundles from continuing to write to the former backend. Never run two independent writable backends for the same accounts.

## 4. Origins, drafts, sessions, and links

Preserve the original origin where possible. Browser storage belongs to the scheme/hostname/port, browser profile and device; sessionStorage also belongs to the tab/session lifetime. Keeping a pathname or changing DNS does not migrate state between origins.

Retain the established `boarded-routes`, `boarded-walls`, `boarded-user`, `boarded-draft`, `boarded-storage-history`, `boarded-board-theme` and `climbset-install-dismissed` semantics. `boarded-user` is only a profile cache, not authentication or moderator authority. Same-origin HttpOnly auth cookies replace former platform sessions; reauthentication is expected. Logout/account switches must clear private remote state without losing local drafts.

An origin change needs an implemented user-controlled draft export/import path or continued old-origin access until users recover drafts; do not promise transfer through DNS. Ordinary cached remote routes are not a full backend export, and local-only walls are not automatically uploaded. Sharing remains `/share/[token]`; preserve records, image bytes and old hostname/path routing. Local-only tokens do not create public server shares. Making files private cannot retract previously downloaded public bytes.

## 5. Backup, isolated recovery, and rollback

The native `backup` helper pauses the application, blocks/drains runtime DB connections, and captures one database/upload set plus checksums, exact runtime grants and release identity. All privileged/import writers must also be frozen. It retains partial sets and never deletes a completed backup on restart failure. Store separately authenticated/encrypted off-server copies with retention/freshness alerts, protected secrets/configuration escrow, and enough disk for recovery. Checksums alone do not authenticate an untrusted SQL dump.

`restore-isolated` requires a new `boarded_restore_*` name and `--runtime-env` pointing to a root-owned 0600 staging configuration. This must specify a distinct private HTTPS origin and authenticated TLS **mail-capture** relay that cannot deliver to real recipients. It never copies production SMTP settings or silently enables insecure mail. It restores only into fresh roles/database/upload paths and automatically links the exact installed backup release; existing destinations are refused. No production service, current symlink or DNS is modified.

Review scoped restore HBA, mail capture and private HTTPS routing before starting the optional `boarded-restore@<name>.service`. It uses a separate OS account and loopback3100, isolated files/cache and fresh auth secret; run one drill at a time. Compare counts, references, checksums and retained data, then repeat core application flows. Never rehearse over production. Partial restore targets are preserved, not automatically overwritten or removed.

Retain pre-cutover database/files/settings/code until the acceptance window closes. Before new writes, rollback may return to the frozen source and original routing after compatibility review. **After new writes**, reverting code/DNS alone loses or splits data: freeze again, preserve the new state, and perform reviewed reverse conversion or restore an explicitly approved recovery point/data-loss window. Never blindly down-migrate, point the old Supabase binary at plain PostgreSQL, delete source backups, or reactivate two writable copies.

## 6. Evidence required before inviting users

These are required observations, **not passed checks**:

- **Auth/mail:** signup confirmation, expired/reused verification links, login/reload/logout, resend and recovery/reset work, including another browser; no confirmation bypass or leaked tokens.
- **Persistence:** profiles/home area/avatar, wall upload and route CRUD/holds/grade/snapshot survive restart and load on another device. Browser cache alone cannot pass.
- **Public/social:** signed-out public sharing loads images/dimensions/holds and appropriate interactions/counts. Private/missing tokens reveal no private route; anonymous views cannot edit other fields.
- **Authorization/privacy:** test A/B/anonymous forged ownership, guessed private IDs, parent/file reassignment, duplicate-ID takeover, moderator escalation, storage enumeration/cleanup, traversal and oversized/malformed files via direct HTTP. Repeat after logout/account switch; optimizer/PWA caches must not leak prior-user data.
- **Local/offline:** signed-out drafts and pending markers survive interrupted operations/reloads; retries neither duplicate nor steal rows, and late responses cannot repopulate another account. Failed remote operations are not displayed as proven remote saves.
- **Moderation/storage:** only authorized moderators can inspect/clean storage; referenced/recent files survive, including references created after preview. Private images cannot bypass authorization.
- **Operations/recovery:** correct release/ledger, external HTTPS/mail, intended port isolation, boot/restart readiness, coherent backup and an exercised isolated restore. Imported identities/ownership/object checksums/share links/retained records match the approved inventory.

Record release SHA, migration version, outcomes, recovery duration/loss window and operator approval without secrets. A green build/test suite is not evidence that these live flows or backups work. Continue OS/PostgreSQL/Node/Caddy/auth patching, monitoring, mail/domain maintenance and staged recovery drills after launch.
