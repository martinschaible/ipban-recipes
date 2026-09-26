# IPBan Recipes

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

## Lists

| File | Use it when |
| --- | --- |
| `lists/files-sensitive.txt` | Any site. Secrets, dotfiles, SQL dumps, cloud credentials, and VCS metadata. |
| `lists/files-credentials.txt` | Any site. Further credential files, framework config, and backup archives. |
| `lists/files-admin.txt` | Any site. Database and server admin panels, plus WordPress user enumeration at `wp-json/wp/v2/users`. |
| `lists/files-products.txt` | Any site. Paths that belong to other products (PHPUnit, Spring, routers, Exchange, VPN portals). |
| `lists/files-php.txt` | Any site. Short PHP names commonly dropped in as probes or shells. Several names are generic (`admin.php`, `info.php`, `file.php`) and can match a real file. |
| `lists/files-webshell.txt` | Any site. Fixed webshell filenames. |
| `lists/files-wordpress.txt` | WordPress sites included. Requests for `wp-config.php`, its backup copies, and `wp-content/debug.log`. Those files must not be downloaded, including on a real WordPress site. |
| `lists/probing-wordpress.txt` | Sites that do **not** run WordPress. |

## Sites that are not WordPress

`lists/probing-wordpress.txt` matches the normal WordPress entry points:

- `wp-login.php`
- `wp-admin`
- `wp-content`
- `wp-includes`

On a site without WordPress, a request for any of these is a probe. On a WordPress site, visitors and the application request `wp-content` and `wp-includes` on ordinary page views. Assigning this list there bans normal traffic.

Do not merge this list into `lists/files-wordpress.txt`. That file stays valid on WordPress, because it targets config and log files that should never be served.
