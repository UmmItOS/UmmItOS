#!/usr/bin/env bash
# The shell's picture converter (Super+I): img-convert.sh <format> <file or web link>...
# Writes each picture beside its original (a web picture goes to Downloads) and prints one line per picture:
#   ok<TAB>input<TAB>output   or   fail<TAB>input<TAB>reason

fmt=${1,,}
shift
case $fmt in
    png) coder=PNG ;;
    jpg) coder=JPEG ;;
    webp) coder=WEBP ;;
    avif) coder=AVIF ;;
    gif) coder=GIF ;;
    bmp) coder=BMP ;;
    tiff) coder=TIFF ;;
    ico) coder=ICO ;;
    *)
        echo "unknown format: $fmt" >&2
        exit 2
        ;;
esac

downloads=$(xdg-user-dir DOWNLOAD 2> /dev/null)
[[ -d $downloads ]] || downloads=$HOME/Downloads
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
    printf 'fail\t%s\t%s\n' "$1" "$2"
}

for src in "$@"; do
    case $src in
        http://* | https://*)
            name=${src%%[?#]*}
            name=${name##*/}
            [[ $name =~ ^[[:alnum:]._-]+$ ]] || name=picture
            in=$tmp/$name
            if ! curl -fsSL --proto =http,https --max-time 60 --max-filesize 104857600 -o "$in" -- "$src"; then
                fail "$src" "The download failed."
                continue
            fi
            dir=$downloads
            ;;
        /*)
            in=$src
            name=${src##*/}
            dir=${src%/*}
            ;;
        *)
            fail "$src" "It is not a file."
            continue
            ;;
    esac

    if [[ ! -f $in ]]; then
        fail "$src" "The file is gone."
        continue
    fi
    # The type from libmagic, which decodes nothing, and then only that decoder: ImageMagick also reads
    # scripts and vector formats that fetch other files, and would pick one from the content.
    case $(file -b --mime-type -- "$in") in
        image/png) kind=PNG ;;
        image/jpeg) kind=JPEG ;;
        image/webp) kind=WEBP ;;
        image/avif) kind=AVIF ;;
        image/heic | image/heif) kind=HEIC ;;
        image/gif) kind=GIF ;;
        image/bmp | image/x-ms-bmp) kind=BMP ;;
        image/tiff) kind=TIFF ;;
        image/vnd.microsoft.icon | image/x-icon) kind=ICO ;;
        image/jxl) kind=JXL ;;
        *)
            fail "$src" "It is not a picture."
            continue
            ;;
    esac
    [[ -w $dir ]] || dir=$downloads

    base=${name%.*}
    [[ -n $base ]] || base=picture
    out=$dir/$base.$fmt
    n=1
    while [[ -e $out ]]; do
        out=$dir/$base-$n.$fmt
        ((n++))
    done

    # Only GIF and WebP keep an animation; the rest take its first frame.
    opts=()
    frames=$in
    [[ $fmt == gif || $fmt == webp ]] || frames="${in}[0]"
    case $fmt in
        # JPEG has no transparency: flatten onto white rather than black.
        jpg) opts=(-background white -alpha remove -alpha off -quality 90) ;;
        # An icon holds at most 256 pixels a side.
        ico) opts=(-resize '256x256>') ;;
    esac

    if err=$(magick "$kind:$frames" "${opts[@]}" "$coder:$out" 2>&1); then
        printf 'ok\t%s\t%s\n' "$src" "$out"
    else
        rm -f "$out"
        fail "$src" "${err##*$'\n'}"
    fi
done
