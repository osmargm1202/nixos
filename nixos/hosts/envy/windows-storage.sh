# Called by an explicitly declared root service, never by the VM as privileged.
set -euo pipefail
root="$1" uid="$2" gid="$3"
[[ "$root" = /* && "$root" != / && "$root" != *'/../'* ]] || exit 1
parent="$root"
while [[ "$parent" != / ]]; do
  [[ ! -L "$parent" ]] || { echo 'Envy Windows: preserved storage directory link' >&2; exit 1; }
  parent="$(dirname "$parent")"
done
read -r label fstype fsroot target < <(findmnt -nro LABEL,FSTYPE,FSROOT,TARGET --target "$root")
[[ "$label" == ENVY_ROOT && "$fstype" == btrfs && "$fsroot" == /@windows && "$target" == "$root" ]] || {
  echo 'Envy Windows: storage must be the mounted ENVY_ROOT/@windows subvolume' >&2; exit 1;
}
for child in storage shared oem; do
  [[ ! -L "$root/$child" ]] || { echo 'Envy Windows: preserved storage directory link' >&2; exit 1; }
done
if [[ -d "$root/storage" ]]; then
  flags="$(lsattr -d -- "$root/storage")"
  if [[ "${flags%% *}" != *C* ]] && [[ -n "$(find "$root/storage" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo 'Envy Windows: existing data is not NoCoW; manual migration required, nothing converted' >&2
    exit 1
  fi
fi
if [[ -d "$root/storage" ]]; then
  while IFS= read -r -d "" image; do
    flags="$(lsattr -d -- "$image")"
    [[ "${flags%% *}" == *C* ]] || {
      echo 'Envy Windows: existing guest image is not NoCoW; manual migration required, nothing converted' >&2
      exit 1
    }
  done < <(find "$root/storage" -type f \( -iname '*.img' -o -iname '*.raw' -o -iname '*.qcow' -o -iname '*.qcow2' -o -iname '*.vhd' -o -iname '*.vhdx' -o -iname '*.vmdk' -o -iname '*.vdi' \) -print0)
fi
install -d -m0700 -o "$uid" -g "$gid" "$root/storage" "$root/shared" "$root/oem"
chattr +C -- "$root/storage"
