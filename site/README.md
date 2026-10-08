# Praxmodoro website and beta waitlist

The public site for Praxmodoro: a single landing page with the beta waitlist, a privacy notice, beta terms and a 404 page. It runs on Cloudflare Pages (free plan). Sign-ups go to a small Cloudflare D1 database through one Pages Function.

**Nothing has been deployed yet.** The steps below are for you to run with your own Cloudflare account. You can do step 1 today, before buying the domain, and the waitlist will work on a free `*.pages.dev` address.

```
site/
  public/            the website, served as-is (HTML, CSS, JS, fonts, images)
  functions/         the API: /api/waitlist, /api/waitlist/export, /api/health
  migrations/        the database table
  src/pages/         page templates: edit these, then run `npm run build`
  src/lib/           the API's logic (validation, rate limit, CSV), unit-tested
  site.config.json   the site address and contact email, in one place
  wrangler.toml      Cloudflare settings
```

You need Node.js 22.13 or newer. Run `npm install` once inside `site/`.

---

## 1. Put the site live on a free pages.dev address

1. Create a free Cloudflare account at [dash.cloudflare.com](https://dash.cloudflare.com/sign-up).
2. In a terminal, go to this folder: `cd site`, then run `npm install`.
3. Log in from the terminal. A browser window opens; approve it.
   ```sh
   npx wrangler login
   ```
4. Create the database:
   ```sh
   npx wrangler d1 create praxmodoro-waitlist
   ```
   It prints a `database_id` (a long id with dashes). Open `wrangler.toml` and paste it in place of `00000000-0000-0000-0000-000000000000`.
5. Create the table in that database:
   ```sh
   npm run db:migrate:remote
   ```
6. Create the Pages project:
   ```sh
   npx wrangler pages project create praxmodoro --production-branch main
   ```
   Cloudflare tells you the address, normally `https://praxmodoro.pages.dev`. If that name is taken, it gives you a slightly different one. In that case put the address it gave you into `siteUrl` in `site.config.json` and run `npm run build`.
7. Set the two secrets. Each command asks you to paste a value. Make each value with `openssl rand -hex 32` (it prints a random 64-character string) and keep the `ADMIN_TOKEN` somewhere safe, like your password manager. You need it to download the list.
   ```sh
   openssl rand -hex 32
   npx wrangler pages secret put ADMIN_TOKEN --project-name praxmodoro
   openssl rand -hex 32
   npx wrangler pages secret put IP_HASH_SALT --project-name praxmodoro
   ```
   `ADMIN_TOKEN` unlocks the CSV download and must be at least 24 characters. `IP_HASH_SALT` is mixed into IP addresses before they are hashed for rate limiting, so the stored hashes can't be matched against a list of addresses.
8. Deploy:
   ```sh
   npm run deploy
   ```
   This rebuilds the pages and uploads everything. Open the address from step 6, join with your own email, and check it arrived (see step 4 below).

Run `npm run deploy` again whenever you change something.

## 2. After you buy praxmodoro.com

Buy the domain through Cloudflare Registrar so the DNS is already in the right place.

1. In the Cloudflare dashboard, open **Workers & Pages**, then the **praxmodoro** project, then **Custom domains**.
2. Add `praxmodoro.com`. Cloudflare creates the DNS record and the certificate for you.
3. Add `www.praxmodoro.com` the same way.
4. Change `siteUrl` in `site.config.json` to `https://praxmodoro.com`, then run `npm run deploy`. This updates the canonical links, the share image link, the sitemap and the privacy notice.

The `pages.dev` address keeps working. You can leave it.

## 3. After you set up Zoho Mail

The site shows `hello@praxmodoro.com` as the contact address. It will not receive mail until Zoho is set up.

1. In Zoho Mail, add the domain and follow its verification step (usually a TXT record).
2. In the Cloudflare dashboard, open **praxmodoro.com**, then **DNS**, then **Records**, and add these. **Use exactly the values Zoho shows you.** The ones below are what Zoho normally shows for an account in its India data centre.

   | Type | Name | Value | Priority |
   |------|------|-------|----------|
   | MX   | `@`  | `mx.zoho.in`  | 10 |
   | MX   | `@`  | `mx2.zoho.in` | 20 |
   | MX   | `@`  | `mx3.zoho.in` | 50 |
   | TXT  | `@`  | `v=spf1 include:zoho.in ~all` | |
   | TXT  | the name Zoho gives (for example `zmail._domainkey`) | the DKIM value Zoho gives | |
   | TXT  | `_dmarc` | `v=DMARC1; p=none; rua=mailto:hello@praxmodoro.com` | |

   If there is already an SPF record (a TXT starting with `v=spf1`), edit it instead of adding a second one.
3. Wait for Zoho to show the records as verified.
4. If you want a different contact address, change `contactEmail` in `site.config.json` and run `npm run deploy`. That is the only place it is set.

## 4. Download the waitlist as a spreadsheet

```sh
curl -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  https://praxmodoro.pages.dev/api/waitlist/export -o waitlist.csv
```

Use your real address once you have the domain. The file opens in Numbers, Excel or Google Sheets. Columns: `email`, `created_at` (UTC), `fields` (which Mac, and what's hardest to start), `source` (which form), `utm` (campaign tags and referring site).

Cells that start with `=`, `+`, `-` or `@` get a leading `'` so a spreadsheet never runs them as formulas.

To delete someone who asks (replace the address):

```sh
npx wrangler d1 execute praxmodoro-waitlist --remote \
  --command "DELETE FROM waitlist WHERE email = 'someone@example.com'"
```

## 5. Turn on Turnstile (only if bots show up)

The form already has a hidden honeypot field and a limit of 5 sign-ups per connection every 10 minutes. If you still get junk sign-ups, add Cloudflare Turnstile, a free, privacy-friendly check that is usually invisible.

1. In the Cloudflare dashboard, open **Turnstile**, then **Add widget**. Add your hostnames (`praxmodoro.pages.dev`, and `praxmodoro.com` if you have it). Choose **Managed**.
2. Copy the **site key** into `wrangler.toml`. Uncomment the two lines at the bottom:
   ```toml
   [vars]
   TURNSTILE_SITE_KEY = "your site key"
   ```
3. Set the **secret key**:
   ```sh
   npx wrangler pages secret put TURNSTILE_SECRET --project-name praxmodoro
   ```
4. Run `npm run deploy`.

Set both or neither. The site key shows the widget (and lets its script through the page's security policy). The secret makes the API require a passed check. With only the secret, every sign-up fails. With only the site key, the widget shows but nothing checks it.

---

## Working on the site

### Run it on your computer

```sh
cp .dev.vars.example .dev.vars   # local-only secrets
npm run db:migrate:local         # creates the table in a local database
npm run dev                      # http://localhost:8788
```

The local database lives in `.wrangler/` and is separate from the real one. To look at local sign-ups:

```sh
npx wrangler d1 execute praxmodoro-waitlist --local --command "SELECT * FROM waitlist"
```

### Edit pages

Edit the templates in `src/pages/` (shared header, footer and head are in `src/pages/partials/`), then run `npm run build`. Don't edit the HTML files in `public/` directly: the build overwrites them, and `npm test` fails if `public/` and `src/pages/` disagree.

Styles are in `public/assets/css/site.css` and scripts in `public/assets/js/`. These are edited directly. The page's security policy blocks inline styles and scripts, so keep them in those files.

### Tests

```sh
npm test
```

This covers email checks, consent, the honeypot, duplicates, the rate limit, the CSV export and its token, the security headers, and checks on every built page: one heading 1, image sizes and alt text, no inline code, and no broken internal links.

### Images

The look of the site (the breathing light, the sky colours for each section, the fonts and the motion rules) is written down in `DESIGN.md`. Read it before changing the design.

The app screens are rendered from the approved design mocks in `design-mocks/living-companion/`, using the app's own fonts kept in `scripts/mock-fonts/` (they are not part of the website). Each screen sits in a `<figure class="screen" data-screen="…">` on the home page, so you can swap a render for a real screenshot or a short screen recording later. `DESIGN.md` has the steps under "Image slots".

The share image (`public/og.jpg`) is drawn from `scripts/brand/og.html` with the site's own CSS, and the icons from `public/favicon.svg`. The website's fonts are Zen Maru Gothic and Atkinson Hyperlegible Next, self-hosted in `public/assets/fonts/` with their licence in `OFL.txt`.

To regenerate the images you need Playwright once:

```sh
npm i -g playwright && npx playwright install chromium
NODE_PATH="$(npm root -g)" npm run render:mocks    # app screens, light and dark
NODE_PATH="$(npm root -g)" npm run render:brand    # og.jpg and icons
NODE_PATH="$(npm root -g)" npm run screenshots -- http://localhost:8788 screenshots
```

The last command saves desktop and phone screenshots in light and dark, and fails if a page scrolls sideways.

### Page counts (off)

The site has no analytics, cookies or trackers. If you want simple page counts later, turn on Cloudflare Web Analytics for the Pages project. Then allow its script in the security policy (the steps are in a comment in `src/pages/partials/head.html`) and update the privacy notice to say so.

### Before you share the link

- Read `/privacy/` and `/terms/`. Both are plain-language templates marked "not yet reviewed". Change what doesn't match how you work, then remove the banner from `src/pages/privacy.html` and `src/pages/terms.html`.
- The pages promise an unsubscribe link in every beta email. Whatever you use to send beta emails, make sure it has one.
