#!/usr/bin/env python3
"""Filter coverage/lcov.info to remove untestable files from the report.

Untestable in unit tests:
- lib/ui/* (widgets, screens)
- lib/l10n/* (ARB-generated localizations)
- lib/native_bindings/* (JNIGEN bindings)
- packages/*/example/* (example apps)
"""

import re
import sys
from pathlib import Path

LCOV_PATH = Path('coverage/lcov.info')

EXCLUDE_PREFIXES = (
    'lib/ui/',
    'lib/l10n/',
    'lib/native_bindings/',
    'packages/terminate_restart/example/',
)


def should_include(sf: str) -> bool:
    return not sf.startswith(EXCLUDE_PREFIXES)


def main() -> int:
    if not LCOV_PATH.exists():
        print(f'{LCOV_PATH} not found', file=sys.stderr)
        return 1

    content = LCOV_PATH.read_text()
    records = content.split('end_of_record')
    kept = []
    total = covered = 0

    for rec in records:
        if not rec.strip():
            continue
        sf_match = re.search(r'^SF:(.+)$', rec, re.MULTILINE)
        if not sf_match:
            continue
        sf = sf_match.group(1)
        if not should_include(sf):
            continue
        kept.append(rec.strip() + '\nend_of_record\n')
        for line in rec.splitlines():
            if line.startswith('DA:'):
                total += 1
                hits = int(line.split(',')[1])
                if hits > 0:
                    covered += 1

    LCOV_PATH.write_text(''.join(kept))

    pct = (covered * 100 // total) if total else 0
    print(f'Filtered coverage: {covered}/{total} = {pct}%')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
