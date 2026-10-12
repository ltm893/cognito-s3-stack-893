# Fork readiness

Checked 2026-10-10. `web-app-893` and `dliv-web` on `dev` match `origin/dev`. The generic frontend is in `web-app-893`. `dliv-web` only adds the sale page on top of that.

A second domain is not ready to fork yet. The deploy shape is. Each backend takes an `id`, writes an outputs file, and the website reads Amplify env vars. The fork docs now match the build. The fork docs, calendar example, and website client id now match the build. Still open: commit the visible-name change with the template before the trial.

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

### 2. Make the fork docs match the build — done

`web-app-893` and `dliv-web` `CONTEXT.md` and `README.md` now match the build: `APP_REGION`, tokens in `localStorage`, PDF search and video convert optional, and `video-convert-893` in the family table. A new domain forks `web-app-893`.

### 3. Stop the calendar example from reusing DLIV’s table — done

The calendar example omits `calendarTable` and `createTable`. The table defaults to `{id}-calendar` and `createTable` defaults to `true`. Set `createTable` to `false` after that first deploy. `id` comes from `base/bin/config.ts`. The live dliv config still uses `CalendarEvents` and `createTable: false`. A trial config must not use `CalendarEvents`.

### 4. Write down which client id the website uses — done

The website copies `APP_REGION`, `USER_POOL_ID`, `USER_POOL_CLIENT_ID`, and `DROPBOX_API_URL` from `dropbox_outputs.json` (`aws_region`, `auth.user_pool_id`, `auth.user_pool_client_id`, `api.base_url`). `base_outputs.json` has a different client id, `{id}-app-client`. The website uses `{id}-dropbox-client`. Live ids stay in the gitignored outputs file.

## After that, the trial itself

Use a new `id` that is not `dliv`, `apps-893`, or `met893`. One AWS account is fine if every name is prefixed with that id. The account must be an administrator, with keys installed (`aws configure`), before `./scripts/new-site.sh` can deploy. Bootstrap that account and region once first (`npx cdk bootstrap aws://ACCOUNT/REGION`). Steps are in the [Bootstrap CDK](README.md#bootstrap-cdk) section.

1. From this repo run `./scripts/new-site.sh`. The id is the folder `~/Dev/projects/<id>/` and the base `config.ts` id. Answer yes to deploy the base stack. Invite email will not send until SES accepts the from-email.
2. Choose Dropbox, then yes to deploy it. The script copies the pool id and bucket names from `base_outputs.json`.
3. Choose calendar, then yes to deploy it. The table defaults to `{id}-calendar` and `createTable` defaults to `true`. After that deploy succeeds, set `createTable: false`. PDF search is optional. Video convert needs Dropbox already in the site folder. The script refuses it until then, because the finished MP4 opens from the Dropbox file list.
4. Fork `web-app-893`. Create a new Amplify app on that fork. Set `APP_REGION`, `USER_POOL_ID`, `USER_POOL_CLIENT_ID` (the Dropbox client), `DROPBOX_API_URL`, `CALENDAR_API_URL`, and the `SITE_*` values for the new name.
5. Leave `PDF_SEARCH_API_URL` and `VIDEO_CONVERT_API_URL` empty for the first build.
6. Open the Amplify URL. Sign in, open a slideshow, open Dropbox, open Calendar.
7. Add the custom domain in Amplify only after that URL works.

Skip `dliv-web`, `music-player-893`, and `mileage-expense-tracker-893` for this trial.
