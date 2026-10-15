# Keep the immutable source aligned with collectLayerFiles, without consulting
# Git or importing a derivation. Obsolete roots (notably shared/) have no consumer.
let
  isMetadata = name:
    builtins.elem name [
      ".git"
      ".gitignore"
      ".DS_Store"
      "icon-theme.cache"
      "mimeinfo.cache"
      "__pycache__"
    ]
    || builtins.match "Icon." name != null
    || builtins.match ".*(~|[.]bak)" name != null;

  # Git exports omit empty directories; also prune directories whose only
  # descendants are metadata. Never follow symlinks while inspecting a tree.
  hasFiles = directory:
    let entries = builtins.readDir directory;
    in builtins.any (name:
      !isMetadata name && (
        if entries.${name} == "directory" then hasFiles (directory + "/" + name)
        else builtins.elem entries.${name} [ "regular" "symlink" ]
      )
    ) (builtins.attrNames entries);
in
{
  inherit isMetadata;
  source = root:
    let rootString = toString root;
    in builtins.path {
      path = root;
      name = "user-dotfiles";
      filter = path: type:
        if toString path == rootString then true
        else
          let
            relative = builtins.substring (builtins.stringLength rootString + 1) (-1) (toString path);
            topLevel = builtins.head (builtins.match "([^/]+)(/.*)?" relative);
          in
          builtins.elem topLevel [ "programs" "profiles" "users" "hosts" ]
          && !isMetadata (builtins.baseNameOf path)
          && (if type == "directory" then hasFiles (toString path)
              else builtins.elem type [ "regular" "symlink" ]);
    };
}
