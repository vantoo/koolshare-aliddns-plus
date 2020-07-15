#!/bin/sh

eval `dbus export aliddns-plus_`

if [ "$aliddns-plus_enable" != "1" ]; then
    echo "not enable"
    exit
fi

now=`date`

die () {
    echo $1
    dbus ram aliddns-plus_last_act="$now: failed($1)"
}

[ "$aliddns-plus_curl" = "" ] && aliddns-plus_curl="curl -s whatismyip.akamai.com"
[ "$aliddns-plus_dns" = "" ] && aliddns-plus_dns="223.5.5.5"
[ "$aliddns-plus_ttl" = "" ] && aliddns-plus_ttl="600"

ip=`$aliddns-plus_curl 2>&1` || die "$ip"

current_ip=`nslookup $aliddns-plus_name.$aliddns-plus_domain $aliddns-plus_dns 2>&1`

if [ "$?" -eq "0" ]
then
    current_ip=`echo "$current_ip" | grep 'Address 1' | tail -n1 | awk '{print $NF}'`

    if [ "$ip" = "$current_ip" ]
    then
        echo "skipping"
        dbus set aliddns-plus_last_act="$now: skipped($ip)"
        exit 0
    fi 
fi


timestamp=`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`

urlencode() {
    # urlencode <string>
    out=""
    while read -n1 c
    do
        case $c in
            [a-zA-Z0-9._-]) out="$out$c" ;;
            *) out="$out`printf '%%%02X' "'$c"`" ;;
        esac
    done
    echo -n $out
}

enc() {
    echo -n "$1" | urlencode
}

send_request() {
    local args="AccessKeyId=$aliddns-plus_ak&Action=$1&Format=json&$2&Version=2015-01-09"
    local hash=$(echo -n "GET&%2F&$(enc "$args")" | openssl dgst -sha1 -hmac "$aliddns-plus_sk&" -binary | openssl base64)
    curl -s "http://alidns.aliyuncs.com/?$args&Signature=$(enc "$hash")"
}

get_recordid() {
    grep -Eo '"RecordId":"[0-9]+"' | cut -d':' -f2 | tr -d '"'
}

query_recordid() {
    send_request "DescribeSubDomainRecords" "SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&SubDomain=$aliddns-plus_name.$aliddns-plus_domain&Timestamp=$timestamp"
}

update_record() {
    send_request "UpdateDomainRecord" "RR=$aliddns-plus_name&RecordId=$1&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns-plus_ttl&Timestamp=$timestamp&Type=A&Value=$ip"
}

add_record() {
    send_request "AddDomainRecord&DomainName=$aliddns-plus_domain" "RR=$aliddns-plus_name&SignatureMethod=HMAC-SHA1&SignatureNonce=$timestamp&SignatureVersion=1.0&TTL=$aliddns-plus_ttl&Timestamp=$timestamp&Type=A&Value=$ip"
}

if [ "$aliddns-plus_record_id" = "" ]
then
    aliddns-plus_record_id=`query_recordid | get_recordid`
fi
if [ "$aliddns-plus_record_id" = "" ]
then
    aliddns-plus_record_id=`add_record | get_recordid`
    echo "added record $aliddns-plus_record_id"
else
    update_record $aliddns-plus_record_id
    echo "updated record $aliddns-plus_record_id"
fi

# save to file
if [ "$aliddns-plus_record_id" = "" ]; then
    # failed
    dbus ram aliddns-plus_last_act="$now: failed"
else
    dbus ram aliddns-plus_record_id=$aliddns-plus_record_id
    dbus ram aliddns-plus_last_act="$now: success($ip)"
fi