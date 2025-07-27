#! /usr/bin/env bash

EXE=$( basename "$0" )
OUT_FILENAME=""
TMP_DIR=""
TMP_NAME="performous.appimage-build.$$"
REPO_URL='https://github.com/performous/performous.git'
APPIMAGETOOL_URL='https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage'

START_DIR=$( pwd )

### Used to handle quick failures
messageExit () {
    echo "${EXE}: $1 $2 $3 $4 $5"
    # cleanup
    cd "${START_DIR}"
    if [ ! -z "${TMP_DIR}" ] && [ -d "${TMP_DIR}" ]; then
        rm -fr "${TMP_DIR}"
    fi
    exit 1
}

### Check we have the necessary tools
for needed_program in git cmake make ldd awk wget; do 
    which ${needed_program} > /dev/null || messageExit "The program [${needed_program}] is needed, can't continue"
done

###
### Process command line args (if any)
###
while [ "$#" -gt 0 ]; do
    case "$1" in 
        -o)
            OUT_FILENAME="${2}"
            shift 2
            ;;
        --out=*)
            OUT_FILENAME="${1#*=}"
            shift 1
            ;;
        --tmp=*)
            TMP_DIR="${1#*=}/${TMP_NAME}"
            shift 1
            ;;

        -h|--help|/?|-?)
            echo "${EXE}: Options:"
            echo "${EXE}: -o [dir/file] | --output=[dir/file]  ... Where to write the App Image"
            echo "${EXE}: --tmp=[dir]  ........................... Which tmp/ dir to use"
            exit 1
            ;;
        *)
            echo "${EXE}: Invalid argument [$1], maybe try --help"
            exit 1
            ;;
    esac
done


### Find a usable temp dir
if [ -z "${TMP_DIR}" ]; then 
    if [ -d "${HOME}/tmp" ] && [ -w "${HOME}/tmp" ]; then
        TMP_DIR="${HOME}/tmp/${TMP_NAME}"
    elif [ ! -z "${TMPDIR}" ] && [ -w "${TMPDIR}" ] ; then
        TMP_DIR="${TMP_DIR}/${TMP_NAME}"
    elif [ ! -z "${TEMP}" ] && [ -w "${TEMP}" ] ; then
        TMP_DIR="${TEMP}/${TMP_NAME}"
    elif [ -d "/tmp" ] && [ -w "/tmp" ] ; then
        TMP_DIR="/tmp/${TMP_NAME}"
    else
        messageExit "Unable to find a temporary directory, try --help"
    fi
fi

# make our work dir in TMP
mkdir -p "${TMP_DIR}"
if [ ! -d "${TMP_DIR}" ] || [ ! -w "${TMP_DIR}" ]; then
     messageExit "Unable to make/use use temporary directory [${TMP_DIR}], giving up"
fi
cd "${TMP_DIR}" || messageExit "Unable to cwd into [${TMP_DIR}], giving up"

### Make the AppDir (so we can install into it via cmake)
APP_DIR="${TMP_DIR}/AppDir"
mkdir "${APP_DIR}" || messageExit "Failed to make [${APP_DIR}], giving up"

### Fetch the AppImage tool
echo "### Fetching AppImageTool ..."
APPIMAGETOOL="${TMP_DIR}/AppImageTool"
wget -nv -pq "${APPIMAGETOOL_URL}" -O "${APPIMAGETOOL}" || messageExit "Failed to download AppImageTool from [${APPIMAGETOOL_URL}], giving up"
chmod +x "${APPIMAGETOOL}" || messageExit "Failed to make AppimageTool [${APPIMAGETOOL}] executable, giving up"
echo "### Fetching AppImageTool Completes"

### Clone the Performous repo
echo "### Cloning Performous ..."
git clone "${REPO_URL}" || messageExit "Failed to clone Performous repo' [${REPO_URL}], giving up"
test -d performous || messageExit "Repo' doesn't seem to have a [performous] dir, giving up"
echo "### Cloning Performous Completes"

SRC_DIR="${TMP_DIR}/performous"
BUILD_DIR="${TMP_DIR}/performous/BUILD"
mkdir "${BUILD_DIR}" || messageExit "Unable to make dir [${BUILD_DIR}], giving up"

### Kickoff the Performous build
cd "${BUILD_DIR}" || messageExit "Unable to use [${BUILD_DIR}], giving up"
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr .. || messageExit "CMake failed, giving up"
make -j4 install DESTDIR="${APP_DIR}" || messageExit "(GNU) make failed, giving up"


### So now we have Performous packed into the .../AppDir directory, with all resources
PERFORMOUS_EXE="${APP_DIR}/usr/bin/performous"
test -x "${PERFORMOUS_EXE}" || messageExit "Failed to find Perfomous at [${PERFORMOUS_EXE}], giving up"

# Start adding the required libraries
APPLIB_DIR="${APP_DIR}/usr/lib"
mkdir "${APPLIB_DIR}" || messageExit "Failed to create [${APPLIB_DIR}], giving up" 
ldd "${PERFORMOUS_EXE}" | awk '{ print $3 }' | 
while read lib_file; do
    # Core System libraries end up giving a blank $lib_file, we want to skip these anyway
    if [ ! -z "${lib_file}" ]; then
        #echo "COPY [$lib_file] to [${APPLIB_DIR}]"
        cp --dereference -p "${lib_file}" "${APPLIB_DIR}/"    # ensure symlinks are copied too
    fi
done

### Create the AppRun
cd "${APP_DIR}"
cat << EOT >> "AppRun"
#! /bin/bash
export LD_LIBRARY_PATH=$APPIMAGE/usr/lib:$LD_LIBRARY_PATH
chmod a+rx "$APPIMAGE/usr/bin/performous"
exec "$APPIMAGE/usr/bin/performous"
EOT
chmod a+rx AppRun

### Create the miscellaneous AppImage infrastructure
cp "${SRC_DIR}/data/performous.desktop" "${APP_DIR}/"
cp "${SRC_DIR}/data/themes/default/icon.svg" "${APP_DIR}/performous.svg"
cp "${SRC_DIR}/data/themes/default/icon128x128.png" "${APP_DIR}/AppRun.DirIcon"

echo "### Building AppImage to [${OUT_FILENAME}] ..."
cd "${START_DIR}"
"${APPIMAGETOOL}" "${APP_DIR}" "${OUT_FILENAME}"
echo "### Building AppImage Completes"

if [ $? -ne 0 ]; then
    echo "${EXE} AppImageTool reported failed"
else
    echo "${EXE} AppImageTool reported success creating [${OUT_FILENAME}]"
fi

### Clean Up
if [ ! -z "${TMP_DIR}" ] && [ -d "${TMP_DIR}" ]; then
    cd "${START_DIR}"
    rm -fr "${TMP_DIR}"
fi
