"""PAMT index parser for Crimson Desert PAZ archives.

Parses .pamt files to discover file entries, their locations in PAZ archives,
sizes, and compression info.
"""

import os
import struct
from dataclasses import dataclass


@dataclass
class PazEntry:
    """A single file entry in a PAZ archive."""
    path: str           # Full path within the archive
    paz_file: str       # Path to the .paz file containing this entry
    offset: int         # Byte offset within the PAZ file
    comp_size: int      # Compressed/stored size in the PAZ
    orig_size: int      # Original decompressed size


def parse_pamt(pamt_path: str, paz_dir: str = None) -> list[PazEntry]:
    """Parse a .pamt index file and return all file entries.

    Args:
        pamt_path: path to the .pamt file
        paz_dir: directory containing .paz files (default: same dir as .pamt)

    Returns:
        list of PazEntry
    """
    with open(pamt_path, 'rb') as f:
        data = f.read()

    if paz_dir is None:
        paz_dir = os.path.dirname(pamt_path) or '.'

    pamt_stem = os.path.splitext(os.path.basename(pamt_path))[0]

    off = 0
    off += 4  # skip magic (varies between game versions)

    paz_count = struct.unpack_from('<I', data, off)[0]; off += 4
    off += 8  # hash + zero

    # PAZ table
    for i in range(paz_count):
        off += 4  # hash
        off += 4  # size
        if i < paz_count - 1:
            off += 4  # separator

    # Folder section
    folder_size = struct.unpack_from('<I', data, off)[0]; off += 4
    folder_end = off + folder_size
    folder_prefix = ""
    while off < folder_end:
        parent = struct.unpack_from('<I', data, off)[0]
        slen = data[off + 4]
        name = data[off + 5:off + 5 + slen].decode('utf-8', errors='replace')
        if parent == 0xFFFFFFFF:
            folder_prefix = name
        off += 5 + slen

    # Node section (path tree)
    node_size = struct.unpack_from('<I', data, off)[0]; off += 4
    node_start = off
    nodes = {}
    while off < node_start + node_size:
        rel = off - node_start
        parent = struct.unpack_from('<I', data, off)[0]
        slen = data[off + 4]
        name = data[off + 5:off + 5 + slen].decode('utf-8', errors='replace')
        nodes[rel] = (parent, name)
        off += 5 + slen

    def build_path(node_ref):
        parts = []
        cur = node_ref
        while cur != 0xFFFFFFFF and len(parts) < 64:
            if cur not in nodes:
                break
            p, n = nodes[cur]
            parts.append(n)
            cur = p
        return ''.join(reversed(parts))

    # Record section
    folder_count = struct.unpack_from('<I', data, off)[0]; off += 4
    off += 4  # hash
    off += folder_count * 16

    # File records (20 bytes each)
    entries = []
    while off + 20 <= len(data):
        node_ref, paz_offset, comp_size, orig_size, flags = \
            struct.unpack_from('<IIIII', data, off)
        off += 20

        paz_index = flags & 0xFF
        node_path = build_path(node_ref)
        full_path = f"{folder_prefix}/{node_path}" if folder_prefix else node_path

        paz_num = int(pamt_stem) + paz_index
        paz_file = os.path.join(paz_dir, f"{paz_num}.paz")

        entries.append(PazEntry(
            path=full_path,
            paz_file=paz_file,
            offset=paz_offset,
            comp_size=comp_size,
            orig_size=orig_size,
        ))

    return entries
