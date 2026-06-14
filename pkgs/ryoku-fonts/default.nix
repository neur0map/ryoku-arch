# Icon fonts the Ryoku shell references that nixpkgs does not package. The
# dashboard icon map (shell/dashboard/modules/theme/Icons.qml) renders with
# "Phosphor-Bold"; without that family the dashboard transport and widget glyphs
# fall back to tofu boxes. The TTF is fetched per-file from the MIT-licensed
# upstream so no font blob lives in the repo.
{
  stdenvNoCC,
  fetchurl,
}:
let
  phosphorBold = fetchurl {
    url = "https://github.com/phosphor-icons/web/raw/v2.1.2/src/bold/Phosphor-Bold.ttf";
    hash = "sha256-EKChy0+BVqQg+fhM80xOmHHljtLd6h9qgHmtByQ6f7I=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "ryoku-fonts";
  version = "2.1.2";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 ${phosphorBold} "$out/share/fonts/truetype/Phosphor-Bold.ttf"
    runHook postInstall
  '';

  meta = {
    description = "Non-nixpkgs icon fonts the Ryoku shell renders (Phosphor-Bold)";
  };
}
