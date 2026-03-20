# OmniSearch Installer

A bash installer for [OmniSearch](https://git.bwaaa.monster/omnisearch) — a self-hosted meta search engine written in C, with a clean dark UI and knowledge panel.

## Requirements

- Ubuntu (or any Debian-based distro)
- Root / sudo access
- `git`, `gcc`, `make` (installer handles these automatically)

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Debronejacobs/Omnisearch/main/install.sh | sudo bash
```

Or clone and run manually:

```bash
git clone https://github.com/Debronejacobs/Omnisearch.git
cd Omnisearch
sudo bash install.sh
```

## What it does

1. Installs system dependencies (`libxml2`, `libcurl`, `gcc`, etc.)
2. Clones and builds `libbeaker` (OmniSearch's C library dependency)
3. Clones and builds `omnisearch`
4. Installs and starts it as a system service
5. Drops a config file at `/etc/omnisearch/config.ini`

## Init system support

The installer auto-detects your init system and sets up the service accordingly:

| Init system | Supported |
|-------------|-----------|
| systemd     | ✅        |
| OpenRC      | ✅        |
| runit       | ✅        |
| s6          | ✅        |

## Configuration

After installation, edit `/etc/omnisearch/config.ini`:

```ini
[server]
port = 8080
host = 127.0.0.1

[search]
# engine configuration here
```

Then restart the service:

```bash
# systemd
sudo systemctl restart omnisearch

# OpenRC
sudo rc-service omnisearch restart

# runit
sudo sv restart omnisearch
```

## Accessing OmniSearch

Once running, open your browser and go to:

```
http://localhost:8080
```

## Public hosting (optional)

For public access, put nginx in front as a reverse proxy:

```nginx
server {
    listen 80;
    server_name search.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Uninstalling

```bash
# Stop and disable the service
sudo systemctl stop omnisearch
sudo systemctl disable omnisearch

# Remove binary and config
sudo rm -rf /etc/omnisearch
sudo rm /usr/local/bin/omnisearch  # adjust path if different
```

## Dependencies

- [libbeaker](https://git.bwaaa.monster/beaker) — C utility library
- [libxml2](https://gitlab.gnome.org/GNOME/libxml2) — XML parsing
- [libcurl](https://curl.se/libcurl/) — HTTP requests

## License

Check the [OmniSearch repo](https://github.com/Debronejacobs/Omnisearch) for license details before forking or redistributing.
