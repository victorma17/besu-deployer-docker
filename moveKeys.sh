#!/bin/bash

# Path to folders
KEYS_DIR="./networkFiles/keys"
NODO_BASE="Node"

# Node counter (starting in 1 → Node-1)
i=1
# sort the directories in KEYS_DIR and iterate through them
for address_dir in $(ls "$KEYS_DIR" | sort); do
  src="$KEYS_DIR/$address_dir"
  dest="$NODO_BASE-$i/data"

  if [[ -d "$src" && -d "$dest" ]]; then
    echo "Moving keys from $address_dir → $dest"
    cp "$src/key" "$dest/"
    cp "$src/key.pub" "$dest/"
  else
    echo "Folder unmatched: $src o $dest"
  fi

  i=$((i + 1))
done
