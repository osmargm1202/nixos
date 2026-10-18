{ runCommandCC, pam }:
runCommandCC "qylock-private-test-pam" { buildInputs = [ pam ]; } ''
  mkdir -p "$out/lib"
  $CC -Wall -Wextra -shared -fPIC ${./qylock-test-pam.c} -lpam \
    -o "$out/lib/qylock-test-pam.so"
''
