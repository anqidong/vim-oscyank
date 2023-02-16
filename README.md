# vim-oscyank

A Vim / Neovim plugin to copy text to the system clipboard using the ANSI OSC52
sequence.

The plugin wraps a piece of text inside an OSC52 sequence and writes it to Vim's
stderr. When your terminal detects the OSC52 sequence, it will copy the text
into the system clipboard.

This is totally location-independent, you can copy text from anywhere including
from remote SSH sessions. The only requirement is that the terminal must support
the sequence. Here is a non-exhaustive list of the state of OSC52 integration in
popular terminal emulators:

| Terminal | OSC52 support |
|----------|:-------------:|
| [alacritty](https://github.com/alacritty/alacritty) | **yes** |
| [foot](https://codeberg.org/dnkl/foot) | **yes** |
| [gnome terminal](https://github.com/GNOME/gnome-terminal) (and other VTE-based terminals) | [not yet](https://bugzilla.gnome.org/show_bug.cgi?id=795774) |
| [hterm](https://chromium.googlesource.com/apps/libapps/+/master/README.md) | [**yes**](https://chromium.googlesource.com/apps/libapps/+/master/nassh/doc/FAQ.md#Is-OSC-52-aka-clipboard-operations_supported) |
| [iterm2](https://iterm2.com/) | **yes** |
| [kitty](https://github.com/kovidgoyal/kitty) | **yes** |
| [konsole](https://konsole.kde.org/) | [not yet](https://bugs.kde.org/show_bug.cgi?id=372116) |
| [qterminal](https://github.com/lxqt/qterminal#readme) | [not yet](https://github.com/lxqt/qterminal/issues/839)
| [rxvt](http://rxvt.sourceforge.net/) | **yes** |
| [st](https://st.suckless.org/) | **yes** (but needs to be enabled, see [here](https://git.suckless.org/st/commit/a2a704492b9f4d2408d180f7aeeacf4c789a1d67.html)) |
| [terminal.app](https://en.wikipedia.org/wiki/Terminal_(macOS)) | no, but see [workaround](https://github.com/roy2220/osc52pty) |
| [tmux](https://github.com/tmux/tmux) | **yes** |
| [urxvt](http://software.schmorp.de/pkg/rxvt-unicode.html) | **yes** (with a script, see [here](https://github.com/ojroques/vim-oscyank/issues/4)) |
| [wezterm](https://github.com/wez/wezterm) | [**yes**](https://wezfurlong.org/wezterm/escape-sequences.html#operating-system-command-sequences) |
| [windows terminal](https://github.com/microsoft/terminal) | **yes** |
| [xterm.js](https://xtermjs.org/) (Hyper terminal) | [not yet](https://github.com/xtermjs/xterm.js/issues/3260) |

Feel free to add terminals to this list by submitting a pull request.

## Installation
With [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'ojroques/vim-oscyank', {'branch': 'main'}
```

**If you are using tmux**, run these steps first: [enabling OSC52 in
tmux](https://github.com/tmux/tmux/wiki/Clipboard#quick-summary). Then make sure
`set-clipboard` is set to `on`: `set -s set-clipboard on`.

## Usage
Add this to your Vim config:
```vim
vim.keymap.set('n', '<leader>c', require('osc52').copy_operator, {expr = true})
vim.keymap.set('n', '<leader>cc', '<leader>c_', {remap = true})
vim.keymap.set('x', '<leader>c', require('osc52').copy_visual)
```

Using these mappings:
* In normal mode, <kbd>\<leader\>c</kbd> is an operator that will copy the given
  text to the clipboard.
* In normal mode, <kbd>\<leader\>cc</kbd> will copy the current line.
* In visual mode, <kbd>\<leader\>c</kbd> will copy the current selection.

## Configuration
The default options are:
```lua
require('osc52').setup {
  max_length = 0,  -- Maximum length of selection (0 for no limit)
  silent = false,  -- Disable message on successful copy
  trim = false,    -- Trim text before copy
}
```

## Using vim-oscyank as clipboard provider
You can use the plugin as your clipboard provider, see `:h provider-clipboard`
for more details. Simply add these lines to your Vim config:
```lua
local function copy(lines, _)
  require('osc52').copy(table.concat(lines, '\n'))
end

local function paste()
  return {vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('')}
end

vim.g.clipboard = {
  name = 'osc52',
  copy = {['+'] = copy, ['*'] = copy},
  paste = {['+'] = paste, ['*'] = paste},
}

-- Now the '+' register will copy to system clipboard using OSC52
vim.keymap.set('n', '<leader>c', '"+y')
vim.keymap.set('n', '<leader>cc', '"+yy')
```

Note that if you set your clipboard provider like the example above, copying
text from outside Vim and pasting with <kbd>p</kbd> won't work. But you can
still use the paste shortcut of your terminal emulator (usually
<kbd>ctrl+shift+v</kbd>).

## Advanced usage
The following methods are also available:
* `require('osc52').copy(text)`: copy text `text`
* `require('osc52').copy_register(register)`: copy text from register `register`

For instance, to automatically copy text that was yanked into register `c`:
```lua
function copy()
  if vim.v.event.operator == 'y' and vim.v.event.regname == 'c' then
    require('osc52').copy_register('c')
  end
end

vim.api.nvim_create_autocmd('TextYankPost', {callback = copy})
```
