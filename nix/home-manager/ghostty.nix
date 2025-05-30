{ pkgs }:
{
  enable = true;
  # currently i'm just installing this manually or building from source
  package = null;

  enableZshIntegration = true;
  enableBashIntegration = true;
  settings = {
    command = "${pkgs.zsh}/bin/zsh";

    keybind = [
      "clear"
      "super+alt+i=inspector:toggle"
      "super+minus=decrease_font_size:1"
      "super+equal=increase_font_size:1"
      "super+zero=reset_font_size"
      "super+c=copy_to_clipboard"
      "super+v=paste_from_clipboard"
      "super+n=new_window"
      "super+w=close_surface"
    ];

    font-family = "Hack";
    font-size = 12;
    font-thicken = true;
    adjust-cell-width = -1;

    window-padding-color = "background";
    window-padding-x = 3;
    window-padding-y = 2;

    theme = "GruvboxDarkHard";
    palette = [
      "0=#1d2021"
      "1=#fb4934"
      "2=#b8bb26"
      "3=#fabd2f"
      "4=#83a598"
      "5=#d3869b"
      "6=#8ec07c"
      "7=#d5c4a1"
      "8=#665c54"
      "9=#fb4934"
      "10=#b8bb26"
      "11=#fabd2f"
      "12=#83a598"
      "13=#d3869b"
      "14=#8ec07c"
      "15=#fbf1c7"
    ];
  };
}
