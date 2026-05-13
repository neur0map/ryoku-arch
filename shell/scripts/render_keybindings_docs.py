import sys
from pathlib import Path

from parse_niri_keybinds import parse_niri_config


SECTION_TITLES = {
    'System': 'Session And Compositor',
    'Ryoku Shell': 'Shell Surfaces',
    'Window Switcher': 'Window Switcher',
    'Screenshots': 'Screenshots And Region Tools',
    'Applications': 'App Launchers',
    'Window Management': 'Window Management',
    'Layout': 'Column Layout',
    'Resize': 'Resize',
    'Focus': 'Focus',
    'Move Windows': 'Move Windows',
    'Monitors': 'Monitors',
    'Workspaces': 'Workspaces',
    'Media': 'Media',
    'Brightness': 'Brightness',
    'Other': 'Other',
}


def markdown_escape(value: str) -> str:
    return value.replace('|', '\\|')


def combo_for(keybind: dict) -> str:
    combo = keybind.get('combo')
    if combo:
        return combo

    parts = list(keybind.get('mods', [])) + [keybind.get('key', '')]
    return '+'.join(parts)


def iter_category_keybinds(parsed: dict):
    for category in parsed.get('children', []):
        name = category.get('name', 'Other')
        keybinds = []

        for child in category.get('children', []):
            keybinds.extend(child.get('keybinds', []))

        if keybinds:
            yield name, keybinds


def render(config_path: Path) -> str:
    parsed = parse_niri_config(config_path)
    lines = [
        '# Ryoku Keybindings',
        '',
        f'Source of truth: `{config_path.as_posix()}`.',
        '',
        'This page is generated. Edit the Niri bind source, then run `bin/ryoku-dev-generate-keybindings-docs`.',
        '',
        '`Mod` means `Super` on a normal Ryoku install. In a nested Niri session, `Mod` means `Alt`.',
        '',
    ]

    for category, keybinds in iter_category_keybinds(parsed):
        title = SECTION_TITLES.get(category, category)
        lines.extend([
            f'## {title}',
            '',
            '| Binding | Action |',
            '| --- | --- |',
        ])

        for keybind in keybinds:
            combo = markdown_escape(combo_for(keybind))
            comment = markdown_escape(keybind.get('comment', ''))
            lines.append(f'| `{combo}` | {comment}. |')

        lines.append('')

    return '\n'.join(lines).rstrip() + '\n'


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: render_keybindings_docs.py <niri-binds.kdl>', file=sys.stderr)
        return 2

    sys.stdout.write(render(Path(sys.argv[1])))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
