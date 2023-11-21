with import <nixpkgs> {
  crossSystem = {
    config = "x86_64-unknown-linux-musl";
  };
};

mkShell {
  nativeBuildInputs = [];
  buildInputs = [ zlib openssl_3_1 gcc12 ];
}
