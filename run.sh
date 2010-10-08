#!/bin/bash

#/etc/my.cnf:
#max_allowed_packet = 10M

#chown apache:nobody -R /var/www/html/wiki/images/
#find /var/www/html/wiki/images/ -type d -exec chmod 775 {} \+

BASEDIR=$(cd $(dirname "$0"); pwd)
MY_DIR=$BASEDIR
SVN_USER="svncheckout"
SVN_PASS="svncheckout"
SVN_BASE="http://10.10.4.4:8080/svn/repos/trunk/Projects/iPhonEX/"

LOCAL_FILE="$MY_DIR/svn_result"

function svn_list() {
    svn list $REC --non-interactive --no-auth-cache --trust-server-cert --password "$SVN_PASS" --username "$SVN_USER" "$1" > "$2"
    return $?
}

REC=""
svn_list $SVN_BASE "$LOCAL_FILE""_1";

while IFS= read -r line; do
    line=$(echo $line | grep "^[0-9]")
    if [[ $line != "" ]];then
	REC=""
	svn_list "$SVN_BASE$line" "$LOCAL_FILE""_2"
	if [[ $? -eq 0 ]];then
	    while IFS= read -r line2; do
		if [[ $line2 != "" ]];then
		    REC="--recursive"
		    svn_list "$SVN_BASE$line$line2/Installation/" "$LOCAL_FILE""_3"
		    if [[ $? -eq 0 ]];then
			cat "$LOCAL_FILE""_3" | grep ".uip$" | gawk -v VAR="$SVN_BASE$line$line2/Installation/" '{print VAR $0}'
# 			cat "$LOCAL_FILE""_3" | grep ".uip$" | sed 's/^/'$STR'\/Installation\//'
		    fi
		fi
	    done <"$LOCAL_FILE""_2"
	fi
    fi
done <"$LOCAL_FILE""_1"

rm -f "$LOCAL_FILE""_1" "$LOCAL_FILE""_2" "$LOCAL_FILE""_3"
exit