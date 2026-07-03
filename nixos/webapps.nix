{
  config,
  lib,
  userName ? "osmarg",
  ...
}:

let
  mkApp =
    {
      name,
      url,
      icon,
      comment ? "${name} Web Application",
      categories,
      wmClass,
    }:
    {
      inherit name;
      exec = ''chromium --app="${url}" --class="${wmClass}" --new-window'';
      inherit icon comment categories;
      settings = {
        StartupNotify = "true";
        StartupWMClass = wmClass;
      };
    };

  multimediaApps = {
    youtube = mkApp {
      name = "Youtube";
      url = "https://youtube.com";
      icon = "youtube-webapp";
      categories = [ "AudioVideo" ];
      wmClass = "chrome-youtube.com__-Default";
    };
    youtube-kids = mkApp {
      name = "YoutubeKids";
      url = "https://youtubekids.com";
      icon = "youtube-kids";
      categories = [ "AudioVideo" ];
      wmClass = "chrome-youtubekids.com__-Default";
    };
    netflix = mkApp {
      name = "Netflix";
      url = "https://netflix.com";
      icon = "netflix";
      categories = [ "AudioVideo" ];
      wmClass = "chrome-netflix.com__-Default";
    };
    hbo-max = mkApp {
      name = "HBO MAX";
      url = "https://hbomax.com";
      icon = "video-television";
      categories = [ "AudioVideo" ];
      wmClass = "chrome-hbomax.com__-Default";
    };
    crunchyroll = mkApp {
      name = "crunchyroll";
      url = "https://www.crunchyroll.com/";
      icon = "crunchyroll";
      comment = "Crunchyroll webapp Anime";
      categories = [ "AudioVideo" ];
      wmClass = "chrome-www.crunchyroll.com__-Default";
    };
  };

  gamingApps = {
    poki = mkApp {
      name = "Poki";
      url = "https://poki.com";
      icon = "poki";
      comment = "Poki Game App";
      categories = [ "Game" ];
      wmClass = "chrome-poki.com__-Default";
    };
  };

  officeApps = {
    gmail = mkApp {
      name = "Gmail";
      url = "https://gmail.com";
      icon = "gmail";
      categories = [
        "Network"
        "WebBrowser"
      ];
      wmClass = "chrome-gmail.com__-Default";
    };
    outlook = mkApp {
      name = "Outlook - Hotmail";
      url = "https://outlook.office.com/";
      icon = "outlook-hotmail";
      categories = [ "Office" ];
      wmClass = "chrome-outlook.office.com__-Default";
    };
    microsoft-teams = mkApp {
      name = "Microsoft Teams";
      url = "https://teams.microsoft.com/";
      icon = "microsoft-teams";
      categories = [ "Office" ];
      wmClass = "chrome-teams.microsoft.com__-Default";
    };
    whatsapp = mkApp {
      name = "Whatsapp";
      url = "https://web.whatsapp.com/";
      icon = "whatsapp";
      categories = [
        "Network"
        "WebBrowser"
      ];
      wmClass = "chrome-web.whatsapp.com__-Default";
    };
    cloud-orgm = mkApp {
      name = "Cloud ORGM";
      url = "https://cloud.or-gm.com/";
      icon = "applications-internet";
      comment = "Cloud ORGM Web Application";
      categories = [ "Office" ];
      wmClass = "chrome-cloud.or-gm.com__-Default";
    };
    webui = mkApp {
      name = "WebUi";
      url = "https://chat.or-gm.com";
      icon = "webui";
      comment = "ORGM OpenWebUI";
      categories = [ "Development" ];
      wmClass = "chrome-chat.or-gm.com__-Default";
    };
    banco-popular = mkApp {
      name = "Banco Popular";
      url = "https://ib.bpd.com.do";
      icon = "banco-popular";
      comment = "Internet Banking Banco Popular";
      categories = [ "Office" ];
      wmClass = "chrome-ib.bpd.com.do__-Default";
    };
  };

  devApps = {
    github = mkApp {
      name = "Github";
      url = "https://github.com/osmargm1202";
      icon = "github-webapp";
      comment = "osmargm1202 Github App";
      categories = [ "Development" ];
      wmClass = "chrome-github.com__-Default";
    };
    google-cloud = mkApp {
      name = "Google Cloud Console";
      url = "https://console.cloud.google.com";
      icon = "google-cloud-console";
      categories = [ "Utility" ];
      wmClass = "chrome-console.cloud.google.com__-Default";
    };
    neon = mkApp {
      name = "Neon";
      url = "https://console.neon.tech/";
      icon = "neon-db";
      comment = "Neon Postgresql Database App";
      categories = [
        "Network"
        "WebBrowser"
      ];
      wmClass = "chrome-console.neon.tech__-Default";
    };
    rollbar = mkApp {
      name = "Rollbar";
      url = "https://app.rollbar.com/";
      icon = "rollbar";
      categories = [ "Development" ];
      wmClass = "chrome-app.rollbar.com__-Default";
    };
    google-ai-studio = mkApp {
      name = "Google AI Studio";
      url = "https://aistudio.google.com/";
      icon = "google-ai-studio";
      categories = [ "Development" ];
      wmClass = "chrome-aistudio.google.com__-Default";
    };
    excalidraw = mkApp {
      name = "Excalid Draw Diagramas";
      url = "https://excalidraw.com/";
      icon = "excalidraw";
      comment = "Excalid Draw Web App";
      categories = [ "Office" ];
      wmClass = "chrome-excalidraw.com__-Default";
    };
    fast = mkApp {
      name = "Fast";
      url = "https://fast.com";
      icon = "fast";
      categories = [ "Development" ];
      wmClass = "chrome-fast.com__-Default";
    };
    windows-docker = mkApp {
      name = "Windows Docker";
      url = "http://127.0.0.1:8006";
      icon = "windows-docker";
      comment = "Windows VM";
      categories = [ "Development" ];
      wmClass = "chrome-127.0.0.1_8006__-Default";
    };
    claude = mkApp {
      name = "Claude";
      url = "https://claude.ai";
      icon = "claude-webapp";
      categories = [ "Development" ];
      wmClass = "chrome-claude.ai__-Default";
    };
    chatgpt = mkApp {
      name = "Chatgpt";
      url = "https://chatgpt.com";
      icon = "chatgpt";
      categories = [ "Development" ];
      wmClass = "chrome-chatgpt.com__-Default";
    };
  };

  socialApps = {
    facebook = mkApp {
      name = "Facebook";
      url = "https://facebook.com";
      icon = "facebook";
      categories = [
        "Network"
        "WebBrowser"
      ];
      wmClass = "chrome-facebook.com__-Default";
    };
    instagram = mkApp {
      name = "Instagram";
      url = "https://instagram.com";
      icon = "instagram";
      categories = [
        "Network"
        "WebBrowser"
      ];
      wmClass = "chrome-instagram.com__-Default";
    };
    ubereats = mkApp {
      name = "UberEats";
      url = "https://www.ubereats.com/";
      icon = "ubereats";
      categories = [ "Utility" ];
      wmClass = "chrome-www.ubereats.com__-Default";
    };
  };
in
{
  options.orgm.webapps = {
    multimedia = lib.mkEnableOption "multimedia web apps (Youtube, Netflix, HBO MAX, Crunchyroll)";
    gaming = lib.mkEnableOption "gaming web apps (Poki)";
    office = lib.mkEnableOption "office web apps (Gmail, Outlook, Teams, Whatsapp, Cloud ORGM)";
    dev = lib.mkEnableOption "dev web apps (Github, Google Cloud, Neon, Claude, ChatGPT)";
    social = lib.mkEnableOption "social web apps (Facebook, Instagram, UberEats)";
  };

  config = {
    home-manager.users.${userName} =
      { lib, ... }:
      {
        xdg.desktopEntries = lib.mkMerge [
          (lib.mkIf config.orgm.webapps.multimedia multimediaApps)
          (lib.mkIf config.orgm.webapps.gaming gamingApps)
          (lib.mkIf config.orgm.webapps.office officeApps)
          (lib.mkIf config.orgm.webapps.dev devApps)
          (lib.mkIf config.orgm.webapps.social socialApps)
        ];
      };
  };
}
