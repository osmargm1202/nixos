{ pkgs, themeName, logo, background ? "0.0, 0.0, 0.0", logoScale ? 28 }:

pkgs.stdenv.mkDerivation {
  pname = "${themeName}-plymouth-theme";
  version = "1.0";
  src = logo;
  dontUnpack = true;
  installPhase = ''
    themeDir=$out/share/plymouth/themes/${themeName}
    mkdir -p $themeDir
    cp $src $themeDir/logo.png

    cat > $themeDir/${themeName}.script <<'SCRIPT'
// Simple centered logo theme. Keeps image ratio.
screen.w = Window.GetWidth(0);
screen.h = Window.GetHeight(0);
screen.half.w = screen.w / 2;
screen.half.h = screen.h / 2;

Window.SetBackgroundTopColor(${background});
Window.SetBackgroundBottomColor(${background});

logo.original = Image("logo.png");
logo.max.w = Math.Int(screen.w * ${toString logoScale} / 100);
logo.max.h = Math.Int(screen.h * ${toString logoScale} / 100);
logo.src.w = logo.original.GetWidth();
logo.src.h = logo.original.GetHeight();

if (logo.src.w * logo.max.h > logo.src.h * logo.max.w) {
  logo.w = logo.max.w;
  logo.h = Math.Int(logo.src.h * logo.max.w / logo.src.w);
} else {
  logo.h = logo.max.h;
  logo.w = Math.Int(logo.src.w * logo.max.h / logo.src.h);
}

logo.image = logo.original.Scale(logo.w, logo.h);
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(screen.half.w - logo.image.GetWidth() / 2);
logo.sprite.SetY(screen.half.h - logo.image.GetHeight() / 2);

message = null;
question = null;
answer = null;
bullets = null;
prompt = null;
bullet.image = Image.Text("*", 1, 1, 1);

fun DisplayQuestionCallback(promptText, entry) {
  question = null;
  answer = null;
  if (entry == "")
    entry = "<answer>";

  question.image = Image.Text(promptText, 1, 1, 1);
  question.sprite = Sprite(question.image);
  question.sprite.SetX(screen.half.w - question.image.GetWidth() / 2);
  question.sprite.SetY(screen.h - 4 * question.image.GetHeight());

  answer.image = Image.Text(entry, 1, 1, 1);
  answer.sprite = Sprite(answer.image);
  answer.sprite.SetX(screen.half.w - answer.image.GetWidth() / 2);
  answer.sprite.SetY(screen.h - 2 * answer.image.GetHeight());
}
Plymouth.SetDisplayQuestionFunction(DisplayQuestionCallback);

fun DisplayPasswordCallback(nil, bulletCount) {
  totalWidth = bulletCount * bullet.image.GetWidth();
  startPos = screen.half.w - totalWidth / 2;

  prompt.image = Image.Text("Enter Password", 1, 1, 1);
  prompt.sprite = Sprite(prompt.image);
  prompt.sprite.SetX(screen.half.w - prompt.image.GetWidth() / 2);
  prompt.sprite.SetY(screen.h - 4 * prompt.image.GetHeight());

  bullets = null;
  for (i = 0; i < bulletCount; i++) {
    bullets[i].sprite = Sprite(bullet.image);
    bullets[i].sprite.SetX(startPos + i * bullet.image.GetWidth());
    bullets[i].sprite.SetY(screen.h - 2 * bullet.image.GetHeight());
  }
}
Plymouth.SetDisplayPasswordFunction(DisplayPasswordCallback);

fun DisplayNormalCallback() {
  bullets = null;
  prompt = null;
  message = null;
  question = null;
  answer = null;
}
Plymouth.SetDisplayNormalFunction(DisplayNormalCallback);

fun MessageCallback(text) {
  message.image = Image.Text(text, 1, 1, 1);
  message.sprite = Sprite(message.image);
  message.sprite.SetPosition(screen.half.w - message.image.GetWidth() / 2, screen.h - 3 * message.image.GetHeight());
}
Plymouth.SetMessageFunction(MessageCallback);
SCRIPT

    cat > $themeDir/${themeName}.plymouth <<EOF
[Plymouth Theme]
Name=${themeName}
Description=Host logo Plymouth theme
ModuleName=script

[script]
ImageDir=$themeDir
ScriptFile=$themeDir/${themeName}.script
EOF
  '';
}
