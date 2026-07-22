#!/usr/bin/env bash
set -euo pipefail

# DeckDoc never writes the unfiltered input. This filter intentionally favors
# removing diagnostic detail over retaining a possible identity or credential.
HOST_VALUE=""
if [ -r /etc/hostname ]; then
    HOST_VALUE=$(tr -d '\r\n' < /etc/hostname 2>/dev/null || true)
fi

awk -v private_host="$HOST_VALUE" '
function literal_replace(text, needle, replacement,    before, after, position) {
    if (needle == "") return text
    while ((position = index(text, needle)) > 0) {
        before = substr(text, 1, position - 1)
        after = substr(text, position + length(needle))
        text = before replacement after
    }
    return text
}

function token_for(kind, value,    key) {
    key = kind SUBSEP value
    if (!(key in token)) {
        count[kind]++
        token[key] = "<" kind "-" count[kind] ">"
    }
    return token[key]
}

function replace_pattern(text, pattern, kind,    before, value, after) {
    while (match(text, pattern)) {
        before = substr(text, 1, RSTART - 1)
        value = substr(text, RSTART, RLENGTH)
        after = substr(text, RSTART + RLENGTH)
        text = before token_for(kind, value) after
    }
    return text
}

function replace_exact_hex(text, wanted_length, kind,    output, before, value, after) {
    output = ""
    while (match(text, /[[:xdigit:]]+/)) {
        before = substr(text, 1, RSTART - 1)
        value = substr(text, RSTART, RLENGTH)
        after = substr(text, RSTART + RLENGTH)
        output = output before
        if (length(value) == wanted_length) output = output token_for(kind, value)
        else output = output value
        text = after
    }
    return output text
}

BEGIN {
    private_block = 0
    url_pattern = "[[:alpha:]][[:alnum:]+.-]*://[^[:space:]<>]+"
    email_pattern = "[[:alnum:]_.%+-]+@[[:alnum:].-]+\\.[[:alpha:]][[:alpha:]]+"
    mac_pattern = "[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]"
    ipv4_pattern = "[0-9][0-9]?[0-9]?\\.[0-9][0-9]?[0-9]?\\.[0-9][0-9]?[0-9]?\\.[0-9][0-9]?[0-9]?"
    ipv6_long_pattern = "[[:xdigit:]][[:xdigit:]:]*:[[:xdigit:]:]*:[[:xdigit:]:]*:[[:xdigit:]:]+"
    ipv6_short_pattern = "[[:xdigit:]][[:xdigit:]]*::[[:xdigit:]][[:xdigit:]:]*"
    uuid_pattern = "[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]-[[:xdigit:]-]+"
    steam_id_pattern = "7656119[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"
}

{
    line = $0
    lower = tolower(line)

    if (lower ~ /-----begin [^-]*(private|secret) key-----/) {
        private_block = 1
        print "[REDACTED: private key block]"
        next
    }
    if (private_block) {
        if (lower ~ /-----end [^-]*(private|secret) key-----/) private_block = 0
        next
    }

    if (lower ~ /(password|passwd|passphrase|sudo[_-]?pass|api[_-]?key|access[_-]?token|refresh[_-]?token|bearer[[:space:]]|authorization[[:space:]]*:|cookie[[:space:]]*:|client[_-]?secret|private[_-]?key|credential|steam[[:space:]_-]*guard)/) {
        print "[REDACTED: sensitive value]"
        next
    }
    if (lower ~ /(^|[^[:alnum:]_])(ssid|bssid)[[:space:]_:=]/ ||
        lower ~ /(serial[[:space:]_-]*(number|no[.]?)|id_serial|machine[_-]?id)[[:space:]_:=]/) {
        print "[REDACTED: device or network identity]"
        next
    }
    if (lower ~ /(^|[^[:alnum:]_])(user[_ -]?id|account[_ -]?id|friend[_ -]?code)[[:space:]]*[:=]/) {
        print "[REDACTED: account identity]"
        next
    }

    line = literal_replace(line, private_host, "<host>")
    gsub(/\/var\/home\/[^\/[:space:]"<>]+/, "/var/home/<user>", line)
    gsub(/\/home\/[^\/[:space:]"<>]+/, "/home/<user>", line)
    gsub(/\/run\/user\/[0-9]+/, "/run/user/<uid>", line)
    gsub(/\/run\/media\/[^\/[:space:]"<>]+\/[^\/[:space:]"<>]+/, "/run/media/<user>/<media>", line)
    gsub(/\/media\/[^\/[:space:]"<>]+\/[^\/[:space:]"<>]+/, "/media/<user>/<media>", line)
    gsub(/\/mnt\/[^\/[:space:]"<>]+/, "/mnt/<item>", line)
    gsub(/\/tmp\/[^\/[:space:]"<>]+/, "/tmp/<item>", line)
    line = replace_pattern(line, url_pattern, "url")
    line = replace_pattern(line, email_pattern, "email")
    line = replace_pattern(line, mac_pattern, "mac")
    line = replace_pattern(line, ipv6_long_pattern, "ip")
    line = replace_pattern(line, ipv6_short_pattern, "ip")
    line = replace_pattern(line, ipv4_pattern, "ip")
    line = replace_pattern(line, uuid_pattern, "id")
    line = replace_pattern(line, steam_id_pattern, "account")
    line = replace_exact_hex(line, 32, "account")
    print line
}
'
