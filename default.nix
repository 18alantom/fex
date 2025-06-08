{
  stdenv,
  fetchFromGitHub,
  zig,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "fex";
  version = "v0.1.1";

  src = fetchFromGitHub {
    owner = "18alantom";
    repo = finalAttrs.pname;
    rev = finalAttrs.version;
    hash = "sha256-9DY+q3ucJC13oSUdj2cp40P4IeFLxCOU03h/jgjmoaU=";
  };

  nativeBuildInputs = [ zig.hook ];
})
