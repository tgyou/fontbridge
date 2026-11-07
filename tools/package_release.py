import re
import zipfile
from pathlib import Path


def build_release():
    root = Path(__file__).resolve().parent.parent
    toc = root / "FontBridge.toc"
    metadata = toc.read_text(encoding="utf-8")
    version = re.search(r"^## Version: ([0-9A-Za-z._-]+)$", metadata, re.MULTILINE)
    if not version:
        raise ValueError("FontBridge.toc must declare a valid Version")

    paths = {toc, root / "README.md", root / "Fonts/README.txt", root / "Libs/LICENSE-LGPL-2.1.txt"}
    for line in metadata.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            paths.add(root / line.replace("\\", "/"))

    for path in paths:
        path.resolve().relative_to(root)
        if path.suffix.lower() not in {".lua", ".toc", ".txt", ".md"}:
            raise ValueError(f"Unexpected release asset: {path.name}")
        if not path.is_file():
            raise FileNotFoundError(path)

    output = root / "dist" / f"FontBridge-{version.group(1)}.zip"
    output.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(paths):
            archive.write(path, Path("FontBridge") / path.relative_to(root))

    with zipfile.ZipFile(output) as archive:
        expected = {f"FontBridge/{path.relative_to(root).as_posix()}" for path in paths}
        if set(archive.namelist()) != expected or archive.testzip() is not None:
            raise ValueError("Release archive verification failed")
    print(f"Created {output} ({len(paths)} files; no font binaries)")
    return output


if __name__ == "__main__":
    build_release()
