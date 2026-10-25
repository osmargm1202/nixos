[
  {
    id = "home";
    type = "internal";
    name = "ORGM Home";
    workspace = "1";
    control = "internal";
    match = "(^| )orgm-home-home( |$)";
  }
  {
    id = "youtube";
    type = "flatpak";
    name = "YouTube";
    appId = "rocks.shy.VacuumTube";
    workspace = "2";
    control = "native";
    match = "VacuumTube";
    player = "VacuumTube";
  }
  {
    id = "spotify";
    type = "flatpak";
    name = "Spotify";
    appId = "com.spotify.Client";
    workspace = "3";
    control = "mpris";
    match = "spotify";
    player = "spotify";
  }
  {
    id = "netflix";
    type = "chrome";
    name = "Netflix";
    url = "https://www.netflix.com";
    workspace = "4";
    control = "keyboard";
    match = "orgm-home-netflix";
  }
  {
    id = "max";
    type = "chrome";
    name = "Max";
    url = "https://www.max.com";
    workspace = "5";
    control = "keyboard";
    match = "orgm-home-max";
  }
  {
    id = "crunchyroll";
    type = "chrome";
    name = "Crunchyroll";
    url = "https://www.crunchyroll.com";
    workspace = "6";
    control = "keyboard";
    match = "orgm-home-crunchyroll";
  }
  {
    id = "browser";
    type = "chrome";
    name = "Navegador";
    url = "about:blank";
    workspace = "7";
    control = "keyboard";
    match = "orgm-home-browser";
  }
  {
    id = "videos";
    type = "mpv";
    name = "Videos locales";
    workspace = "8";
    control = "mpv";
    match = "^mpv ";
  }
  {
    id = "poki";
    type = "chrome";
    name = "Poki";
    workspace = "9";
    url = "https://poki.com/es";
    match = "orgm-home-poki";
  }
  {
    id = "streameast";
    type = "chrome";
    name = "StreamEast";
    workspace = "10";
    url = "https://streameasto.cx/";
    match = "orgm-home-streameast";
  }
  {
    id = "nba";
    type = "chrome";
    name = "NBA";
    workspace = "11";
    url = "https://www.nba.com/watch";
    match = "orgm-home-nba";
  }
  {
    id = "retroarch";
    type = "flatpak";
    name = "RetroArch";
    workspace = "12";
    appId = "org.libretro.RetroArch";
    match = "(?i)retroarch";
    control = "native";
  }
  {
    id = "airplay";
    type = "airplay";
    name = "AirPlay";
    workspace = "14";
    url = "http://127.0.0.1:8765/airplay";
    match = "(?i)(uxplay|orgm-home-airplay)";
    control = "receiver";
  }
  {
    id = "kitty";
    type = "terminal";
    name = "Kitty";
    workspace = "15";
    match = "orgm-home-kitty";
    control = "terminal";
  }
  {
    id = "disney-plus";
    type = "chrome";
    name = "Disney+";
    workspace = "16";
    url = "https://www.disneyplus.com";
    match = "orgm-home-disney-plus";
  }
  {
    id = "prime-video";
    type = "chrome";
    name = "Prime Video";
    workspace = "17";
    url = "https://www.primevideo.com";
    match = "orgm-home-prime-video";
  }
  {
    id = "immich";
    type = "chrome";
    name = "Immich";
    workspace = "18";
    url = "https://fotos.or-gm.com";
    match = "orgm-home-immich";
  }
  {
    id = "claude";
    type = "chrome";
    name = "Claude";
    workspace = "19";
    url = "https://claude.ai";
    match = "orgm-home-claude";
  }
  {
    id = "chatgpt";
    type = "chrome";
    name = "ChatGPT";
    workspace = "20";
    url = "https://chatgpt.com";
    match = "orgm-home-chatgpt";
  }
  {
    id = "ubereats";
    type = "chrome";
    name = "Uber Eats";
    workspace = "21";
    url = "https://www.ubereats.com";
    match = "orgm-home-ubereats";
  }
  {
    id = "twitch";
    type = "chrome";
    name = "Twitch";
    workspace = "22";
    url = "https://www.twitch.tv";
    match = "orgm-home-twitch";
  }
  {
    id = "kick";
    type = "chrome";
    name = "Kick";
    workspace = "23";
    url = "https://kick.com";
    match = "orgm-home-kick";
  }
]
