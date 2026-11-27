#!/usr/bin/env python3
"""Build a MudForge native multi-file plugin ZIP, not an .mfp package."""

import argparse
import re
from pathlib import Path, PurePosixPath
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
NAME = "LOTJ Companion"
MODULE = re.compile(
    rb'^[ \t]*(?:local[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*=[ \t]*)?'
    rb'loadModule\("(src/(?:widgets|application|domain)/[A-Za-z0-9_-]+\.lua)"\)[ \t]*\r?$',
    re.M,
)


def build(output: Path) -> None:
    entry = (ROOT / "src/lotj.lua").read_bytes()
    modules = sorted(set(MODULE.findall(entry)))
    if not modules or len(modules) != len(re.findall(rb'\bloadModule\s*\(', entry)):
        raise ValueError("expected unique literal loadModule calls for src/widgets, src/application, or src/domain")
    files = {f"{NAME}.lua": entry}
    for path in modules:
        relative = PurePosixPath(path.decode("ascii"))
        files[f"{NAME}/{relative}"] = (ROOT / relative).read_bytes()
    with ZipFile(output, "x", compression=ZIP_DEFLATED) as archive:
        for name, data in files.items():
            entry_info = ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry_info.create_system = 3
            entry_info.external_attr = 0o100644 << 16
            entry_info.compress_type = ZIP_DEFLATED
            archive.writestr(entry_info, data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="path to a new ZIP file")
    args = parser.parse_args()
    try:
        build(args.output)
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")
    print(args.output)


if __name__ == "__main__":
    main()
