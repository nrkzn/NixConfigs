# NixConfigs

A flake-based NixOS + home-manager configuration for two hosts, laid out the
way Vimjoyer's NixOS YouTube series recommends.

## Layout

```
.
├── flake.nix                       # inputs + outputs, auto-imports modules
├── hosts/
│   ├── desktop/                    # Hyprland workstation
│   │   ├── configuration.nix       # picks which nixos-modules to enable
│   │   ├── home.nix                # picks which home-manager-modules to enable
│   │   └── hardware-configuration.nix
│   └── mediaserver/                # headless Nixarr media server
│       ├── configuration.nix
│       ├── home.nix
│       └── hardware-configuration.nix
├── nixos-modules/                  # reusable system modules
│   ├── core.nix                    # nix settings, locale, base packages
│   ├── boot.nix                    # systemd-boot EFI
│   ├── networking.nix              # NetworkManager + firewall
│   ├── users.nix                   # primary user 'nathan'
│   ├── audio.nix                   # PipeWire
│   ├── bluetooth.nix               # bluez + blueman
│   ├── fonts.nix                   # Nerd Fonts + Noto
│   ├── hyprland.nix                # Hyprland + greetd + portals
│   ├── gpu-nvidia.nix              # opt-in NVIDIA drivers
│   ├── gpu-amd.nix                 # opt-in AMD Mesa stack
│   ├── gaming.nix                  # Steam + gamemode + gamescope
│   ├── virtualisation.nix          # docker + libvirt toggles
│   ├── ssh.nix                     # OpenSSH (key-only)
│   ├── server-base.nix             # headless server baseline
│   └── nixarr.nix                  # Jellyfin + *arr stack + Transmission
└── home-manager-modules/           # reusable home modules
    ├── core.nix                    # XDG + CLI tools
    ├── git.nix                     # git + gh
    ├── zsh.nix                     # zsh + starship + fzf + zoxide + direnv
    ├── neovim.nix                  # neovim with treesitter/telescope/lsp
    ├── tmux.nix                    # tmux with sensible defaults
    ├── kitty.nix                   # terminal
    ├── hyprland.nix                # Hyprland user config (keybinds, etc.)
    ├── waybar.nix                  # status bar
    ├── firefox.nix                 # browser
    └── desktop-apps.nix            # GUI app bundle
```

## How it works

`flake.nix` recursively imports every `.nix` file under `nixos-modules/` and
`home-manager-modules/`. Each module declares `myNixOS.<name>.enable` (or
`myHomeManager.<name>.enable`) and wraps its config in `lib.mkIf`. Hosts pick
features by flipping those switches in `hosts/<host>/configuration.nix` and
`hosts/<host>/home.nix`.

## First-time setup on a new machine

1. Install NixOS using the standard installer.
2. Clone this repo to `/etc/nixos` and give it to your user:
   ```
   sudo git clone https://github.com/nrkzn/NixConfigs.git /etc/nixos
   sudo chown -R nathan:users /etc/nixos
   ```
3. Generate the machine's hardware file (it is gitignored, like `flake.lock` —
   both are **per machine and never committed**):
   ```
   nixos-generate-config --show-hardware-config > /etc/nixos/hosts/<host>/hardware-configuration.nix
   ```
4. Build and switch. Always use `path:` — it reads the repo from disk, so the
   ignored per-machine files are included (a plain `--flake /etc/nixos`
   would only see git-tracked files and miss them). The flake has an entry
   per hostname (`blackeye`, `holodeck`), so no `#name` is needed:
   ```
   sudo nixos-rebuild switch --flake path:/etc/nixos
   ```
5. As root, set the user's password: `passwd nathan` (no passwords are
   stored in this repo).

## Updating

The zsh aliases wrap these (`update`, `rebuild`):

```
git -C /etc/nixos pull --ff-only                      # config changes
nix flake update --flake path:/etc/nixos              # bump inputs (local flake.lock)
sudo nixos-rebuild switch --flake path:/etc/nixos     # rebuild
```

## Standalone home-manager (optional)

If you want to run home-manager without rebuilding the system:

```
home-manager switch --flake .#nathan@desktop
```

## Inputs

- `nixpkgs` — `nixos-unstable`
- `home-manager` — follows nixpkgs
- `hyprland` — official flake (used by desktop)
- `nixarr` — `rasmus-kirk/nixarr` (used by mediaserver)
- `sops-nix` — encrypted secrets (used by mediaserver; recipients in `.sops.yaml`)

## TRaSH-Guides followup

The mediaserver's [configuration.nix](hosts/mediaserver/configuration.nix) uses
Nixarr's `settings-sync` to declaratively wire:

- Prowlarr → all *arr apps (indexer push) via `enable-nixarr-apps = true`
- Sonarr → Transmission (defaults; set category in Sonarr UI if you want sorting)
- Radarr → Transmission (defaults; set category in Radarr UI if you want sorting)

Library layout (created by the flake's tmpfiles rules under `/data/media`):

```
/data/media/
├── library/        ← *arr root folders point here
│   ├── shows/      ← Sonarr root
│   ├── movies/     ← Radarr root
│   ├── music/      ← Lidarr root
│   └── books/      ← Shelfmark root
└── torrents/       ← Transmission downloads land here, hardlinked into library/ on import
```
- Bazarr → Sonarr + Radarr (library list pull, monitored-only)

That covers the **connectivity** assumptions in TRaSH-Guides.

### Recyclarr (quality profiles, custom formats, naming)

[hosts/mediaserver/recyclarr.nix](hosts/mediaserver/recyclarr.nix) enables
Nixarr's Recyclarr module, which syncs TRaSH-Guides into Sonarr and Radarr
daily: quality definitions (file sizes), TRaSH's **German** profiles with
their custom formats, and TRaSH's Jellyfin naming schemes. API keys are
injected by Nixarr — nothing to set.

Profiles (in both Sonarr and Radarr):

- **[German] HD Bluray + WEB** — everything that isn't anime
- **[German] Anime HD Bluray + WEB** — anime (set Seerr's *Anime Quality
  Profile* to this one)

Both prefer **German DL** releases (German dub + original audio: English for
English shows, Japanese for anime), accept German-only or original-only as a
stopgap, and keep upgrading towards German DL.

Trigger a sync by hand / read its output:

```
sudo systemctl start recyclarr
journalctl -u recyclarr -e
```

### Still manual (one-time, in each web UI)

1. **Indexers** — add them in Prowlarr once; they auto-push to Sonarr/Radarr/
   Lidarr because of `enable-nixarr-apps`.
2. **Root folders** — Settings → Media Management → Root Folders:
   Sonarr `/data/media/library/shows`, Radarr `/data/media/library/movies`,
   Lidarr `/data/media/library/music`.
3. **Use the synced profiles** — after Recyclarr's first run, pick
   *[German] HD Bluray + WEB* (or the *Anime* one) when adding series/movies.
   Existing items: Mass Editor → Quality Profile. Anime series in Sonarr
   also need Series Type → *Anime*.
4. **Jellyfin audio** — per user, Settings → Playback → *Preferred audio
   language*: German to default to the dub, or leave empty to get the
   release's default track; switch tracks in the player either way.
5. **Media Management toggles** (TRaSH basics): *Use Hardlinks instead of
   Copy* on, *Rename* on (Recyclarr sets the format), *Unmonitor Deleted*
   on, *Propers and Repacks* → **Do not Prefer** (the custom formats score
   them instead).
6. **Lidarr** — Recyclarr doesn't support it; follow
   [TRaSH's Lidarr guide](https://trash-guides.info/Lidarr/) by hand if wanted.
7. **Seerr** — Settings → General → *Enable Proxy Support* (it sits behind
   the Cloudflare tunnel), and point its Sonarr/Radarr servers at the synced
   profiles.

### Jellyfin transcoding on the GTX 970M (Maxwell)

The 970M has hard limits TRaSH-Guides' Jellyfin recommendations don't account
for. After first boot, in Jellyfin → Dashboard → Playback → Transcoding:

- **Hardware acceleration**: NVIDIA NVENC
- **Enable hardware decoding for**: H.264, VP9, VC-1, MPEG-2 (8-bit only)
- **Enable hardware encoding**: ✅
- **Hardware encoding codecs**: H.264 **only** (uncheck HEVC, AV1)
- **Disable**: HEVC 10-bit decode, anything AV1

Most x265/HEVC content in your library will hardware-decode but CPU-encode.
For a small library this is fine; for many simultaneous remote streams,
consider direct-play presets per device instead of transcoding.

## Adding a new module

1. Drop a new `.nix` file under `nixos-modules/` or `home-manager-modules/`.
2. Give it an `myNixOS.<name>.enable` / `myHomeManager.<name>.enable` option.
3. Wrap config in `lib.mkIf config.myNixOS.<name>.enable { … }`.
4. Enable it from the relevant host file.

No need to touch `flake.nix` — the importer picks it up automatically.
