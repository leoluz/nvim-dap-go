# nvim-dap-go

An extension for [nvim-dap][1] providing configurations for launching go debugger (delve) and debugging individual tests.

## Features

- Auto launch Delve. No configuration needed. You just have to have `dlv` in your path.
- Run just the closest test from the cursor in debug mode (uses treesitter). See [debugging individual tests](#debugging-individual-tests) section bellow for more details.
- Configuration to attach nvim-dap and Delve into a running process and start a debug session.
- Configuration to start a debug session in the main function.
- Configuration to run tests in a debug session.

## Pre-reqs

- Neovim >= 0.5
- [nvim-dap][1]
- [delve][2] >= 1.7.0

This plugin extension make usage of treesitter to find the nearest test to debug.
Make sure you have the Go treesitter parser installed. 
If using [nvim-treesitter][3] plugin you can install with `:TSInstall go`.

## Installation

- Install like any other neovim plugin:
  - If using [vim-plug][4]: `Plug 'leoluz/nvim-dap-go'`
  - If using [packer.nvim][5]: `use 'leoluz/nvim-dap-go'`

## Usage

### Register the plugin

Call the setup function in your `init.vim` to register the go adapter and the configurations to debug go tests:

```vimL
lua require('dap-go').setup()
```

### Use nvim-dap as usual

- Call `:lua require('dap').continue()` to start debugging.
- All pre-configured debuggers will be displayed for you to choose from.
- See `:help dap-mappings` and `:help dap-api`.

### Debugging individual tests

To debug the closest method above the cursor use you can run:
- `:lua require('dap-go').debug_test()` 

It is better to define a mapping to invoke this command. See the mapping section bellow.

## Mappings

```vimL
nmap <silent> <leader>td :lua require('dap-go').debug_test()<CR>
```

## Acknowledgement

Thanks to the [nvim-dap-python][6] for the inspiration.

[1]: https://github.com/mfussenegger/nvim-dap
[2]: https://github.com/go-delve/delve
[3]: https://github.com/nvim-treesitter/nvim-treesitter
[4]: https://github.com/junegunn/vim-plug
[5]: https://github.com/wbthomason/packer.nvim
[6]: https://github.com/mfussenegger/nvim-dap-python
