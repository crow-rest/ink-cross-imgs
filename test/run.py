import json
import os
import subprocess
import sys
import tomllib
import urllib.request
import misc


crates_io_api = "https://crates.io/api/v1/crates/{CRATE}"
crates_io_cdn = "https://static.crates.io/crates/{CRATE}/{CRATE}-{VERSION}.crate"

targets = [
    "aarch64-unknown-linux-gnu",
    "aarch64-unknown-linux-musl",
    "armv7-unknown-linux-gnueabihf",
    "armv7-unknown-linux-musleabihf",
    "powerpc64le-unknown-linux-gnu",
    "riscv64gc-unknown-linux-gnu",
    "s390x-unknown-linux-gnu",
    "x86_64-unknown-linux-gnu",
    "x86_64-unknown-linux-musl",
]


def main(filename):
    with open(f"./test/crates/{filename}", "rb") as file:
        crate_toml = tomllib.load(file)
        crate = crate_toml["info"]["id"]

    # Get from crates.io
    req = urllib.request.Request(
        crates_io_api.replace("{CRATE}", crate),
        data=None,
        headers={
            "User-Agent": f"crow-rest - ink images testing"
        }
    )
    res = urllib.request.urlopen(req)
    api = json.loads(res.read().decode("utf-8")) if res and res.status == 200 else sys.exit(3)

    v = api["versions"][0]
    version = v["num"]
    checksum = v["checksum"]

    subprocess.run(["wget", crates_io_cdn.replace("{CRATE}", crate).replace("{VERSION}", version)]).check_returncode()
    subprocess.run(["tar", "-xf", f"{crate}-{version}.crate"]).check_returncode()
    subprocess.run(["mv", f"{crate}-{version}", "./build"]).check_returncode()

    flags = misc.gen_flags(crate_toml)
    linux_flags = flags["linux"]
    final_linux_flags = "auditable build --verbose --release --locked "
    if linux_flags[0] is not None:
        final_linux_flags += f"--features '{linux_flags[0]}' "
    if linux_flags[1]:
        final_linux_flags += "--no-default-features "
    final_linux_flags += linux_flags[2]

    final_linux_flags = final_linux_flags.strip().split(" ")

    for t in targets:
        # Load image
        subprocess.run(["docker", "load", "-i", f"cross-{t}-amd64/cross-{t}-amd64.tar"]).check_returncode()

        try:
            sub = subprocess.run(["docker", "run", "--rm", "--pull=never", "-v", "./build:/project", f"cross:{t}"] + final_linux_flags)
        except:
            pass
        if "GITHUB_STEP_SUMMARY" in os.environ:
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f :
                print(f"{t}: {sub.returncode}", file=f)

        # Purge
        subprocess.run(["docker", "system", "prune", "--all", "--force"]).check_returncode()


if __name__ == "__main__":
    argv = sys.argv
    main(argv[1])
