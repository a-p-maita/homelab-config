#!/bin/zsh
# Scan audiobook m4b/mp3 files, create dirs for each audiobook, move files into dirs
# Have to check if mp3 are split into chapter parts and move them all in same dir

for file in ./*.m4b; do
  if [[ -f "$file" ]]; then
    dir="${file%.*}"
    mkdir -p "$dir"
    mv "$file" "$dir/"
  fi
done

for file in ./*.mp3; do
  if [[ -f "$file" ]]; then
    # Check if the filename contains " - Chapter " to identify chapter parts
    # Also check for other common chapter naming patterns like 01, part1
    if [[ "$file" == *" - Chapter "* ]] || [[ "$file" == *" - Part "* ]]; then
      # Extract the base name without the chapter part
      base="${file%% - Chapter *}"
      dir="${base%.*}"
    else
      dir="${file%.*}"
    fi
    mkdir -p "$dir"
    mv "$file" "$dir/"
  fi
done

# move any other files that are not m4b or mp3 into the same dir as the m4b/mp3 if they have the same base name
for file in ./*; do
  if [[ -f "$file" ]]; then
    base="${file%.*}"
    if [[ -d "$base" ]]; then
      mv "$file" "$base/"
    fi
  fi
done
