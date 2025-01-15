# [Cairo](https://cairographics.org/) packaged for Zig

This repo builds Cairo using Zig's build system and C compiler frontend. Its primary use is to simplify cross-compiling and static linking for [zigplug](https://github.com/bandithedoge/zigplug).

**These are not language bindings.** You still have to use Cairo's C headers to do anything useful with this in your own projects.

Several packages in the `pkg/` directory were copied from [Ghostty](https://github.com/ghostty-org/ghostty/tree/main/pkg).
