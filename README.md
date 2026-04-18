# vim-trustdir

Per-directory trust for Vim modelines. When a modeline sets options outside a
small safe allowlist, the plugin prompts you to trust the directory. Decisions
are remembered in `~/.vim/trust.json`, with parent-directory inheritance.

> [!WARNING]
> This plugin is **experimental**.
>
> It requires the `modeline()` built-in function, which is **not yet
> available** in released Vim. If `modeline()` is not present the plugin
> loads silently and does nothing.

## Behavior

- Disables Vim's builtin modeline processing (`set nomodeline`).
- Parses each buffer's modeline via `modeline()` on `BufReadPost`.
- If the modeline touches only allowlisted options, applies them silently.
- Otherwise, checks the current file's directory against the trust store:
  - Trusted (permanent or session) — apply all options.
  - Not trusted — prompt:
    - **Yes, always** — save to `~/.vim/trust.json` and apply.
    - **Session only** — trust for this Vim session only.
    - **No** — apply only the allowlisted options.

## Allowlist

```
autoindent cindent commentstring expandtab filetype
foldcolumn foldenable foldmethod modifiable readonly
rightleft shiftwidth smartindent softtabstop spell
spelllang tabstop textwidth varsofttabstop vartabstop
```

## Commands

| Command                      | Description                                 |
| ---------------------------- | ------------------------------------------- |
| `:TrustdirList`              | Show saved trust entries.                   |
| `:TrustdirAdd {path}`        | Permanently trust `{path}`.                 |
| `:TrustdirRemove {path}`     | Remove `{path}` from the trust store.       |

## Configuration

```vim
" Override the path to the trust store (default: ~/.vim/trust.json).
let g:trustdir_file = expand('~/.config/vim/trust.json')
```

## License

MIT
