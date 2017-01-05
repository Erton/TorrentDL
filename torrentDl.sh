#!/bin/bash

. .tdl.conf
. .tdl_$tdl_lang.lang

tmpFile=$(mktemp)
oldIFS=$IFS
IFS=$(echo -en "\n\b") # don't split array after each space
speedLimit=$(($speedLimit*1024))
if [ $# -eq 1 ]; then baseUrl="$1"; fi

dlCmd(){ # args: <link index in array>
	axel -s $speedLimit -an$dlThreads "$baseUrl${linkList[$1]}"
}

getData(){ # args: <baseUrl>
	local webPage=$(mktemp)
	wget -q $1 -O - | grep '\<img src=\"/icons/' > $webPage # get all movies and folders from apache index
	cat $webPage | grep '\<img src=\"/icons/movie' | sed -e s/.*href=\"//g -e s#\</a\>.*##g | sort -n > $tmpFile
	cat $webPage | grep -v '\<img src=\"/icons/\(movie\|folder\|back\|blank\)' | sed -e s/.*href=\"//g -e s#\</a\>.*##g | sort -n >> $tmpFile
	cat $webPage | grep '\<img src=\"/icons/folder' | sed -e s/.*href=\"//g -e s#\</a\>.*##g | sort -n >> $tmpFile
	rm $webPage
	maxStrLen=1
	local i=1; while read line; do
		linkList[$i]=$(echo $line | sed s/\"\>.*//g)
		fileName[$i]=$(echo $line | sed -e s/.*\"\>//g)
		dispName[$i]=$(echo $line | sed -e s/.*\"\>//g -e s/\\[720p\\]//g -e 's/\[HorribleSubs\]\(.*\)\ -\ \(..\)\ /\[HorribleSubs\]\ \\Zb\2\\Zn\1/g' -e s/^\\[HorribleSubs\\]/[HS]/g -e 's/\(.*\)\/$/\\Zb\>\ \1\\Zn/g')
		if [ ${#dispName[$i]} -gt $maxStrLen ]; then
			maxStrLen=$(echo ${dispName[$i]} | wc -c)
		fi
		i=$(($i+1))
	done < $tmpFile
	rm $tmpFile
}


dl(){ # args: <link index in array>
	if [[ ! ${fileName[$queueIndex]} == */ ]]; then
		if [ $queueIndex -gt 1 ]; then echo; fi # new line after each dl
		printf '%*s\n' "$(tput cols)" '' | tr ' ' = # line separator
		echo -e "\e[1m${fileName[$1]}\e[0m"
		printf '%*s\n' "$(tput cols)" '' | tr ' ' =

		if [ -e "${fileName[$1]}" ]; then
			if [ -e "$(echo ${fileName[$1]}.st)" ]; then
				echo -e $text_partial
				read -n1 -srt5; local errorCode=$?
				if [[ $errorCode -eq 142 ]];	then
					dlCmd $1
				else
					echo $text_cancel
				fi
			else
				echo -e $text_alreadyDl
			fi
		else
			dlCmd $1
		fi
	fi
}

genMenu(){
	for i in $(seq 1 ${#dispName[@]}); do
		echo $i
		echo ${dispName[$i]}
		echo 0
	done
}

getData $baseUrl
if [ $baseUrl -gt $maxStrLen ]; then
	maxStrLen=$(echo $baseUrl | wc -c)
	echo LEN && sleep 5
fi
dialog --colors --checklist $baseUrl $((${#dispName[@]}+7)) $(($maxStrLen+15)) ${#dispName[@]} $(genMenu) 2>$tmpFile ; clear ; selected=$(cat $tmpFile)

IFS=$oldIFS
if [[ $selected ]]; then
	elements=$(echo $selected | wc -w)
	for queueIndex in $selected; do
		if [[ ${fileName[$queueIndex]} == */ ]]; then
			./torrentDl.sh "$baseUrl${fileName[$queueIndex]}"
		fi
		dl $queueIndex
	done
fi
