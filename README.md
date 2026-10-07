# Curated Recipes for IPBan

Trigger lists for [IPBan](https://github.com/DigitalRuby/IPBan). Each file in `lists/` names paths that scanners request when they look for secrets, admin panels, shells, or a specific product. A hit is a reason to ban the client IP.

The files are the pattern source. They are not full IPBan recipe files yet. The recipe wrapper will follow a sample taken from the server.

## Pattern format

One regular expression per line. Lines are sorted by the path they describe.

Characters that are special in a regular expression are escaped:

| Character | Written as |
| --- | --- |
| `.` | `\.` |
| `/` | `\/` |
| `+` | `\+` |

`wp-admin` matches any request whose path contains that folder. `wp-config\.php\.bak` matches that filename only.

Short filenames in `lists/files-php.txt` start with `\/`. The name must follow a slash, so `\/i\.php` matches `/i.php` and does not match `api.php`. Extension patterns such as `\.sql` stay without that slash, because they must still match `/backup.sql`.

## Lists

| ID | File | Use it when |
| -- | ---- | ----------- |
| 02 | `lists/ssh-bad-usernames.txt` | Well known user names used for a login attempt |
| 03 | `lists/ssh-bad-usernames-internal.txt` | User names related to us or customers used for a login attempt |
| 11 | `lists/probing-ai-configurations.txt` | AI coding-agent configs and credentials (Claude, Cursor, Codex, Continue, Gemini, Aider, OpenCode, and related MCP files) |
| 12 | `lists/probing-wordpress.txt` | Only needed for websites that do **not** run WordPress |
| 13 | `lists/probing-sensitive-files.txt` | Secrets, dotfiles, SQL dumps, cloud credentials, and VCS metadata |
| 14 | `lists/probing-sensitive-folders.txt` | Folders that must not be reachable over HTTP (VCS, SSH/cloud tooling, IDE dirs, backups, vendor, node_modules) |
| 15 | `lists/probing-credentials.txt` | Credential files, framework config, etc |
| 16 | `lists/probing-backups.txt` | Any form of backup files, mostly from databases |
| 17 | `lists/probing-webshells.txt` | Fixed webshell filenames from hacked servers |
| 18 | `lists/probing-php-files.txt` | Short PHP names commonly dropped in as probes or shells. Several names are generic and can match a real file |
| 19 | `lists/probing-admin-files.txt` | Database and server admin panels, plus WordPress user enumeration at `wp-json/wp/v2/users` |
| 20 | `lists/probing-product-files.txt` | Paths that belong to other products (PHPUnit, Spring, routers, Exchange, VPN portals) |
| 30 | `lists/probing-wordpress-files.txt` | Requests for `wp-config.php`, its backup copies, other sensitive files, and the REST batch endpoint `wp-json/batch/v1` |
| 31 | `lists/probing-wordpress-wp-cron.php.txt` | `wp-cron.php` is commonly locked down. Scanners probe it heavily. On WordPress, use a real system cron instead of the HTTP pseudo-cron |
| 32 | `lists/probing-wordpress-xmlrpc.php.txt` | Scanners abuse `xmlrpc.php` for auth brute force and pingback amplification |
| 40 | `lists/proftp-bad-usernames.txt` | Well known user names used for a login attempt |

## Webshell

A webshell is a small PHP file that an attacker uploads after breaking into a server. Calling it from a browser or a script gives remote control: read and write files, run commands, and install more malware. It is a back door left on the site.

`lists/probing-webshells.txt` lists fixed filenames of well-known shells:

| File | Meaning |
| --- | --- |
| `c99.php` | C99, a classic PHP webshell |
| `r57.php` | R57, another classic PHP webshell |
| `wso.php` | WSO (“Web Shell by oRb”), often behind a login form |
| `shell.php` | Generic name used by many droppers |
| `cmd.php` | Often a minimal shell that only runs system commands |

Scanners request these names because the same shells are often left under exactly those filenames on compromised hosts. A hit usually returns 404 and means someone is looking for an existing shell, not that your site is already infected.

This list differs from credential or AI probes: those look for config files. This list looks for the door the attacker left behind.

## Sites that are not WordPress

`lists/probing-wordpress.txt` matches the normal WordPress entry points:

- `wp-login.php`
- `wp-admin`
- `wp-content`
- `wp-includes`

On a site without WordPress, a request for any of these is a probe. On a WordPress site, visitors and the application request `wp-content` and `wp-includes` on ordinary page views. Assigning this list there bans normal traffic.

Do not merge this list into `lists/probing-wordpress-files.txt`. That file stays valid on WordPress, because it targets config and log files that should never be served.

## Collect probe paths from logs

`tools/collect-probe-paths.sh` runs on a Linux server. It reads **nginx** access logs only (not httpd), keeps lines with status **403** or **404**, strips the query string, and writes a deduplicated list of paths with counts. On DirectAdmin it also picks up `/var/log/nginx/domains/*.log` (domain access logs, not only files named `access.log`).

```bash
chmod +x tools/collect-probe-paths.sh
sudo ./tools/collect-probe-paths.sh -o /root/probe-paths.txt
```

The terminal only reports success and the number of unique paths, e.g. `OK: 142 unique paths -> /root/probe-paths.txt`. The file itself contains lines like `25 /wp-login.php`.

Fetch the file with SFTP/SCP and use it to review new probing patterns for `lists/`.

<br>
<p align="center">Made with :heart: and :coffee:</p>