const std = @import("std");
const sources = @import("sources.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_tests = b.option(bool, "build_tests", "Build Cairo tests. Implies the following options: use_zlib=true, use_png=true, use_xlib=true") orelse false;

    const use_lzo = b.option(bool, "use_lzo", "Use LZO") orelse false;
    const use_dl = b.option(bool, "use_dl", "Use libdl for dynamic library loading") orelse false;
    const use_zlib = (b.option(bool, "use_zlib", "Use zlib") orelse true) or build_tests;
    const use_png = (b.option(bool, "use_png", "Use libpng") orelse true) or build_tests;
    const use_fontconfig = b.option(bool, "use_fontconfig", "Use Fontconfig (only affects Windows and Darwin)") orelse false;
    const use_freetype = b.option(bool, "use_freetype", "Use FreeType font backend (only affects Windows and Darwin)") orelse false;
    const use_ttx = b.option(bool, "use_ttx", "Use ttx from fonttools for converting fonts") orelse false;
    const use_tee = b.option(bool, "use_tee", "Use tee surface backend") orelse false;
    const use_xlib = (b.option(bool, "use_xlib", "Use X11 surface backend") orelse (target.result.os.tag == .linux or target.result.os.tag.isBSD())) or build_tests;
    const use_xrender = (b.option(bool, "use_xrender", "Use XRender")) orelse use_xlib;
    const use_xcb = b.option(bool, "use_xcb", "Use XCB surface backend") orelse (target.result.os.tag == .linux or target.result.os.tag.isBSD());
    const use_quartz = b.option(bool, "use_quartz", "Use Quartz surface backend (only affects Darwin)") orelse target.result.os.tag.isDarwin();
    const use_dwrite = b.option(bool, "use_dwrite", "Use DirectWrite font backend (only affects Windows)") orelse (target.result.os.tag == .windows);
    const use_glib = b.option(bool, "use_glib", "Use glib") orelse (target.result.os.tag == .linux or target.result.os.tag.isBSD());
    const use_spectre = b.option(bool, "use_spectre", "Use libspectre") orelse use_zlib;
    const symbol_lookup = b.option(bool, "symbol_lookup", "Symbol lookup in debug utils via binutils/bfd") orelse (optimize == .Debug);

    const cairo = b.dependency("cairo", .{});

    const lib = b.addStaticLibrary(.{
        .name = "cairo",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib.addIncludePath(cairo.path("src"));

    var cairo_sources = std.ArrayList([]const u8).init(b.allocator);
    defer cairo_sources.deinit();

    try cairo_sources.appendSlice(sources.cairo);

    var test_sources = std.ArrayList([]const u8).init(b.allocator);
    defer test_sources.deinit();

    try test_sources.appendSlice(sources.tests);
    var add_fallback_resolution = false;
    var build_any2ppm = false;

    var boilerplate_sources = std.ArrayList([]const u8).init(b.allocator);
    defer boilerplate_sources.deinit();
    try boilerplate_sources.appendSlice(sources.boilerplate);

    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    defer c_flags.deinit();
    try c_flags.appendSlice(&.{
        "-Wmissing-declarations",
        "-Werror-implicit-function-declaration",
        "-Wpointer-arith",
        "-Wwrite-strings",
        "-Wsign-compare",
        "-Wpacked",
        "-Wswitch-enum",
        "-Wmissing-format-attribute",
        "-Wvolatile-register-var",
        "-Wstrict-aliasing=2",
        "-Winit-self",
        // "-Wunsafe-loop-optimizations",
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-Wno-attributes",
        "-Wno-long-long",
        "-Winline",
        "-Wno-unused-but-set-variable",
        "-Wno-enum-conversion",
        "-fno-strict-aliasing",
        "-fno-common",
        "-D_GNU_SOURCE",
        "-fno-sanitize=undefined",
    });
    if (optimize != .Debug) {
        try c_flags.append("-Wp,-D_FORTIFY_SOURCE=2");
    }

    const config = b.addConfigHeader(.{}, .{
        .HAVE_STDINT_H = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_FCNTL_H = 1,
        .HAVE_UNISTD_H = 1,
        .HAVE_TIME_H = 1,
        .HAVE_LIBGEN_H = 1,
        .HAVE_SIGNAL_H = 1,
        .HAVE_SETJMP_H = 1,
        .HAVE_SYS_STAT_H = 1,
        .HAVE_UINT64_T = 1,
        .HAVE___UINT128_T = 1,
        .HAVE_ALARM = 1,
        .HAVE_CTIME_R = 1,
        .HAVE_LOCALTIME_R = 1,
        .HAVE_GMTIME_R = 1,
        .HAVE_GETLINE = 1,
        .HAVE_RAISE = 1,
        .HAVE_STRTOD_L = 1,
        .HAVE_CLOCK_GETTIME = 1,
        .HAVE_C11_ATOMIC_PRIMITIVES = 1,
        // 2 means variant 2 (see meson-cc-tests/mkdir-variant-2.c)
        // aka `int mkdir(const char *, mode_t)`
        .HAVE_MKDIR = 2,
        .SIZEOF_VOID_P = target.result.ptrBitWidth() / 8,
        .SIZEOF_INT = target.result.cTypeByteSize(.int),
        .SIZEOF_LONG = target.result.cTypeByteSize(.long),
        .SIZEOF_LONG_LONG = target.result.cTypeByteSize(.longlong),
        .SIZEOF_SIZE_T = target.result.ptrBitWidth() / 8,
    });

    if (target.result.os.tag == .windows)
        config.addValues(.{
            .HAVE_INTSAFE_H = 1,
        })
    else
        config.addValues(.{
            .HAVE_SYS_SOCKET_H = 1,
            .HAVE_POLL_H = 1,
            .HAVE_SYS_POLL_H = 1,
            .HAVE_SYS_UN_H = 1,
            .HAVE_SCHED_H = 1,
            .HAVE_SYS_MMAN_H = 1,
            .HAVE_SYS_IOCTL_H = 1,
            .HAVE_TERMIOS_H = 1,
            .HAVE_DRAND48 = 1,
            .HAVE_LINK = 1,
            .HAVE_FORK = 1,
            .HAVE_NEWLOCALE = 1,
            .HAVE_STRNDUP = 1,
            .HAVE_MMAP = 1,
        });

    if (target.result.os.tag == .linux or target.result.cpu.arch.isWasm())
        config.addValues(.{
            .HAVE_BYTESWAP_H = 1,
            .HAVE_FENV_H = 1,
            .HAVE_SYS_WAIT_H = 1,
            .HAVE_ALLOCA_H = 1,
            .HAVE_FLOCKFILE = 1,
            .HAVE_FUNLOCKFILE = 1,
            .HAVE_SCHED_GETAFFINITY = 1,
        });

    if (target.result.os.tag.isDarwin())
        config.addValues(.{ .HAVE_XLOCALE_H = 1 })
    else
        config.addValues(.{ .HAVE_IO_H = 1 });

    if (target.result.os.tag.isDarwin() or target.result.os.tag == .linux)
        config.addValues(.{ .HAVE_WAITPID = 1 });

    if (target.result.cpu.arch.endian() == .big)
        config.addValues(.{
            .WORDS_BIGENDIAN = 1,
            .FLOAT_WORDS_BIGENDIAN = 1,
        });

    const feature_config = b.addConfigHeader(.{ .include_path = "cairo-features.h" }, .{});

    lib.linkSystemLibrary("m");

    if (use_lzo) {
        lib.linkSystemLibrary("lzo2");
        config.addValues(.{ .HAVE_LZO = 1 });
    }

    if (use_dl) {
        lib.linkSystemLibrary("dl");
        config.addValues(.{ .CAIRO_HAS_DLSYM = 1 });
    }

    if (use_zlib) {
        if (b.systemIntegrationOption("zlib", .{}))
            lib.linkSystemLibrary("zlib")
        else {
            if (b.lazyDependency("zlib", .{
                .target = target,
                .optimize = optimize,
            })) |zlib| {
                lib.linkLibrary(zlib.artifact("z"));
            }
        }
        config.addValues(.{
            .HAVE_ZLIB = 1,
            .CAIRO_HAS_INTERPRETER = 1,
            .CAIRO_CAN_TEST_PS_SURFACE = 1,
        });
        feature_config.addValues(.{
            .CAIRO_HAS_PS_SURFACE = 1,
            .CAIRO_HAS_PDF_SURFACE = 1,
            .CAIRO_HAS_SCRIPT_SURFACE = 1,
        });

        lib.addCSourceFiles(.{
            .files = sources.script,
            .root = cairo.path("util/cairo-script"),
            .flags = c_flags.items,
        });
        lib.installHeadersDirectory(cairo.path("util/cairo-script"), "", .{});

        if (use_spectre) {
            lib.linkSystemLibrary("spectre");
            config.addValues(.{ .CAIRO_HAS_SPECTRE = 1 });
        }

        try cairo_sources.appendSlice(sources.script_surface);
        try test_sources.appendSlice(sources.script_tests);

        add_fallback_resolution = true;
        build_any2ppm = true;

        if (target.result.os.tag == .windows)
            try test_sources.append("pdf-structure.c");

        try boilerplate_sources.appendSlice(sources.script_boilerplate);
    }

    if (use_png) {
        if (b.systemIntegrationOption("libpng", .{}))
            lib.linkSystemLibrary("libpng")
        else if (b.lazyDependency("libpng", .{
            .target = target,
            .optimize = optimize,
        })) |png| {
            lib.linkLibrary(png.artifact("png"));
        }

        config.addValues(.{
            .CAIRO_CAN_TEST_SVG_SURFACE = 1,
        });
        feature_config.addValues(.{
            .CAIRO_HAS_SVG_SURFACE = 1,
            .CAIRO_HAS_PNG_FUNCTIONS = 1,
        });

        try cairo_sources.appendSlice(sources.png);

        try test_sources.appendSlice(sources.svg_tests);

        add_fallback_resolution = true;
        build_any2ppm = true;

        try boilerplate_sources.append("cairo-boilerplate-svg.c");
    }

    if (use_fontconfig or !(target.result.os.tag == .windows or target.result.os.tag.isDarwin())) {
        if (b.systemIntegrationOption("fontconfig", .{}))
            lib.linkSystemLibrary("fontconfig")
        else if (b.lazyDependency("fontconfig", .{
            .target = target,
            .optimize = optimize,
            .@"enable-libxml2" = false,
            .@"enable-libxml2-iconv" = false,
            // .@"enable-freetype" = use_freetype,
        })) |dep| {
            const fontconfig = dep.artifact("fontconfig");
            if (b.lazyDependency("expat", .{
                .target = target,
                .optimize = optimize,
            })) |expat|
                fontconfig.linkLibrary(expat.artifact("expat"));

            lib.linkLibrary(fontconfig);
            lib.installLibraryHeaders(fontconfig);
        }

        config.addValues(.{
            .HAVE_FCINIT = 1,
            .HAVE_FCFINI = 1,
        });
        feature_config.addValues(.{ .CAIRO_HAS_FC_FONT = 1 });
    }

    if (use_freetype or !(target.result.os.tag == .windows or target.result.os.tag.isDarwin())) {
        if (b.systemIntegrationOption("freetype", .{}))
            lib.linkSystemLibrary("freetype")
        else {
            if (b.lazyDependency("freetype", .{
                .target = target,
                .optimize = optimize,
                // .@"enable-libpng" = use_png,
            })) |dep| {
                const freetype = dep.artifact("freetype");
                lib.linkLibrary(freetype);
                lib.installLibraryHeaders(freetype);
            }

            feature_config.addValues(.{ .CAIRO_HAS_FT_FONT = 1 });
            config.addValues(.{
                .HAVE_FT_SVG_DOCUMENT = 1,
                .HAVE_FT_LOAD_NO_SVG = 1,
                .HAVE_FT_COLR_V1 = 1,
            });
        }

        if (use_png) {
            config.addValues(.{
                .HAVE_FT_SVG_DOCUMENT = 1,
            });
            if (use_ttx) {
                config.addValues(.{ .CAIRO_CAN_TEST_TTX_FONT = 1 });
            }
        }

        config.addValues(.{
            .HAVE_FT_LOAD_NO_SVG = 1,
            .HAVE_FT_COLR_V1 = 1,
        });

        try cairo_sources.appendSlice(sources.freetype);

        if (use_fontconfig) {
            try test_sources.appendSlice(sources.fontconfig);

            if (use_ttx)
                try test_sources.appendSlice(sources.ttx_tests);
        }
    }

    if (use_xlib) {
        lib.linkSystemLibrary("x11");
        lib.linkSystemLibrary("xext");
        // lib.linkSystemLibrary("xproto");
        feature_config.addValues(.{ .CAIRO_HAS_XLIB_SURFACE = 1 });

        config.addValues(.{
            .HAVE_X11_EXTENSIONS_XSHM_H = 1,
            .HAVE_X11_EXTENSIONS_SHMPROTO_H = 1,
            .HAVE_X11_EXTENSIONS_SHMSTR_H = 1,
            .HAVE_X11_XLIBINT_H = 1,
            .HAVE_X11_XPROTO_H = 1,
        });

        try cairo_sources.appendSlice(sources.xlib);

        try test_sources.appendSlice(sources.xlib_tests);

        try boilerplate_sources.append("cairo-boilerplate-xlib.c");

        if (use_xrender) {
            lib.linkSystemLibrary("xrender");

            config.addValues(.{
                .HAVE_XRENDERCREATESOLIDFILL = 1,
                .HAVE_XRENDERCREATELINEARGRADIENT = 1,
                .HAVE_XRENDERCREATERADIALGRADIENT = 1,
                .HAVE_XRENDERCREATECONICALGRADIENT = 1,
            });

            feature_config.addValues(.{ .CAIRO_HAS_XLIB_XRENDER_SURFACE = 1 });
        }
    }

    if (use_xcb) {
        lib.linkSystemLibrary("xcb");
        lib.linkSystemLibrary("xcb-render");
        lib.linkSystemLibrary("xcb-shm");
        feature_config.addValues(.{
            .CAIRO_HAS_XCB_SURFACE = 1,
            .CAIRO_HAS_XCB_SHM_FUNCTIONS = 1,
        });

        if (use_xlib) {
            lib.linkSystemLibrary("x11-xcb");
            try cairo_sources.append("cairo-xlib-xcb-surface.c");
            feature_config.addValues(.{ .CAIRO_HAS_XLIB_XCB_FUNCTIONS = 1 });
        }

        try cairo_sources.appendSlice(sources.xcb);

        try test_sources.append("xcb-surface-source.c");

        try boilerplate_sources.append("cairo-boilerplate-xcb.c");
    }

    if (target.result.os.tag.isDarwin() and use_quartz) {
        lib.linkFramework("CoreFoundation");
        lib.linkFramework("ApplicationServices");

        feature_config.addValues(.{
            .CAIRO_HAS_QUARTZ_SURFACE = 1,
            .CAIRO_HAS_QUARTZ_IMAGE_SURFACE = 1,
            .CAIRO_HAS_QUARTZ_FONT = 1,
        });

        try cairo_sources.appendSlice(sources.quartz);
        try test_sources.appendSlice(sources.quartz_tests);
        try boilerplate_sources.append("cairo-boilerplate-quartz.c");
    }

    if (target.result.os.tag == .windows) {
        try c_flags.appendSlice(&.{
            "-DWIN32_LEAN_AND_MEAN",
            "-DNOMINMAX",
        });

        lib.linkSystemLibrary("gdi32");
        lib.linkSystemLibrary("msimg32");

        feature_config.addValues(.{
            .CAIRO_HAS_WIN32_SURFACE = 1,
            .CAIRO_HAS_WIN32_FONT = 1,
        });

        if (use_dwrite) {
            lib.linkSystemLibrary("d2d1");
            lib.linkSystemLibrary("dwrite");
            lib.linkSystemLibrary("windowscodecs");

            feature_config.addValues(.{
                .CAIRO_HAS_DWRITE_FONT = 1,
                .HAVE_D2D1_3_H = 1,
            });

            // TODO: this assumes target is at least Windows 10
            try c_flags.appendSlice(&.{
                "-DWINVER=_WIN32_WINNT_WIN10",
                "-D_WIN32_WINNT=_WIN32_WINNT_WIN10",
                "-DNTDDI_VERSION=NTDDI_WIN10_RS3",
                "-DCAIRO_WIN32_STATIC_BUILD",
            });

            try cairo_sources.appendSlice(sources.win32);

            try boilerplate_sources.appendSlice(sources.win32_boilerplate);
        }
    }

    if (use_glib) {
        lib.linkSystemLibrary("gobject-2.0");
        lib.linkSystemLibrary("glib-2.0");
        feature_config.addValues(.{ .CAIRO_HAS_GOBJECT_FUNCTIONS = 1 });
    }

    if (symbol_lookup) {
        // lib.linkSystemLibrary("bfd");
        config.addValues(.{
            .HAVE_BFD = 1,
            .CAIRO_HAS_SYMBOL_LOOKUP = 1,
        });
    }

    if (b.systemIntegrationOption("pixman", .{})) {
        lib.linkSystemLibrary("pixman-1");
    } else if (b.lazyDependency("pixman", .{
        .target = target,
        .optimize = optimize,
    })) |dep| {
        const pixman = dep.artifact("pixman");
        pixman.root_module.sanitize_c = false;
        lib.linkLibrary(pixman);
        lib.installLibraryHeaders(pixman);
    }

    feature_config.addValues(.{ .CAIRO_HAS_IMAGE_SURFACE = 1 });
    config.addValues(.{ .HAS_PIXMAN_GLYPHS = 1 });

    feature_config.addValues(.{
        .CAIRO_HAS_USER_FONT = 1,
        .CAIRO_HAS_MIME_SURFACE = 1,
        .CAIRO_HAS_RECORDING_SURFACE = 1,
        .CAIRO_HAS_OBSERVER_SURFACE = 1,
    });

    if (use_tee) {
        feature_config.addValues(.{ .CAIRO_HAS_TEE_SURFACE = 1 });
        try cairo_sources.append("cairo-tee-surface.c");
    }

    lib.linkSystemLibrary("pthread");

    config.addValues(.{
        .CAIRO_HAS_PTHREAD = 1,
        .CAIRO_HAS_REAL_PTHREAD = 1,
    });

    try c_flags.appendSlice(&.{
        "-pthread",
        "-D_REENTRANT",
    });

    try test_sources.appendSlice(sources.pthread_tests);

    if (!target.result.cpu.arch.isX86())
        config.addValues(.{ .ATOMIC_OP_NEEDS_MEMORY_BARRIER = 1 });

    if ((target.result.os.tag == .linux or target.result.os.tag.isBSD() or target.result.os.tag.isDarwin()) and
        use_zlib and config.values.contains("CAIRO_HAS_REAL_PTHREAD") and use_dl)
        config.addValues(.{ .CAIRO_HAS_TRACE = 1 });

    if (add_fallback_resolution)
        try test_sources.appendSlice(sources.fallback_resolution_tests);

    lib.addConfigHeader(config);
    lib.addConfigHeader(feature_config);

    lib.addCSourceFiles(.{
        .root = cairo.path("src"),
        .files = try cairo_sources.toOwnedSlice(),
        .flags = c_flags.items,
    });

    lib.installHeadersDirectory(cairo.path("src"), "", .{});
    lib.installConfigHeader(config);
    lib.installConfigHeader(feature_config);

    b.installArtifact(lib);

    const cairomissing = b.addStaticLibrary(.{
        .name = "cairo-missing",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    cairomissing.addCSourceFiles(.{
        .files = &.{ "strndup.c", "getline.c" },
        .root = cairo.path("util/cairo-missing"),
    });
    cairomissing.installHeadersDirectory(cairo.path("util/cairo-missing"), "", .{});
    cairomissing.linkLibrary(lib);

    const cairoboilerplate = b.addStaticLibrary(.{
        .name = "cairoboilerplate",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    cairoboilerplate.addCSourceFiles(.{
        .files = boilerplate_sources.items,
        .root = cairo.path("boilerplate"),
    });
    cairoboilerplate.addIncludePath(cairo.path("boilerplate"));
    cairoboilerplate.linkLibrary(lib);
    cairoboilerplate.installHeadersDirectory(cairo.path("boilerplate"), "", .{});

    // TODO: don't litter the source directory
    const boilerplate_constructors = b.path("cairo-boilerplate-constructors.c");

    const python = try b.findProgram(&.{"python3"}, &.{});

    const make_boilerplate_constructors = b.addSystemCommand(try std.mem.concat(
        b.allocator,
        []const u8,
        &.{
            &.{ python, "make-cairo-boilerplate-constructors.py", boilerplate_constructors.getPath(b) },
            boilerplate_sources.items,
        },
    ));
    make_boilerplate_constructors.setCwd(cairo.path("boilerplate"));

    cairoboilerplate.step.dependOn(&make_boilerplate_constructors.step);
    cairoboilerplate.addCSourceFile(.{
        .file = boilerplate_constructors,
        .flags = c_flags.items,
    });

    if (build_tests) {
        if (build_any2ppm) {
            const any2ppm = b.addExecutable(.{
                .name = "any2ppm",
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            });

            any2ppm.addCSourceFile(.{ .file = cairo.path("test/any2ppm.c") });
            any2ppm.linkLibrary(lib);
            any2ppm.linkSystemLibrary("rsvg-2");

            any2ppm.step.dependOn(&lib.step);

            b.installArtifact(any2ppm);
        }

        const cairo_test_suite = b.addExecutable(.{
            .name = "cairo-test-suite",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        cairo_test_suite.addCSourceFiles(.{
            .files = test_sources.items,
            .root = cairo.path("test"),
            .flags = c_flags.items,
        });
        cairo_test_suite.addIncludePath(cairo.path("test"));
        cairo_test_suite.linkLibrary(lib);
        cairo_test_suite.linkLibrary(cairoboilerplate);
        cairo_test_suite.addCSourceFiles(.{
            .files = &.{
                "buffer-diff.c",
                "cairo-test.c",
                "cairo-test-runner.c",
            },
            .root = cairo.path("test"),
            .flags = c_flags.items,
        });

        // TODO: don't litter the source directory
        const test_constructors = b.path("cairo-test-constructors.c");

        const make_test_constructors = b.addSystemCommand(try std.mem.concat(
            b.allocator,
            []const u8,
            &.{
                &.{ python, "make-cairo-test-constructors.py", test_constructors.getPath(b) }, test_sources.items,
            },
        ));
        make_test_constructors.cwd = cairo.path("test");

        cairo_test_suite.step.dependOn(&make_test_constructors.step);
        cairo_test_suite.addCSourceFile(.{
            .file = test_constructors,
            .flags = c_flags.items,
        });

        b.installArtifact(cairo_test_suite);

        if (use_xlib and use_zlib) {
            const pdiff = b.addStaticLibrary(.{
                .name = "pdiff",
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            });

            pdiff.addCSourceFiles(.{
                .files = &.{
                    "lpyramid.c",
                    "pdiff.c",
                },
                .root = cairo.path("test/pdiff"),
            });
            pdiff.addIncludePath(cairo.path("test/pdiff"));
            pdiff.linkLibrary(lib);
            pdiff.installHeadersDirectory(cairo.path("test/pdiff"), "", .{});

            const cairo_test_trace = b.addExecutable(.{
                .name = "cairo-test-trace",
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            });

            cairo_test_trace.addCSourceFiles(.{
                .files = &.{
                    "cairo-test-trace.c",
                    "buffer-diff.c",
                },
                .root = cairo.path("test"),
                .flags = c_flags.items,
            });
            cairo_test_trace.addIncludePath(cairo.path("test"));
            cairo_test_trace.linkLibrary(lib);
            cairo_test_trace.linkLibrary(pdiff);
            cairo_test_trace.linkLibrary(cairoboilerplate);
            // cairo_test_trace.linkLibrary(cairoscript);
            cairo_test_trace.linkLibrary(cairomissing);

            cairo_test_suite.linkLibrary(pdiff);

            b.installArtifact(cairo_test_trace);
        }
    }
}
