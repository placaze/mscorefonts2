#!/bin/sh

# Download the Microsoft Core Fonts for the WEB from third party websites.
# Install to Unix X Windows.
#
# (C) 2012 Rob Janes.
#
# You may freely distribute this file under the terms of the
# GNU General Public License, version 2 or later.

${TraceF-}

usage() {
  cat <<EOF
Download the Microsoft Core Fonts for the WEB from third party websites.
Install to Unix X Windows.

Usage: ${0##*/} [ OPTIONS ]
  -q     : quiet
  -v     : verbose
  -k     : don't cleanup the temp directory
  -d DIRECTORY      : download only, do not install
  -F DIRECTORY      : install to this directory
          either -d or -F must be given.
  -L LICENSE_FILE   : filename to store the microsoft license
          default is to NOT save the license.
  -N NAME           : basename for temp directory
          default is this command name.
  -S CHECK_FILE     : file with list of sha256sums for downloaded files
          default is cabfiles.sha256sums in COMMAND_DIR
  -I INSTALLED_LIST : file to save list of installed files
          default is installed-list.txt in COMMAND_DIR
EOF
}

function progress {
  [ "$QUIET_FLAG" ] || echo "### $*" >&2
}

function error {
  echo "Error: $*" >&2
}

function warning {
  echo "Warning: $*" >&2
}

function check_file {
  local file="$1"
  local stored_checksum
  local variable_name

  if [ ! -e "$file" ] || [ ! -f "$file" ] || [ ! -s "$file" ]; then
    return 1
  fi

  if [ -z "$CABFILES_SHA256SUMS" ]; then
    variable_name=`basename "$file" | sed -e 's/\..*$//'`_md5
    eval stored_checksum=\$$variable_name
    [ -z "$stored_checksum" ] && warning "no md5 checksum for $file"
    computed_checksum=`md5sum < "$file" | cut -f1 -d" "`
  else
    stored_checksum=`grep -i "\`basename $file\`\$" $CABFILES_SHA256SUMS | cut -f1 -d" "`
    [ -z "$stored_checksum" ] && warning "no sha256 checksum found for $file in $CABFILES_SHA256SUMS"
    computed_checksum=`sha256sum < "$file" | cut -f1 -d" "`
  fi

  if [ -z "$stored_checksum" ]; then
    error "verification checksum not stored for $file"
    return 9
  elif [ "$stored_checksum" = "$computed_checksum" ]; then
    return 0
  else
    error "verification checksum for $file does not match: should be $stored_checksum, is $computed_checksum"
    return 9
  fi
}

function download_file {
  local mirror="$1" file="$2"
  if type wget > /dev/null 2>&1; then
    wget ${VERBOSE_FLAG:---no-verbose} --timeout=5 -O $file $mirror/$file
  elif type curl > /dev/null 2>&1; then
    curl ${VERBOSE_FLAG:--s -S} -R -L -o "$file" --connect-timeout 5 "$mirror/$file"
  fi
}

function list_cab_contents {
  local name="$1" cab="$2"
  [ -z "$cab" ] && cab="$name"

  cabextract --lowercase -l -F '*.ttf' "$cab" |
    awk '/^  *[0-9][0-9]* / {sub(/^.*\|  */, ""); sub(/  *$/, ""); print}; {next}' |
    while read ttf_file_name xxx
    do
      sha=`sha256sum $FONTDIR/$ttf_file_name | sed -e 's/ .*$//'`
      echo "$sha $name $ttf_file_name"
    done
}

EXITCODE=
while getopts :d:kqvF:N:L:S:I: op
do
  case "$op" in
  d) DOWNLOAD_ONLY_FLAG=1; KEEP_TMP_FLAG=1; FONTDIR=`realpath "$OPTARG"`;;
  k) KEEP_TMP_FLAG=1 ;;
  q) QUIET_FLAG=1 ;;
  v) VERBOSE_FLAG=1 ;;
  F) FONTDIR="$OPTARG" ;;
  L) LICENSE_FILE="$OPTARG" ;;
  S) CABFILES_SHA256SUMS="$OPTARG" ;;
  I) INSTALLED_LIST="$OPTARG" ;;
  N) NAME="$OPTARG" ;;
  :)
    case "$OPTARG" in
    \?) usage; EXITCODE=0 ;;
    *) error "invalid option $OPTARG"; usage >&2; EXITCODE=1 ;;
    esac
    ;;
  esac
done

[ -n "$EXITCODE" ] && exit $EXITCODE

COMMAND=`realpath $0`
COMMAND_DIR=`dirname $COMMAND`

shift `expr $OPTIND - 1`

[ -z "$NAME" ] && NAME=`basename $0 .sh`

if [ -n "$DOWNLOAD_ONLY_FLAG" ]; then
  TMP="$FONTDIR"
  [ "${INSTALLED_LIST-unset}" = unset ] && INSTALLED_LIST=$FONTDIR/downloaded-list.txt
else
  TMP=`mktemp -t -d ${NAME}-XXXXXX`
  [ "${INSTALLED_LIST-unset}" = unset ] && INSTALLED_LIST=$COMMAND_DIR/installed-list.txt
fi

[ "${CABFILES_SHA256SUMS-unset}" = unset ] && CABFILES_SHA256SUMS=$COMMAND_DIR/cabfiles.sha256sums
if [ -n "$CABFILES_SHA256SUMS" -a ! -f "$CABFILES_SHA256SUMS" ]; then
  warning "sha256sums for cabfiles not found: $CABFILES_SHA256SUMS"
  CABFILES_SHA256SUMS=
fi

if [ -z "$FONTDIR" ]; then
  error "Please specify a directory to install the fonts to, for example /usr/share/fonts/msttcore/"
  usage >&2
  exit 2
fi

if [ ! -d "$FONTDIR" ]; then
  mkdir -p "$FONTDIR" || {
    error "Font directory $FONTDIR does not exist and could not be created."
    exit 2
  }
fi

# setup trap to run on exit from this script
if [ -z "$KEEP_TMP_FLAG" ]; then
  trap '[ -d "${TMP:-nonexistantdirectory}" ] && {
cd /;
echo "### Removing tmp directory ${TMP:-nonexistantdirectory}" >&2;
rm -rf "${TMP:-nonexistantdirectory}";
}' 0
else
  trap '[ -d "${TMP:-nonexistantdirectory}" ] && {
echo "### Downloaded files are in directory ${TMP:-nonexistantdirectory}" >&2;
}' 0
fi

# create the temp directory to download cabs to
mkdir -p $TMP/downloads
chmod 0755 $TMP
cd $TMP/downloads

progress "Using tmp directory $TMP"

mirror=http://downloads.sourceforge.net/corefonts
mirror_update=http://downloads.sourceforge.net/mscorefonts2

andale32_md5="cbdc2fdd7d2ed0832795e86a8b9ee19a"
arial32_md5="9637df0e91703179f0723ec095a36cb5"
arialb32_md5="c9089ae0c3b3d0d8c4b0a95979bb9ff0"
comic32_md5="2b30de40bb5e803a0452c7715fc835d1"
courie32_md5="4e412c772294403ab62fb2d247d85c60"
georgi32_md5="4d90016026e2da447593b41a8d8fa8bd"
impact32_md5="7907c7dd6684e9bade91cff82683d9d7"
times32_md5="ed39c8ef91b9fb80f76f702568291bd5"
trebuc32_md5="0d7ea16cac6261f8513a061fbfcdb2b5"
webdin32_md5="230a1d13a365b22815f502eb24d9149b"
verdan32_md5="12d2a75f8156e10607be1eaa8e8ef120"
wd97vwr32_md5="efa72d3ed0120a07326ce02f051e9b42"
EUupdate_md5="79d4277864cee0269af46c78ac2ce8d2"
PowerPointViewer_md5="9b4b476488674ae103d2e97cd88cd222"

# cab files downloaded from sourceforge corefonts
FONT_FILES="andale32.exe arialb32.exe comic32.exe courie32.exe georgi32.exe impact32.exe webdin32.exe"

FONT_FILES2="PowerPointViewer.exe"

# update cab file downloaded from sourceforge
UPDATE_FILE=EUupdate.EXE

# some install font
DOWNLOAD_FILE=wd97vwr32.exe

# these cabs contain fonts updated by EUupdate.EXE, so only download these
# if the download for EUupdate.EXE failed
UPDATED_FONT_FILES="arial32.exe times32.exe trebuc32.exe verdan32.exe"

download_files="${FONT_FILES} ${DOWNLOAD_FILE} mirror_update ${UPDATE_FILE} ${FONT_FILES2} only_if_errors ${UPDATED_FONT_FILES}"

failures=0

download_update_file_error=no

count_errors=0
count_fonts_installed=0
current_mirror="$mirror"
for df in $download_files
do
  case "$df" in
  mirror_update) current_mirror="$mirror_update"; continue ;;
  only_if_errors) [ $download_update_file_error = yes ] && continue || break;;
  esac

  failures=0
  found=no
  error=no
  while [ $found != yes -a $error = no ]
  do
    check_file $df
    rc=$?
    if [ $rc -gt 0 ]; then # fail to find
      [ -e "$df" ] && rm -f "$df"

      if [ $failures -gt 0 ]; then
        if [ $rc -eq 1 ]; then
          error "$df does not exist"
        fi
      fi
    else
      found=yes
      if [ $failures -gt 0 ]; then
        progress "cab file $df successfully downloaded"
      else
        progress "cab file $df already downloaded"
      fi
    fi

    if [ $found != yes ]; then
      if [ $failures -gt 5 ]; then
        case "$df" in
        ${UPDATE_FILE})
          error "failed to download $mirror/$df too many times."
          warning "trying to download alternates."
          download_update_file_error=yes
          ;;
        *)
          error "failed to download $mirror/$df too many times, giving up."
          error=yes
          break
          ;;
        esac
      elif [ $failures -gt 0 ]; then
        error "failed to download $mirror/$df: attempt $failures"
      fi
      failures=`expr $failures + 1`

      progress "Downloading $df from $current_mirror"
      download_file "$current_mirror" "$df"
    else
      [ -n "$INSTALLED_LIST" ] && sha256sum "$df" | sed -e 's/   */ /' >> "$INSTALLED_LIST"

      progress "extracting fonts from $df directly into ${FONTDIR}"
      cabextract --lowercase ${VERBOSE_FLAG:--q} -F '*.ttf' --directory=${FONTDIR} "$df"
      case "$df" in
      PowerPointViewer.exe)
        # handle the ClearType fonts
        if [ -n "$LICENSE_FILE" ]; then
          ldir="${LICENSE_FILE}"
          [ ! -d "$ldir" -a -n "${ldir%/*}" -a -d "${ldir%/*}" ] && Ldir="${ldir%/*}"
          if [ -d "$ldir" ]; then
            # save the eula file
            cabextract --lowercase ${VERBOSE_FLAG:--q} -F 'eula.txt' "$df"
            mv eula.txt "$ldir"
            progress "MS EULA for ClearType fonts saved to $ldir"
          else
            warning "Not saving EULA for ClearType fonts, directory $ldir not found"
          fi
        fi

        cabextract --lowercase ${VERBOSE_FLAG:--q} -F 'ppviewer.cab' "$df"
        cabextract --lowercase ${VERBOSE_FLAG:--q} -F '*.ttf' --directory=${FONTDIR} ppviewer.cab
        [ -n "$INSTALLED_LIST" ] && list_cab_contents $df ppviewer.cab >> "$INSTALLED_LIST"

        rm -f ppviewer.cab
        ;;

      wd97vwr32.exe)
        if [ -n "$LICENSE_FILE" ]; then
          if [ -d "${LICENSE_FILE%/*}" -o -d "${LICENSE_FILE}" ]; then
            # save the license file
            cabextract --lowercase ${VERBOSE_FLAG:--q} -F 'license.txt' "$df"
            mv license.txt "$LICENSE_FILE"
            progress "MS License file saved to $LICENSE_FILE"
          else
            warning "Not saving license file, directory ${LICENSE_FILE%/*} not found"
          fi
        fi

        cabextract --lowercase ${VERBOSE_FLAG:--q} -F 'viewer1.cab' "$df"
        cabextract --lowercase ${VERBOSE_FLAG:--q} -F '*.ttf' --directory=${FONTDIR} viewer1.cab
        [ -n "$INSTALLED_LIST" ] && list_cab_contents $df viewer1.cab >> "$INSTALLED_LIST"
        rm -f viewer1.cab
        ;;

      *) [ -n "$INSTALLED_LIST" ] && list_cab_contents $df >> "$INSTALLED_LIST" ;;
      esac

      count_fonts_installed=`expr $count_fonts_installed + 1`
      [ "$KEEP_TMP_FLAG" ] || rm -f "$df"
    fi
  done
  [ $error = yes ] && count_errors=`expr $count_errors + 1`
done

if ! [ "$DOWNLOAD_ONLY_FLAG" ]; then
  oops=
  case "$FONTDIR" in
  /usr/share/fonts/*)
    progress "Adding fonts to Xft"
    ;;
  *)
    # note: if the FONTDIR is not a subdirectory of the system font dir
    # we have some extra work to do ...

    # point fc-cache to this new font directory

    if mkdir -p /etc/fonts/conf.d; then
      progress "Adding new fontdir $FONTDIR to Xft"

      cat - > /etc/fonts/conf.d/09-msttcore-fonts.conf <<EOT
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <dir>$FONTDIR</dir>
</fontconfig>
EOT
    else
      error "Failed to create /etc/fonts/conf.d, cannot add new fontdir $FONTDIR to Xft"
      oops=1
    fi
    ;;
  esac

  if [ -z "$oops" ]; then
    fc_cache=`type -p fc-cache`
    if [ -n "$fc_cache" -a -x "$fc_cache" ]; then
      progress "Indexing the new fonts for Xft"
      "$fc_cache" -f -v
    else
      warning "fc-cache not found, cannot prepare the fonts for Xft"
    fi
  fi
fi

exit 0
