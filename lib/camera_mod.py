"""CrimsonCamera — on-the-fly camera modification for Crimson Desert.

Extracts the vanilla camera XML from the game's PAZ archive, applies
user-chosen modifications, size-matches, compresses, encrypts, and
patches the result back.  Works on any game version automatically.

Usage:
    python camera_mod.py <game_dir> --style shoulder --height medium --fov 60 --steadycam --combat wide
    python camera_mod.py <game_dir> --restore
"""

import argparse
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from paz_crypto import decrypt, encrypt, lz4_decompress
from paz_parse import parse_pamt
from paz_repack import _match_compressed_size
import lz4.block

from camera_rules import build_modifications


# ── XML modification engine ────────────────────────────────────────

TAG_RE = re.compile(r'<(\w+)\s+([^>]*?)(/?)>')

SUBELEMENT_TAGS = frozenset({
    'CameraDamping', 'CameraBlendParameter', 'OffsetByVelocity',
    'PivotHeight', 'ZoomLevel',
})

FOV_SECTION_TYPES = frozenset({'TPS', 'TwoTargetLockOn'})


def _parse_attrs(attrs_str):
    return dict(re.findall(r'(\w+)="([^"]*)"', attrs_str))


def apply_modifications(xml_text, mod_set):
    """Apply element-level modifications and static FoV to XML text.

    Walks line by line, tracks parent context, and modifies attribute
    values using regex substitution.  Also applies the global FoV pass
    on Type="TPS" and Type="TwoTargetLockOn" sections.
    """
    element_mods = mod_set.element_mods
    fov_value = mod_set.fov_value

    lines = xml_text.split('\n')
    parent_stack = []
    result = []

    for line in lines:
        stripped = line.strip()

        if stripped == '</>':
            result.append(line)
            if parent_stack:
                parent_stack.pop()
            continue

        m = TAG_RE.match(stripped)
        if not m:
            result.append(line)
            continue

        tag = m.group(1)
        attrs_str = m.group(2)
        self_closing = m.group(3) == '/'
        attrs = _parse_attrs(attrs_str)

        parent_tag, parent_applies_fov, parent_fov = (
            parent_stack[-1] if parent_stack else ('', False, 0)
        )

        if tag == 'ZoomLevel':
            level = attrs.get('Level', '?')
            key = f'{parent_tag}/ZoomLevel[{level}]' if parent_tag else f'ZoomLevel[{level}]'
        else:
            key = f'{parent_tag}/{tag}' if parent_tag else tag

        modified_line = line

        if key in element_mods:
            for attr, (action, value) in element_mods[key].items():
                if action == 'SET':
                    if re.search(rf'{attr}="', modified_line):
                        modified_line = re.sub(
                            rf'{attr}="[^"]*"',
                            f'{attr}="{value}"',
                            modified_line, count=1,
                        )
                    else:
                        modified_line = re.sub(
                            r'(/?>)',
                            f' {attr}="{value}"\\1',
                            modified_line, count=1,
                        )
                elif action == 'REMOVE':
                    modified_line = re.sub(rf'\s+{attr}="[^"]*"', '', modified_line)

        if fov_value > 0:
            applies_fov = attrs.get('Type') in FOV_SECTION_TYPES

            if tag not in SUBELEMENT_TAGS and tag != 'ZoomLevel':
                if applies_fov and 'Fov' in attrs:
                    modified_line = re.sub(
                        r'Fov="[^"]*"',
                        f'Fov="{fov_value}"',
                        modified_line, count=1,
                    )
            elif tag == 'ZoomLevel' and parent_applies_fov:
                level_num = int(attrs.get('Level', '0'))
                if level_num < 2:
                    result.append(modified_line)
                    continue
                if 'InDoorFov' in attrs:
                    modified_line = re.sub(
                        r'InDoorFov="[^"]*"',
                        f'InDoorFov="{fov_value}"',
                        modified_line, count=1,
                    )
                if 'Fov' in attrs:
                    modified_line = re.sub(
                        r'Fov="[^"]*"',
                        f'Fov="{fov_value}"',
                        modified_line, count=1,
                    )

                if parent_fov > 0:
                    zd_match = re.search(r'ZoomDistance="([^"]*)"', modified_line)
                    if zd_match:
                        current_zd = float(zd_match.group(1))
                        if current_zd > 0:
                            ratio = (math.tan(math.radians(parent_fov / 2))
                                     / math.tan(math.radians(fov_value / 2)))
                            new_zd = round(current_zd * ratio, 2)
                            modified_line = re.sub(
                                r'ZoomDistance="[^"]*"',
                                f'ZoomDistance="{new_zd}"',
                                modified_line, count=1,
                            )

        result.append(modified_line)

        if tag not in SUBELEMENT_TAGS and tag != 'ZoomLevel':
            applies_fov = attrs.get('Type') in FOV_SECTION_TYPES
            original_fov = float(attrs.get('Fov', '0')) if applies_fov else 0
            if not self_closing:
                parent_stack.append((tag, applies_fov, original_fov))

    return '\n'.join(result)


def strip_header_comments(xml_text):
    """Strip Korean comment blocks at the top of the XML.

    Creates ~700 bytes of zero-padding room for the size matcher.
    """
    lines = xml_text.split('\n')
    result = []
    in_comment = False
    header_done = False

    for line in lines:
        stripped = line.strip()

        if header_done:
            result.append(line)
            continue

        if '<!--' in stripped and '-->' not in stripped:
            in_comment = True
            continue
        if in_comment:
            if '-->' in stripped:
                in_comment = False
            continue
        if stripped.startswith('<!--') and stripped.endswith('-->'):
            continue
        if not stripped:
            continue

        header_done = True
        result.append(line)

    return '\n'.join(result)


# ── Backup management ──────────────────────────────────────────────

def _backups_dir():
    return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        'backups')


def _ensure_backup(entry):
    """Create backup of original PAZ bytes on first run.

    If the game has updated (comp_size changed), the old backup is
    stale — delete it and re-backup from the now-vanilla PAZ.
    """
    bdir = _backups_dir()
    backup_path = os.path.join(bdir, 'original_backup.bin')
    meta_path = os.path.join(bdir, 'backup_meta.txt')

    if os.path.exists(backup_path) and os.path.exists(meta_path):
        with open(meta_path) as f:
            for part in f.read().split():
                if part.startswith('comp_size='):
                    saved_comp = int(part.split('=')[1])
                    if saved_comp == entry.comp_size:
                        return

    os.makedirs(bdir, exist_ok=True)
    with open(entry.paz_file, 'rb') as f:
        f.seek(entry.offset)
        data = f.read(entry.comp_size)
    with open(backup_path, 'wb') as f:
        f.write(data)
    with open(meta_path, 'w') as f:
        f.write(f'comp_size={entry.comp_size} orig_size={entry.orig_size}')
    print(f'  Backup saved ({entry.comp_size} bytes)')


def _get_vanilla_xml(entry):
    """Extract vanilla XML from backup."""
    backup_path = os.path.join(_backups_dir(), 'original_backup.bin')
    with open(backup_path, 'rb') as f:
        encrypted = f.read()
    decrypted = decrypt(encrypted, 'playercamerapreset.xml')
    xml_bytes = lz4_decompress(decrypted, entry.orig_size)
    return xml_bytes.rstrip(b'\x00').decode('utf-8-sig')


# ── PAZ writing ────────────────────────────────────────────────────

def _write_to_paz(entry, encrypted_bytes):
    """Write encrypted bytes to the PAZ file at the entry's offset."""
    paz_path = entry.paz_file
    stat_before = os.stat(paz_path)

    with open(paz_path, 'r+b') as f:
        f.seek(entry.offset)
        f.write(encrypted_bytes)

    os.utime(paz_path, (stat_before.st_atime, stat_before.st_mtime))


# ── Main operations ────────────────────────────────────────────────

def _find_camera_entry(game_dir):
    """Parse PAMT and find the playercamerapreset.xml entry."""
    pamt_path = os.path.join(game_dir, '0010', '0.pamt')
    paz_dir = os.path.join(game_dir, '0010')

    if not os.path.exists(pamt_path):
        print(f'  ERROR: PAMT not found: {pamt_path}')
        sys.exit(1)

    entries = parse_pamt(pamt_path, paz_dir=paz_dir)
    for e in entries:
        if 'playercamerapreset.xml' in e.path:
            return e

    print('  ERROR: playercamerapreset.xml not found in PAMT')
    sys.exit(1)


def install_camera_mod(game_dir, style, height, fov, steadycam, combat):
    """Apply camera modifications to the game."""
    print('  Finding camera entry...')
    entry = _find_camera_entry(game_dir)
    print(f'  Found: offset={entry.offset}, comp_size={entry.comp_size}, '
          f'orig_size={entry.orig_size}')

    print('  Ensuring backup...')
    _ensure_backup(entry)

    print('  Extracting vanilla XML...')
    vanilla_xml = _get_vanilla_xml(entry)

    print('  Stripping header comments...')
    vanilla_xml = strip_header_comments(vanilla_xml)

    print('  Building modification rules...')
    mod_set = build_modifications(style, height, fov, steadycam, combat)
    mod_count = sum(len(v) for v in mod_set.element_mods.values())
    print(f'  Rules: {mod_count} attribute changes'
          + (f', FoV={mod_set.fov_value}' if mod_set.fov_value else ''))

    print('  Applying modifications...')
    modified_xml = apply_modifications(vanilla_xml, mod_set)

    print('  Encoding and size-matching...')
    xml_bytes = modified_xml.encode('utf-8-sig')
    matched = _match_compressed_size(xml_bytes, entry.comp_size, entry.orig_size)

    print('  Compressing...')
    compressed = lz4.block.compress(matched, store_size=False)
    assert len(compressed) == entry.comp_size, \
        f'Size mismatch: {len(compressed)} != {entry.comp_size}'

    print('  Encrypting...')
    encrypted = encrypt(compressed, 'playercamerapreset.xml')

    print('  Patching game files...')
    _write_to_paz(entry, encrypted)

    print('  Done!')
    return {'status': 'ok', 'comp_size': entry.comp_size}


def restore_camera(game_dir):
    """Restore vanilla camera from backup."""
    entry = _find_camera_entry(game_dir)
    backup_path = os.path.join(_backups_dir(), 'original_backup.bin')

    if not os.path.exists(backup_path):
        print('  No backup found. The camera may already be vanilla.')
        print('  If needed, use Steam > Verify Integrity of Game Files.')
        return {'status': 'no_backup'}

    with open(backup_path, 'rb') as f:
        backup_data = f.read()

    if len(backup_data) != entry.comp_size:
        print(f'  Backup size ({len(backup_data)}) does not match current '
              f'game version ({entry.comp_size}).')
        print('  The game may have been updated. Deleting stale backup.')
        os.remove(backup_path)
        meta_path = os.path.join(_backups_dir(), 'backup_meta.txt')
        if os.path.exists(meta_path):
            os.remove(meta_path)
        return {'status': 'stale_backup'}

    print('  Restoring original camera...')
    _write_to_paz(entry, backup_data)
    print('  Done! Camera restored to vanilla.')
    return {'status': 'ok'}


# ── CLI ────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='CrimsonCamera mod tool')
    parser.add_argument('game_dir', help='Path to Crimson Desert game folder')
    parser.add_argument('--restore', action='store_true',
                        help='Restore vanilla camera')
    parser.add_argument('--style', choices=['shoulder', 'centered'],
                        default='shoulder')
    parser.add_argument('--height', choices=['slight', 'medium', 'vlow'],
                        default='medium')
    parser.add_argument('--fov', type=int, default=0,
                        help='Static FoV value (50-100, 0=no change)')
    parser.add_argument('--steadycam', action='store_true')
    parser.add_argument('--combat', choices=['default', 'wide', 'max'],
                        default='default')

    args = parser.parse_args()

    if args.restore:
        result = restore_camera(args.game_dir)
    else:
        if args.fov and not (50 <= args.fov <= 100):
            print(f'  ERROR: FoV must be between 50 and 100 (got {args.fov})')
            sys.exit(1)
        result = install_camera_mod(
            args.game_dir, args.style, args.height, args.fov,
            args.steadycam, args.combat)

    sys.exit(0 if result.get('status') == 'ok' else 1)


if __name__ == '__main__':
    main()
