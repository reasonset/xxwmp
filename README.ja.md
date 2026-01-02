# XXWMP (Extra External Web Media Player)

## Synopsis

Media file browser and player web application based on LWMP.

## Description

このソフトウェアは私が開発したLWMP(Local Web Media Player)をインターネット上で公開する形で利用できるようにしたバージョンとして開発されたものである。

主な違いは、認証機能を追加し、さらにユーザーごとのドライブスペースを区別できるようになったことである。

これに伴ってアプリケーションの構成は大きく変化している。
LWMPはLighttpdを前提とし、アプリケーション自体はCGI経由で動作するようになっていた。
対して、XXWMPはRodaで書かれたアプリケーションサーバーとして動作し、認証機能はNginxの`auth_request`機能を利用することを想定している。

また、メタデータ機能はLWMPでは`ffprobe`を利用するようになっていたが、この方式では安全性を担保するのが難しいため、現状ではメタデータ機能は省略されている。

このソフトウェアはNginxが動作するインターネットサーバー上で利用することを想定している。提供される機能はあくまでもファイルブラウザとメディアプレイヤーであり、クラウドドライブの機能は持たない。
このため、NextCloudやSeafileといったセルフホスト型のクラウドドライブと組み合わせたり、SFTPでファイルをアップロードするといった方法と組み合わせたりする必要がある。

コード的にはLWMPから流用した部分も多いが、LWMPの主旨――PCにあるファイルをスマートフォンで再生する――とは全く異なっており、基本的にドライブ側のメディアプレイヤー機能が満足できない場合に併用するためのものとなっている。
LWMPの主旨で使うのであれば、XXWMPではなくLWMPを利用することをおすすめする。

現状では管理用webUIはないし、作る予定もない。基本的に管理者の手が必要な機能はCLIから実行されるべきだと考えている。
また、ユーザーによるパスワードリセットリンクのような気の利いた機能はない。

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
* XXWMPで配信するルートディレクトリを作る (例: `/srv/http/xxwmp`)
* `static` ディレクトリ以下のファイルを配信ルートの`src`ディレクトリ以下にコピーする (例: `rsync -rv static/ /srv/http/xxwmp/src/`)
* `config/xxwmp.yaml.sample` を `config/xxwmp.yaml` としてコピーし、編集する
* `bundle install`

## Configure web server

### Nginx

`config/webserver.sample/nginx.conf` を参考にして設定してほしい。

### Caddy

`config/webserver.sample/Caddyfile` を参考にして設定してほしい。

### Other servers

現状ではテストされているのはNginxだけである。
ただし、理屈上ではLighttpd, Apacheでも動作する。

アプリケーションとしては以下のようにルーティングできれば正しく動作する。

* `/browse/*` -> アプリケーションサーバーの `/auth` にリクエストを転送し、OKが返った場合にアプリケーションサーバーにリクエストを転送する。
* `/media/*` -> アプリケーションサーバーの `/auth` にリクエストを転送し、OKが返った場合に `$xxwmp_root/media/` 以下を配信する
* `/login`, `/config`, `/authcheck` -> アプリケーションサーバーにリクエストを転送する
* `/` -> `$xxwmp_root/src` 以下を配信する

`/auth` へのリクエスト転送時は、 `X-Original-Request-Path` というヘッダーに元のリクエストパスを付加する必要がある。

`/auth` が返す可能性があるHTTPステータスは`204`, `401`, `403`である。

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

## メディアファイルの配置

配信ルート以下の`media/`ディレクトリがメディアルートになる。

各ユーザーのファイルは`<media_root>/<user>/`以下に配置する。

## Open Source Licenses

This project is licensed under the Apache License 2.0. 
However, it includes or bundles the following third-party components under different licenses:

- [Feather Icons](https://feathericons.com/) - Distributed under the [MIT License](opensource.org).
- [FiraSans](https://github.com/bBoxType/FiraSans) - Distributed under the [SIL Open Font License 1.1](openfontlicense.org).
- [Genos](https://github.com/googlefonts/genos) - Distributed under the [SIL Open Font License 1.1](openfontlicense.org).
- [Local Web Media Player](https://github.com/reasonset/localwebmediaplayer) - Distributed under the [Apache-2.0](http://www.apache.org/licenses/)

For more details and the full text of the licenses, please refer to the [LICENSE-3RD-PARTY.md](LICENSE-3RD-PARTY.md) file.
