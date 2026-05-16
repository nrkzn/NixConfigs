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
2. Clone this repo to `/etc/nixos` (or anywhere).
3. Replace the placeholder hardware file with the one generated on the target:
   ```
   sudo nixos-generate-config --show-hardware-config > hosts/<host>/hardware-configuration.nix
   ```
4. Build and switch:
   ```
   sudo nixos-rebuild switch --flake .#desktop
   # or
   sudo nixos-rebuild switch --flake .#mediaserver
   ```

## Updating

```
nix flake update                                    # bump inputs
sudo nixos-rebuild switch --flake .#<host>          # rebuild
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

That covers the **connectivity** assumptions in TRaSH-Guides. What it does
**not** cover (Nixarr has no options for these — manual UI work or external
tooling required):

1. **Quality profiles** — per-app, in each web UI (Settings → Profiles).
   Or run [Recyclarr](https://recyclarr.dev/) to sync them from TRaSH templates.
2. **Custom Formats** (HQ release groups, x265 penalties, HDR, etc.) — Recyclarr.
3. **Naming schemes** — copy the TRaSH naming strings into each app's
   Settings → Media Management → Episode/Movie Naming.
4. **Indexers** — add them inside Prowlarr's web UI once; they auto-push to
   the *arr apps because of `enable-nixarr-apps`.
5. **Release profiles** (Sonarr only) — Settings → Profiles → Release Profiles.

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

### Recyclarr (recommended next step)

If you want the rest of TRaSH-Guides applied declaratively, drop a
`recyclarr.yml` somewhere and run it as a systemd timer. Sketch:

```nix
systemd.services.recyclarr = {
  description = "Apply TRaSH-Guides templates";
  after = ["sonarr.service" "radarr.service"];
  serviceConfig.Type = "oneshot";
  script = "${pkgs.recyclarr}/bin/recyclarr sync --config /etc/recyclarr.yml";
};
systemd.timers.recyclarr = {
  wantedBy = ["timers.target"];
  timerConfig.OnCalendar = "daily";
};
```

I haven't wired this in by default because the API keys it needs are
host-state, not Nix-state — easier to add once the *arr apps are up.

## Adding a new module

1. Drop a new `.nix` file under `nixos-modules/` or `home-manager-modules/`.
2. Give it an `myNixOS.<name>.enable` / `myHomeManager.<name>.enable` option.
3. Wrap config in `lib.mkIf config.myNixOS.<name>.enable { … }`.
4. Enable it from the relevant host file.

No need to touch `flake.nix` — the importer picks it up automatically.
