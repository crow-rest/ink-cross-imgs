with import <nixpkgs> {
  crossSystem = {
    config = "x86_64-unknown-linux-musl";
  };
};

mkShell {
  buildInputs = [ zlib ]; # your dependencies here
}
