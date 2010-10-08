#!/bin/bash

#/etc/my.cnf:
#max_allowed_packet = 10M

#chown apache:nobody -R /var/www/html/wiki/images/
#find /var/www/html/wiki/images/ -type d -exec chmod 775 {} \+

# active main,ver naming: the ones returned from mefs query
# active customers: from marinels query


BASEDIR=$(cd $(dirname "$0"); pwd)
MY_DIR=$BASEDIR
SVN_USER="svncheckout"
SVN_PASS="svncheckout"
SVN_BASE="http://10.10.4.4:8080/svn/repos/trunk/Projects/iPhonEX/"

LOCAL_FILE="$MY_DIR/svn_result"
# http://10.10.4.4:8080/svn/repos/trunk/Projects/iPhonEX/*/*/Installation/Installers/*/*.uip


# svn list --recursive --non-interactive --no-auth-cache --trust-server-cert --password $SVN_PASS --username $SVN_USER http://10.10.4.4:8080/svn/repos/trunk/Projects/iPhonEX/ > ./all_vsn


function svn_list() {
    svn list $REC --non-interactive --no-auth-cache --trust-server-cert --password "$SVN_PASS" --username "$SVN_USER" "$1" > "$2"
    return $?
}

REC=""
svn_list $SVN_BASE $LOCAL_FILE"_1";

while IFS= read -r line; do
    line=$(echo $line | grep "^[0-9]")
    if [[ $line != "" ]];then
	REC=""
	svn_list "$SVN_BASE$line" $LOCAL_FILE"_2"
	if [[ $? -eq 0 ]];then
	    while IFS= read -r line2; do
		if [[ $line2 != "" ]];then
		    REC="--recursive"
		    svn_list "$SVN_BASE$line$line2/Installation/" $LOCAL_FILE"_3"
		    if [[ $? -eq 0 ]];then
			cat $LOCAL_FILE"_3" | grep ".uip$"
		    fi
		fi
	    done <$LOCAL_FILE"_2"
	fi
    fi
done <$LOCAL_FILE"_1"
#
# function update_from_svn() {
#     SQL_FILE="$MY_DIR/select_active_versions.sql"
#     SQL_OUTPUT_FILE="$MY_DIR/select_active_versions.out"
#
#     mkdir -p $SVN_LOCAL_BASE_PATH
#     $IC_PATH/sqlplus -S $ORA_USER/$ORA_PASS @$SQL_FILE $COL_SEP $SQL_OUTPUT_FILE
#
#     if [ $? -ne 0 ]; then
# 	echo "query failed"
# 	exit 1
#     fi
#
#     SVN_USER="svncheckout"
#     SVN_PASS="svncheckout"
#
#     echo "Projects"
#     SVN_BASE_URL="http://10.10.4.4:8080/svn/repos/trunk/Projects/iPhonEX"
#     APPEND_DIR_ARRAY=( "Documents" "Scripts")
#     while IFS=$COL_SEP read main; do
# 	main=$(echo $main)
# 	for i in ${!APPEND_DIR_ARRAY[@]}; do
# 	    SVN_URL="$SVN_BASE_URL/$main/${APPEND_DIR_ARRAY[i]}"
# 	    LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/Projects/$main/${APPEND_DIR_ARRAY[i]}"
# 	    time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
# 	done
#     done <$SQL_OUTPUT_FILE
#
#     echo "Projects_Common"
#     SVN_URL="$SVN_BASE_URL/Common/Documents/"
#     LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/Projects_Common"
#     time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
#
#     echo "Projects_Customizations"
#     SVN_URL="$SVN_BASE_URL/Customizations"
#     svn list --non-interactive --no-auth-cache --trust-server-cert --password "$SVN_PASS" --username "$SVN_PASS" "$SVN_URL" > "$MY_DIR/customers"
#     while IFS="/" read cust; do
# 	SVN_URL_B="$SVN_BASE_URL/Customizations/$cust"
# 	svn list --non-interactive --no-auth-cache --trust-server-cert --password "$SVN_PASS" --username "$SVN_PASS" "$SVN_URL_B" | tail -1  > "$MY_DIR/customers_ver"
# 	while IFS="/" read ver; do
# 	    for i in ${!APPEND_DIR_ARRAY[@]}; do
# 		SVN_URL="$SVN_URL_B/$ver/${APPEND_DIR_ARRAY[i]}"
# 		LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/Projects_Customizations/$cust/$ver/${APPEND_DIR_ARRAY[i]}"
# 		time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
# 	    done
# 	done <"$MY_DIR/customers_ver"
#     done <"$MY_DIR/customers"
#
#     echo "Projects_Deployment"
#     while IFS="/" read main ver; do
# 	SVN_URL="$SVN_BASE_URL/Deployment/$main"
# 	LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/Projects_Deployment/$main"
# 	time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
#     done <$SQL_OUTPUT_FILE
#
#     echo "Projects_Deployment_Common"
#     SVN_URL="$SVN_BASE_URL/Deployment/Common"
#     LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/Projects_Deployment_Common"
#     time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
#
#     echo "Projects_Deployment_Customization"
#     SVN_URL="$SVN_BASE_URL/Deployment/Customization"
#     LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/Projects_Deployment_Customization"
#     time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
#
#     echo "Docs"
#     SVN_BASE_URL="http://10.10.4.4:8080/svn/docs/repos/trunk/Documentation/iPhonEX%20Documents/iPhonEX"
#     while IFS="/" read main ver; do
# 	main=$(echo V$main)
# 	#ver=$(echo $ver | sed s/\ //g | sed s/SP.*//)
# 	SVN_URL="$SVN_BASE_URL/$main"
# 	LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/Docs/$main"
# 	time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
#     done <$SQL_OUTPUT_FILE
#
#     echo "Docs_Customizations"
#     SVN_URL="$SVN_BASE_URL/Customizations"
#     svn list --non-interactive --no-auth-cache --trust-server-cert --password "$SVN_PASS" --username "$SVN_PASS" "$SVN_URL" > "$MY_DIR/customers"
#     while IFS="/" read cust; do
# 	SVN_URL="$SVN_BASE_URL/Customizations/$cust"
# 	svn list --non-interactive --no-auth-cache --trust-server-cert --password "$SVN_PASS" --username "$SVN_PASS" "$SVN_URL" | tail -1  > "$MY_DIR/customers_ver"
# 	while IFS="/" read ver; do
# 	    SVN_URL="$SVN_URL/$ver"
# 	    LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/Docs_Customizations/$cust/$ver"
# 	    time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
# 	done <"$MY_DIR/customers_ver"
#     done <"$MY_DIR/customers"
#
# #     echo "SCDocs"
# #     SVN_BASE_URL="http://10.10.4.4:8080/svn/scdocs/repos/svnDocs/Documents/iPhonEX/"
# #     APPEND_DIR_ARRAY=( "arch" "def" "hld" "market")
# #     for i in ${!APPEND_DIR_ARRAY[@]}; do
# # 	SVN_URL="$SVN_BASE_URL/${APPEND_DIR_ARRAY[i]}"
# # 	LOCAL_SVN_PATH="$SVN_LOCAL_BASE_PATH/SCDocs/${APPEND_DIR_ARRAY[i]}"
# # 	time update_svn "$SVN_URL" "$LOCAL_SVN_PATH"
# #     done
# }
#
# update_from_svn
# rm "$MY_DIR/customers_ver" -f
exit