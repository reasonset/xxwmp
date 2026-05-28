# XXWMP (Extra External Web Media Player)

## Synopsis

Media file browser and player web application based on LWMP.

## Description

This software is a version of my previously developed LWMP (Local Web Media Player) adapted for use as a publicly accessible service on the internet.

The main differences are the addition of an authentication feature and the ability to separate drive spaces for each user.

Along with these changes, the overall application architecture has been significantly modified.  
LWMP was designed to run on Lighttpd, with the application itself operating via CGI.  
In contrast, XXWMP runs as an application server written with Roda, and its authentication mechanism is intended to work with Nginx’s `auth_request` feature.

Additionally, LWMP used `ffprobe` to provide metadata functionality, but ensuring security with that approach is difficult. For this reason, metadata functionality is currently omitted.

This software is intended to run on an internet-facing server using Nginx.  
Its provided features are strictly a file browser and media player; it does **not** function as a cloud drive.  
Therefore, it must be used in combination with a self‑hosted cloud drive such as NextCloud or Seafile, or with methods like uploading files via SFTP.

Although much of the code is reused from LWMP, the purpose of XXWMP is entirely different.  
LWMP was designed to “play files stored on your PC from your smartphone,” whereas XXWMP is meant to complement an existing drive system when its built‑in media player is insufficient.  
If your goal aligns with LWMP’s original purpose, it is recommended to use LWMP instead of XXWMP.

Currently, there is no administrative web UI, nor is there any plan to create one.  
Any functionality requiring administrative action is intended to be executed via the CLI.  
There is also no convenient feature such as a user‑initiated password reset link.

## Dependency

* Ruby >= 3.4
* LMDB
* Bundler
    * Roda
    * Puma
    * Rack / Rackup
    * LMDB
    * Oj
* Nginx (or other web server)

## Install

* `git clone https://github.com/reasonset/xxwmp.git`
* `cd xxwmp`
* `mkdir -pv var/{tokens,users}`
* Create the root directory to be served by XXWMP (e.g., `/srv/http/xxwmp`)
* Copy the files under the `static` directory into the `src` directory under the serve root  
  (e.g., `rsync -rv static/ /srv/http/xxwmp/src/`)
* Copy `config/xxwmp.yaml.sample` to `config/xxwmp.yaml` and edit it
* `bundle install`

## Configure web server

### Nginx

Refer to `config/webserver.sample/nginx.conf` for configuration examples.

### Caddy

Refer to `config/webserver.sample/Caddyfile` for configuration examples.

### Other servers

Currently, only Nginx has been tested.  
However, in theory, it should also work with Lighttpd, or Apache.

The application will function correctly as long as routing is configured as follows:

* `/browse/*` → Forward the request to the application server’s `/auth`.  
  If it returns OK, forward the request to the application server.
* `/media/*` → Forward the request to `/auth`.  
  If OK, serve files under `$xxwmp_root/media/`.
* `/login`, `/config`, `/authcheck` → Forward to the application server.
* `/` → Serve files under `$xxwmp_root/src`.

When forwarding requests to `/auth`, you must include the original request path in the `X-Original-Request-Path` header.

Possible HTTP status codes returned by `/auth` are `204`, `401`, and `403`.

## Usage

### Start server

```bash
ruby server/xxwmp.rb
```

### Add user

```bash
ruby cli/useradd.rb
```

### Update password

```bash
ruby cli/useradd.rb
```

## Media file placement

The `media/` directory under the serve root becomes the media root.

Each user’s files should be placed under:

```
<media_root>/<user>/
```

## Additional Features

### Authentication

By default, authentication is performed using a standard user ID and password.  
Passwords are set via `cli/useradd.rb`.

You can switch to alternative authentication methods using the `auth_method` setting.

When `auth_method` is set to `publickey`, the server uses a mechanism similar to SSH public key authentication combined with a challenge–response flow.  
If a client attempts to authenticate without a registered key pair, the server displays an exported public key.  
Register it using the following command:

```
ruby cli/publickey.rb add <user_id> <publickey>
```

To remove a registered key:

```
ruby cli/publickey.rb remove <publickey>
```

A single public key cannot be registered to multiple users.

### Metadata

Enable metadata support by setting `use_metadata` to `true` in `xxwmp.yaml`.

When metadata is enabled, the server returns playlists that include audio/video metadata whenever a client requests a playlist.  
If metadata for a file has not yet been retrieved, the server uses `ffprobe` to extract it.

Metadata is stored under the directory specified by `meta_root`.  
This directory does **not** need to be served by the web server.

Internally, this feature invokes `ffprobe` without performing file safety checks.  
Do **not** enable it unless you are certain that all media files come from a safe and trusted source.

### Thumbnails

Enable thumbnail support by setting `use_thumbnail` to `true` in `xxwmp.yaml`.

When enabled, the client uses an intersection observer in the file browser to fetch and replace media file thumbnails as they appear on screen.  
Thumbnails must be generated in advance using the following command:

```
cli/create-thumbnail.rb <media_root> <thumbnail_root>
```

`thumbnail_root` is the directory where thumbnails are stored.  
This directory must be accessible to clients under the `/thumb/` path.

Internally, `create-thumbnail.rb` invokes `ffmpeg` and ImageMagick without performing file safety checks.  
Do **not** enable this feature unless you are certain that all media files come from a safe and trusted source.

### Video/Audio Player Libraries

You can specify custom video or audio player libraries in `xxwmp.yaml` using the `videoplayer` and `audioplayer` settings.  
When configured, these libraries replace the default HTML `<video>` and `<audio>` elements.

Libraries are loaded from a CDN only when explicitly specified.

Supported values are:

- `vidstack` (Vidstack)  
- `vlitejs` (vLiteJS)  
- `plyr` (Plyr)  
- `fluid` (Fluid Player) — *not available for `audioplayer`*

## Open Source Licenses

This project is licensed under the Apache License 2.0. 
However, it includes or bundles the following third-party components under different licenses:

- [Feather Icons](https://feathericons.com/) - Distributed under the [MIT License](opensource.org).
- [FiraSans](https://github.com/bBoxType/FiraSans) - Distributed under the [SIL Open Font License 1.1](openfontlicense.org).
- [Genos](https://github.com/googlefonts/genos) - Distributed under the [SIL Open Font License 1.1](openfontlicense.org).
- [Local Web Media Player](https://github.com/reasonset/localwebmediaplayer) - Distributed under the [Apache-2.0](http://www.apache.org/licenses/)

For more details and the full text of the licenses, please refer to the [LICENSE-3RD-PARTY.md](LICENSE-3RD-PARTY.md) file.
