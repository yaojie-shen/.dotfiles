# Neovim

## File Fuzzy Search

`fd-find` is required by telescope to speed up file search, otherwise it falls back to `find`, which is slow.


To install it:

```bash
sudo apt install fd-find
```

This is also included in the optional mise system package profile:

```bash
mise -E system bootstrap --only packages
```
