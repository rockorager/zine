const zine = @This();
const std = @import("std");

// This file only contains definitions that are considered Zine's public
// interface. Zine's main build function is in another castle!
pub const build = @import("build/tools.zig").build;

pub const Site = struct {
    /// Title of the website
    title: []const u8,
    /// URL where the website will be hosted.
    /// It must not contain a subpath.
    host_url: []const u8,
    /// Set this value if your website is hosted under a subpath of `host_url`.
    ///
    /// `host_url` and `url_prefix_path` are split to allow the development
    /// server to generate correct relative paths when serving the website
    /// locally.
    url_path_prefix: []const u8 = "",
    /// If you want your site to be placed in a subdirectory of the output
    /// directory.
    /// Zig Build's output directory is `zig-out` by default, customizable
    /// by passing `-p path` to the build command invocation.
    output_path_prefix: []const u8 = "",
    layouts_dir_path: []const u8,
    content_dir_path: []const u8,
    assets_dir_path: []const u8,
    /// Subpaths in `assets_dir_path` that will be installed unconditionally.
    /// All other assets will be installed only if referenced by a content file
    /// or a layout by calling `$site.asset('foo').link()`.
    ///
    /// Examples of incorrect usage of this field:
    /// - site-wide CSS files (should be `link`ed by templates)
    /// - RSS feeds (should be generated by defining `alternative` pages)
    ///
    /// Examples of correct usage of this field:
    /// - `favicon.ico` and other similar assets auto-discovered by browsers
    /// - `CNAME` (used by GitHub Pages when you set a custom domain)
    static_assets: []const []const u8 = &.{},
    /// A list of build-time assets.
    ///
    /// For each entry the following values must be unique:
    ///   - `name`
    ///   - `install_path` (if set, unless `link`ing them is mutually exclusive)
    build_assets: []const BuildAsset = &.{},

    /// Enables Zine's -Ddebug and -Dscope flags
    /// (only useful if you're developing Zine)
    debug: bool = false,
};

pub const BuildAsset = struct {
    /// Name of this asset
    name: []const u8,
    /// LazyPath of the generated asset.
    ///
    /// The LazyPath cannot be generated by calling `b.path`.
    /// Use the 'assets' directory for non-buildtime assets.
    lp: std.Build.LazyPath,
    /// Installation path relative to the website's output path prefix.
    ///
    /// It is recommended to give the file an appropriate file extension.
    /// No need to specify this value if the asset is not meant to be
    /// `link()`ed
    install_path: ?[]const u8 = null,
    /// Installs the asset unconditionally when set to true.
    ///
    /// When set to false, the asset will be installed only if `link()`ed
    /// in a content file or layout (requires `install_path` to be set).
    install_always: bool = false,
};

pub const MultilingualSite = struct {
    /// URL where the website will be hosted.
    /// It must not contain a path other than `/`.
    host_url: []const u8,
    /// Directory that contains mappings from placeholders to translations,
    /// expressed as Ziggy files.
    ///
    /// Each Ziggy file must be named after the locale it's meant to offer
    /// translations for.
    i18n_dir_path: []const u8,
    layouts_dir_path: []const u8,
    assets_dir_path: []const u8,
    /// Subpaths in `assets_dir_path` that will be installed unconditionally.
    /// All other assets will be installed only if referenced by a content file
    /// or a layout by using `$site.asset('foo').link()`.
    ///
    /// Examples of incorrect usage of this field:
    /// - site-wide CSS files (should be `link`ed by templates)
    /// - RSS feeds (should be generated by defining `alternative` pages)
    ///
    /// Examples of correct usage of this field:
    /// - `favicon.ico` and other similar assets auto-discovered by browsers
    /// - `CNAME` (used by GitHub Pages when you set a custom domain)
    static_assets: []const []const u8 = &.{},
    /// A list of build-time assets.
    ///
    /// For each entry the following values must be unique:
    ///   - `name`
    ///   - `install_path` (if set, unless `link`ing them is mutually exclusive)
    build_assets: []const BuildAsset = &.{},
    /// A list of locales of this website.
    ///
    /// For each entry the following values must be unique:
    ///   - `code`
    ///   - `output_prefix_override` (if set) + `host_url_override`
    locales: []const Locale,

    /// Enables Zine's -Ddebug and -Dscope flags
    /// (only useful if you're developing Zine)
    debug: bool = false,
};

/// A localized variant of a multilingual website
pub const Locale = struct {
    /// A language-NATION code, e.g. 'en-US', used to identify each
    /// individual localized variant of the website.
    code: []const u8,
    /// A name that identifies this locale, e.g. 'English'
    name: []const u8,
    /// Content dir for this locale,
    content_dir_path: []const u8,
    /// Site title for this locale.
    site_title: []const u8,
    /// Set to a non-null value when deploying this locale from a dedicated
    /// host (e.g. 'https://us.site.com', 'http://de.site.com').
    ///
    /// It must not contain a subpath.
    host_url_override: ?[]const u8 = null,
    /// |  output_ |     host_     |     resulting    |    resulting    |
    /// |  prefix_ |      url_     |        url       |      path       |
    /// | override |   override    |      prefix      |     prefix      |
    /// | -------- | ------------- | ---------------- | --------------- |
    /// |   null   |      null     | site.com/en-US/  | zig-out/en-US/  |
    /// |   null   | "us.site.com" | us.site.com/     | zig-out/en-US/  |
    /// |   "foo"  |      null     | site.com/foo/    | zig-out/foo/    |
    /// |   "foo"  | "us.site.com" | us.site.com/foo/ | zig-out/foo/    |
    /// |    ""    |      null     | site.com/        | zig-out/        |
    ///
    /// The last case is how you create a default locale.
    output_prefix_override: ?[]const u8 = null,
};

/// Defines a default Zine project:
/// - Creates a 'website' step that will generate all the static content and
///   install it in the install prefix directory.
/// - Creates a 'serve' step that depends on 'website' and that also starts
///   Zine's development server on a default address (localhost:1990).
/// - Defines custom flags:
///   - `-Dport` to override the port used by the development server
/// - Sets other default Zine options
///
/// Look at the implementation of this function to see how you can use
/// `addWebsiteStep` and `addDevelopmentServerStep` for more fine-grained
/// control over the pipeline.
pub fn website(b: *std.Build, site: Site) void {
    // Setup debug flags if the user enabled Zine debug.
    const opts = zine.defaultZineOptions(b, site.debug);

    const website_step = b.step(
        "website",
        "Builds the website",
    );
    zine.addWebsite(b, opts, website_step, site);

    // Invoking the default step also builds the website
    b.getInstallStep().dependOn(website_step);

    const serve = b.step(
        "serve",
        "Starts the Zine development server",
    );

    const port = b.option(
        u16,
        "port",
        "port to listen on for the development server",
    ) orelse 1990;

    zine.addDevelopmentServer(b, opts, serve, .{
        .website_step = website_step,
        .host = "localhost",
        .port = port,
        .input_dirs = &.{
            site.layouts_dir_path,
            site.content_dir_path,
            site.assets_dir_path,
        },
    });
}

/// Defines a default multilingual Zine project:
/// - Creates a 'website' step that will generate all the static content and
///   install it in the prefix directory.
/// - Creates a 'serve' step that depends on 'website' and that also starts
///   Zine's development server on a default address (localhost:1990).
/// - Defines custom flags:
///   - `-Dport` to override the port used by the development server
/// - Sets other default Zine options
///
/// Look at the implementation of this function to see how you can use
/// `addMultilingualWebsiteStep` and `addDevelopmentServerStep` for more
/// fine-grained control over the pipeline.
pub fn multilingualWebsite(b: *std.Build, multi: MultilingualSite) void {
    // Setup debug flags if the user enabled Zine debug.
    const opts = zine.defaultZineOptions(b, multi.debug);

    const website_step = b.step(
        "website",
        "Builds the website",
    );
    zine.addMultilingualWebsite(b, website_step, multi, opts);

    // Invoking the default step also builds the website
    b.getInstallStep().dependOn(website_step);

    const serve = b.step(
        "serve",
        "Starts the Zine development server",
    );

    const port = b.option(
        u16,
        "port",
        "port to listen on for the development server",
    ) orelse 1990;

    var input_dirs = std.ArrayList([]const u8).init(b.allocator);
    input_dirs.appendSlice(&.{
        multi.layouts_dir_path,
        multi.assets_dir_path,
        multi.i18n_dir_path,
    }) catch unreachable;

    for (multi.locales) |v| {
        if (v.host_url_override) |_| {
            @panic("TODO: a variant specifies a dedicated host but multihost support for the dev server has not been implemented yet.");
        }
        input_dirs.append(v.content_dir_path) catch unreachable;
    }

    zine.addDevelopmentServer(b, opts, serve, .{
        .website_step = website_step,
        .host = "localhost",
        .port = port,
        .input_dirs = input_dirs.items,
    });
}

pub fn addWebsite(
    b: *std.Build,
    opts: ZineOptions,
    step: *std.Build.Step,
    site: Site,
) void {
    @import("build/content.zig").addWebsiteImpl(
        b,
        opts,
        step,
        .{ .site = site },
    );
}
pub fn addMultilingualWebsite(
    b: *std.Build,
    step: *std.Build.Step,
    multi: MultilingualSite,
    opts: ZineOptions,
) void {
    @import("build/content.zig").addWebsiteImpl(
        b,
        opts,
        step,
        .{ .multilingual = multi },
    );
}

pub const DevelopmentServerOptions = struct {
    website_step: *std.Build.Step,
    host: []const u8,
    port: u16 = 1990,
    input_dirs: []const []const u8,
};
pub fn addDevelopmentServer(
    b: *std.Build,
    zine_opts: ZineOptions,
    step: *std.Build.Step,
    server_opts: DevelopmentServerOptions,
) void {
    const zine_dep = b.dependencyFromBuildZig(zine, .{
        .optimize = zine_opts.optimize,
        .scope = zine_opts.scopes,
    });

    const server_exe = zine_dep.artifact("server");
    const run_server = b.addRunArtifact(server_exe);
    run_server.addArg(b.graph.zig_exe); // #1
    run_server.addArg(b.install_path); // #2
    run_server.addArg(b.fmt("{d}", .{server_opts.port})); // #3
    run_server.addArg(server_opts.website_step.name); // #4
    run_server.addArg(@tagName(zine_opts.optimize)); // #5

    for (server_opts.input_dirs) |dir| {
        run_server.addArg(dir); // #6..
    }

    if (server_opts.website_step.id != .top_level) {
        std.debug.print("Website step given to 'addDevelopmentServer' needs to be a top-level step (created via b.step()) because the server executable needs to be able to invoke it to rebuild the website on file change.\n\n", .{});

        std.process.exit(1);
    }

    run_server.step.dependOn(server_opts.website_step);
    step.dependOn(&run_server.step);
}

pub const ZineOptions = struct {
    optimize: std.builtin.OptimizeMode = .ReleaseFast,
    /// Logging scopes to enable, useful when
    /// building in debug mode to develop Zine.
    scopes: []const []const u8 = &.{},
};
fn defaultZineOptions(b: *std.Build, debug: bool) ZineOptions {
    var flags: ZineOptions = .{};
    if (debug) {
        flags.optimize = if (b.option(
            bool,
            "debug",
            "build Zine tools in debug mode",
        ) orelse false) .Debug else .ReleaseFast;
        flags.scopes = b.option(
            []const []const u8,
            "scope",
            "logging scopes to enable",
        ) orelse &.{};
    }
    return flags;
}

pub fn scriptyReferenceDocs(
    project: *std.Build,
    shtml_output_file_path: []const u8,
    smd_output_file_path: []const u8,
) void {
    const zine_dep = project.dependencyFromBuildZig(
        zine,
        .{ .optimize = .Debug },
    );

    const run_step = project.step(
        "docgen",
        "Regenerates Scripty reference docs",
    );

    {
        const run_docgen = project.addRunArtifact(
            zine_dep.artifact("shtml_docgen"),
        );

        const reference_md = run_docgen.addOutputFileArg(
            "shtml_scripty_reference.md",
        );

        const wf = project.addWriteFiles();
        wf.addCopyFileToSource(reference_md, shtml_output_file_path);

        run_step.dependOn(&wf.step);
    }
    {
        const run_docgen = project.addRunArtifact(
            zine_dep.artifact("smd_docgen"),
        );

        const reference_md = run_docgen.addOutputFileArg(
            "smd_scripty_reference.md",
        );

        const wf = project.addWriteFiles();
        wf.addCopyFileToSource(reference_md, smd_output_file_path);

        run_step.dependOn(&wf.step);
    }
}
