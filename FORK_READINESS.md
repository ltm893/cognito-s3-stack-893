# Fork readiness

Checked 2026-10-10. `web-app-893` and `dliv-web` on `dev` match `origin/dev`. The generic frontend is in `web-app-893`. `dliv-web` only adds the sale page on top of that.

A second domain is not ready to fork yet. The deploy shape is. Each backend takes an `id`, writes an outputs file, and the website reads Amplify env vars. What is not ready is the branding, two docs that contradict the build, and the calendar table name.

## Already in place

- Fork `cognito-s3-stack-893`, then `dropbox-893` and `calendar-893`. Point a new Amplify app at a fork of `web-app-893`.
- `pdf-search-893` and `video-convert-893` stay off when their API URL env vars are blank.
- Do not fork `dliv-web` for the new domain. Its build clones `https://github.com/ltm893/web-app-893.git` and adds the sale page and the Ancestry label.
- Nav title, tagline, footer, extra links, and the PDF search label already come from `site` in `dliv_outputs.json`.
- API Gateway CORS allows any origin, so a new Amplify hostname does not need a code change.
- The Dropbox deploy creates an app client with `ALLOW_USER_PASSWORD_AUTH`. The website must use that client id.

## Do these before the trial

### 1. Make the visible name follow config

`SITE_TITLE`, `SITE_TAGLINE`, and `SITE_FOOTER` change the sidebar. These stay DLIV even when those are set:

| Place | Current text |
|-------|----------------|
| `frontend/index.html` `<title>` | `DLIV` |
| `frontend/calendar.html` `<title>` | `DLIV — Calendar` |
| `frontend/mediaPlay.js` `APP_TAB_TITLE` | `DLIV` (playback writes this back over the tab title) |
| Dropbox shared tab | `All DLIV Users` |
| Sidebar defaults, if the env vars are left blank | `DLIV`, `Family & Friends`, `© 2020 DLIV` |

A fork that only sets Amplify env vars will still present itself as DLIV. Drive the tab title and the shared-tab label from `site` the same way the sidebar already works. Until that lands, the trial is a DLIV-branded site on another hostname.

### 2. Make the fork docs match the build

A forker who follows `CONTEXT.md` will deploy a site that cannot sign in.

- `amplify.yml` reads `APP_REGION` and writes it to `aws_region`. `auth.js` calls `https://cognito-idp.${aws_region}.amazonaws.com/`. `CONTEXT.md` tells forkers to set `AWS_REGION`. That leaves `aws_region` empty and sign-in fails.
- `README.md` still says tokens live in `sessionStorage` and clear when the tab closes. The code uses `localStorage`.
- `CONTEXT.md` “Next steps” still lists work that is done, including “do this next” on `amplify.yml`, and it tells forkers to deploy `pdf-search-893` before the site. PDF search is optional.
- The family table in `README.md` omits `video-convert-893`. The env var table includes it.

Update those three places so the trial uses `APP_REGION`, treats PDF search and video convert as optional, and describes the token storage the code actually uses.

### 3. Stop the calendar example from reusing DLIV’s table

`calendar-893/backend/bin/config.example.ts` sets `calendarTable` to `CalendarEvents`. That is the live DLIV table. A second stack in this account with that name reads and writes DLIV events.

Before the trial, change the example to a name that includes `id`, such as `your-id-here-calendar`, and say to set `createTable: true` on the first deploy of a new name, then `false` after. The trial config must not use `CalendarEvents`.

### 4. Write down which client id the website uses

`cognito-s3-stack-893` creates a client for mobile apps. It does not enable `USER_PASSWORD_AUTH`. `dropbox-893/backend/scripts/deploy.sh` creates the client the website needs and writes `user_pool_client_id` into `dropbox_outputs.json`.

The fork notes should say: `USER_POOL_ID` comes from the base outputs, `USER_POOL_CLIENT_ID` comes from `dropbox_outputs.json`, and `DROPBOX_API_URL` comes from that same file. Using the base-stack client makes sign-in fail.

## After that, the trial itself

Use a new `id` that is not `dliv`, `apps-893`, or `met893`. One AWS account is fine if every name is prefixed with that id.

1. Fork and deploy `cognito-s3-stack-893` with that `id` and a `fromEmail` you can verify in SES. Invite email will not send until SES accepts that address.
2. Fork and deploy `dropbox-893` against that pool and the new `{id}-public` and `{id}-private` buckets.
3. Fork and deploy `calendar-893` with a new table name and `createTable: true`.
4. Fork `web-app-893`. Create a new Amplify app on that fork. Set `APP_REGION`, `USER_POOL_ID`, `USER_POOL_CLIENT_ID` (the Dropbox client), `DROPBOX_API_URL`, `CALENDAR_API_URL`, and the `SITE_*` values for the new name.
5. Leave `PDF_SEARCH_API_URL` and `VIDEO_CONVERT_API_URL` empty for the first build.
6. Open the Amplify URL. Sign in, open a slideshow, open Dropbox, open Calendar.
7. Add the custom domain in Amplify only after that URL works.

Skip `dliv-web`, `music-player-893`, and `mileage-expense-tracker-893` for this trial.
