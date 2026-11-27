#!/usr/bin/env python3
"""Install or package the "LotJ Plugin DEV" harness plugin (QA-07).

The DEV plugin is dev/main.lua plus the production src/ modules and the
dev/ harness and scenarios. It is never part of the release ZIP
(scripts/build_preview_zip.py).

First install: build a ZIP and import it in MudForge (Plugin Manager > Import)
into a throwaway world with the release plugin turned off:

    python scripts/dev/install_dev_plugin.py --zip lotj-dev.zip

After that, every run copies the current files into the desktop app's plugins
folder. Saving them there hot-reloads the plugin (MudForge guide 19.6), and
its init() runs every scenario and prints `LOTJDEV SUMMARY passed=N failed=M`:

    python scripts/dev/install_dev_plugin.py
"""

import argparse
import subprocess
from pathlib import Path, PurePosixPath
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[2]
NAME = "LotJ Plugin DEV"
MAIN = "dev/main.lua"
DEFAULT_PLUGINS = Path.home() / "MudForge" / "plugins"


def release_copy(path, data):
    """DEV copy of a production module, served from release/ instead of src/.

    Seen in the MudForge desktop app (QA-07): the hot reload never refreshed
    the imported src/ modules, and it matches a saved file to a plugin by its
    `plugin = { id = ... }` table, so src/lotj.lua counted as the release
    plugin's file. The DEV copy renames that table and loads its modules from
    release/; the code is otherwise byte-for-byte the production code.
    """
    if path != "src/lotj.lua":
        return data
    if data.count(b"\nplugin = {") != 1:
        raise ValueError("src/lotj.lua must declare one top-level plugin table")
    data = data.replace(b"\nplugin = {", b"\nLotjReleasePlugin = {", 1)
    return data.replace(b'loadModule("src/', b'loadModule("release/')


def plugin_files(root=ROOT):
    """Map plugin-relative paths to file contents: main script plus modules."""
    listed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "--", "src", "dev"],
        cwd=root, check=True, capture_output=True, text=True,
    ).stdout.split()
    modules = sorted(p for p in listed if p.endswith(".lua") and p != MAIN)
    if MAIN not in listed or "src/lotj.lua" not in modules:
        raise ValueError("expected dev/main.lua and src/lotj.lua")
    files = {}
    for path in modules:
        data = (Path(root) / path).read_bytes()
        if path.startswith("src/"):
            files[f"{NAME}/release/{path[4:]}"] = release_copy(path, data)
        else:
            files[f"{NAME}/{PurePosixPath(path)}"] = data
    files[f"{NAME}.lua"] = (Path(root) / MAIN).read_bytes()
    return files


def build_zip(output, root=ROOT):
    with ZipFile(output, "x", compression=ZIP_DEFLATED) as archive:
        for name, data in plugin_files(root).items():
            info = ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = ZIP_DEFLATED
            archive.writestr(info, data)


def install(plugins_dir, root=ROOT):
    """Write modules first and the main script last: the app reloads the plugin
    once per batch of saves, and only a batch that includes the main script
    picked up changed modules in our runs."""
    plugins_dir = Path(plugins_dir)
    if not plugins_dir.is_dir():
        raise ValueError(f"{plugins_dir} does not exist: import the DEV ZIP in the MudForge desktop app first")
    files = plugin_files(root)
    main = files.pop(f"{NAME}.lua")
    written = []
    for name, data in list(files.items()) + [(f"{NAME}.lua", main)]:
        target = plugins_dir / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_bytes() != data or name == f"{NAME}.lua":
            target.write_bytes(data)  # the main script is always rewritten: that save triggers the run
            written.append(name)
    return written


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--zip", type=Path, help="write a new import ZIP here instead of installing")
    parser.add_argument("--plugins-dir", type=Path, default=DEFAULT_PLUGINS, help="MudForge plugins folder")
    args = parser.parse_args()
    try:
        if args.zip:
            build_zip(args.zip)
            print(args.zip)
        else:
            written = install(args.plugins_dir)
            print(f"wrote {len(written)} files to {args.plugins_dir}; MudForge reloads {NAME} and prints LOTJDEV SUMMARY")
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
