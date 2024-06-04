{ pkgs, shell, wsl }:
{
  enable = true;
  package = (if !wsl then pkgs.alacritty else pkgs.hello);
  settings = {
    live_config_reload = true;

    bell = {
      animation = "EaseOutExpo";
      command = "None";
      duration = 0;
    };

    colors = {
      primary = {
        background = "0x1d2021";
        foreground = "0xd5c4a1";
      };
      cursor = {
        text = "0x1d2021";
        cursor = "0xd5c4a1";
      };
      normal = {
        black = "0x1d2021";
        red = "0xfb4934";
        green = "0xb8bb26";
        yellow = "0xfabd2f";
        blue = "0x83a598";
        magenta = "0xd3869b";
        cyan = "0x8ec07c";
        white = "0xd5c4a1";
      };
      bright = {
        black = "0x665c54";
        red = "0xfb4934";
        green = "0xb8bb26";
        yellow = "0xfabd2f";
        blue = "0x83a598";
        magenta = "0xd3869b";
        cyan = "0x8ec07c";
        white = "0xfbf1c7";
      };
    };

    # colors =
    #   let
    #     dark = (builtins.fromTOML
    #       (builtins.readFile "${pkgs.alacritty-theme}/gruvbox_dark.toml")).colors;
    #     material_dark = (builtins.fromTOML
    #       (builtins.readFile "${pkgs.alacritty-theme}/gruvbox_material_hard_dark.toml")).colors;
    #
    #   in
    #   {
    #     primary = material_dark.primary;
    #     normal = dark.bright;
    #     bright = dark.bright;
    #   };

    cursor = {
      style = "Block";
      unfocused_hollow = true;
    };

    debug = {
      persistent_logging = false;
      render_timer = false;
    };

    env = {
      TERM = "alacritty-direct";
    };

    font = {
      # TODO: pkgs.hack-font
      # share/fonts/truetype/Hack-Regular.ttf
      # share/fonts/truetype/Hack-BoldItalic.ttf
      # ...
      size = 12.0;
      bold = { family = "Hack"; style = "Bold"; };
      bold_italic = { family = "Hack"; style = "Bold Italic"; };
      glyph_offset = { x = 0; y = 0; };
      italic = { family = "Hack"; style = "Italic"; };
      normal = { family = "Hack"; style = "Regular"; };
      offset = { x = 0; y = 0; };
    };

    keyboard.bindings = [
      {
        chars = "\\u0011";
        key = "Q";
        mods = "Control";
      }
      {
        action = "ReceiveChar";
        key = "L";
        mods = "Control";
      }
    ];

    mouse = {
      hide_when_typing = true;
      bindings = [
        {
          action = "PasteSelection";
          mouse = "Middle";
        }
      ];
    };

    scrolling = {
      history = 0;
    };

    shell = {
      args = (if !wsl then [ "--login" ] else [ ]);
      # cp alacritty/alacritty.toml /mnt/c/Users/ehden/AppData/Roaming/alacritty
      program = (if !wsl then shell else "C:\\\\Windows\\\\System32\\\\wsl.exe");
    };

    window = {
      decorations = "full";
      dynamic_padding = false;
      dynamic_title = true;
      opacity = 1.0;
      startup_mode = "Windowed";
      padding = {
        x = 2;
        y = 2;
      };
    };
  };
}
