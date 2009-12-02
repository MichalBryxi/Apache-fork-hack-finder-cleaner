#!/bin/bash

# Script created for finding and removing the "keygenguru" hack.
# Hack uses vulnerability of <apr-1.3.6
# See: http://smaert.com/apache_mischief/writeup.txt for more info
# BIG FAT WARNING: This script is dumb. Do not execute it before altering constants and backing up your files!
# Some parts are server-specific and may never run on your configuration properly.

#PAYLOAD='eval *\( *base64_decode' # Most evil is behind this snippet. BUT! Wordpress also produces this code!
PAYLOAD="e[^a-z]*v[^a-z]*a[^a-z]*l[^a-z]*b[^a-z]*a[^a-z]*s[^a-z]*e[^a-z]*6[^a-z]*4[^a-z]*_[^a-z]*d[^a-z]*e[^a-z]*c[^a-z]*o[^a-z]*d[^a-z]*e"

PHP_EXT='*.php' # Keygenguru hack infects afaik only *.php files
RECORDS='/tmp/results_scan' # Where to store infected files list?
#HTDOCS='/var/www/' # Where is your htdocs?
HTDOCS='/DISK2/www/' # Where is your htdocs?
TYPES_DIR='/tmp/types/' # Where to store parsed hack types logs?
FIRST_LINES="999999" # Just a hand-break for development.
LE=".log" # Where to store infected files log.
PE=".payload" # Where to store payload log.
SEPARATOR='----------------------------' # Just for nice output,

case "$1" in
"1")
    time find ${HTDOCS} -name "${PHP_EXT}" -exec egrep -Hl "${PAYLOAD}" "{}" \; > ${RECORDS}
    echo ${SEPARATOR}
    ./${0} 2
    ;;
"2")
    echo "Comprimised files:"
    cat ${RECORDS} | wc -l 
    echo ${SEPARATOR}

    echo "Comromised domains:"
    cat ${RECORDS} | awk -F '/' '{ print $5 }'  | sort | uniq -c | sort -rn
    echo ${SEPARATOR}

    echo "Compromised accounts:"
    cat ${RECORDS} | awk -F '/' '{ print $4 }'  | sort | uniq -c | sort -rn
    echo ${SEPARATOR}
    ;;
"3")
    rm "${TYPES_DIR}" -rf 2> /dev/null
    mkdir -p ${TYPES_DIR}
    count=`wc -l ${RECORDS}`
    cat ${RECORDS} | while read file; do
        i=$(( i + 1 ))
        echo "${i}/${count} files done"
        type=`cat "${file}" | grep ${PAYLOAD}`
        hash=`echo ${type} | md5sum | awk '{ print $1}'`
        echo $type > "${TYPES_DIR}${hash}${PE}"
        echo ${file} >> "${TYPES_DIR}${hash}${LE}"

        if [ "$i" -gt ${FIRST_LINES} ]; then # hand-break for development
            break
        fi
    done
    ./${0} 4
    ;;
"4")
    echo "Below are files which contains list of infected files with the same payload:"
    files=(`ls ${TYPES_DIR}*${LE}`)
    for file in ${files[@]}; do
        wc $file -l
    done
    echo "The same files but with ${PE} extension contains the payload."
    ;;
"5" | "6")
    if [ -z "$2" ]; then
        echo "You MUST specify hash of the payload. This hash refers to files in ${TYPES_DIR}."
    else
        if [ "$1" -eq "6" ]; then
            echo "This action can DESTROY important data on your computer. Do you want to continue? [yes/NO]"
            read confirm
            if [ "$confirm" != "yes" ]; then
                echo "exitting..."
                exit
            fi
        fi
        files=(`cat ${TYPES_DIR}${2}${LE}`)
        count=${#files[@]}
        payload=`cat ${TYPES_DIR}$2${PE}`
        for file in ${files[@]}; do
            i=$(( i + 1 ))
            echo "${i}/${count} files done - ${file}"
            file_content=`cat "${file}"`
            if [ "$1" -eq "5" ]; then
                echo -e "${file_content/${payload}}" # dump into file
            elif [ "$1" -eq "6" ]; then
                echo "${file_content/${payload}}" > "${file}" # really write into file
            fi
            #break # for development only
        done
    fi
    ;;
*)
    echo "Usage: ./this_script.sh [arg1]"
    echo "    arg1 = 1 -> Scans ${HTDOCS} for ${PAYLOAD} and saves file list in ${RECORDS}."
    echo "           2 -> Shows some statistics. ${RECORDS} must exist! Server specific. In your enviroment this will not work!"
    echo "           3 -> Scans for payload variants."
    echo "           4 -> Echoes payload variants statistics. Option #3 must run first!"
    echo "           5 -> Performs a dry-run cleanup. This is the same as #6, but all data are printed out"
    echo "           6 -> Cleans up files listed in [arg2] file. arg2 should be hash and should refer to some of ${TYPES_DIR}*${LE}. Option #3 must run first! Cleans only first occurence. Run multiple times if multiple hacks installed."
esac
