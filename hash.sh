#! /bin/bash

# Do some prep work
command -v jq >/dev/null 2>&1 || { echo >&2 "We require jq for this script to run, but it's not installed.  Aborting."; exit 1; }
command -v sha1sum >/dev/null 2>&1 || { echo >&2 "We require sha1sum for this script to run, but it's not installed.  Aborting."; exit 1; }

# quick checksum generator for all the Bibles used in getBible.net
echo -n "[vdm.io] -- Building checksum for all Bibles found in getBible's repository......"

# get array value
function getArrayValue () {
	# main string
	str="$1"
	# delimiter string
	delimiter="$2"
	#length of main string
	strLen=${#str}
	#length of delimiter string
	dLen=${#delimiter}
	#iterator for length of string
	i=0
	#length tracker for ongoing substring
	wordLen=0
	#starting position for ongoing substring
	strP=0

	array=()
	while [ $i -lt $strLen ]; do
		if [ $delimiter == ${str:$i:$dLen} ]; then
			array+=(${str:strP:$wordLen})
			strP=$(( i + dLen ))
			wordLen=0
			i=$(( i + dLen ))
		fi
		i=$(( i + 1 ))
		wordLen=$(( wordLen + 1 ))
	done
	array+=(${str:strP:$wordLen})

	if [ "$3" -eq "7" ]; then
		echo "${array[@]}"
	else
		echo "${array[$3]}"
	fi
}

# setup: positional arguments to pass in literal variables, query with code    
jq_args=( )
jq_query='.'
jq_t_args=( )
jq_t_query='.'
# counter
nr=1
# book names
echo "#	language	translation	abbreviation	textdirection	filename	hash" > translations
# checksum
echo "#	filename	checksum" > checksum

for filename in *.txt; do
	# get the hash
	fileHash=$(sha1sum "$filename" | awk '{print $1}')
	# build the hash file name
	hashFileName="${filename/.txt/.sha}"
	# get the file name
	fileName="${filename/.txt/}"
	fileNameX="${fileName/___/\'}"
	# get the details
	language=$(getArrayValue "$fileNameX" "__" 0)
	language=$(getArrayValue "$language" "_" 7)
	translation=$(getArrayValue "$fileNameX" "__" 1)
	translation=$(getArrayValue "$translation" "_" 7)
	abbreviation=$(getArrayValue "$fileNameX" "__" 2)
	textdirection=$(getArrayValue "$fileNameX" "__" 3)
	# set file details to text file
	echo "${nr}	${language}	${translation}	${abbreviation}	${textdirection}	${fileName}	${fileHash}" >> translations
	# build the json details
	JSON_STRING=$( jq -n \
		--arg id "${nr}" \
		--arg lang "${language}" \
		--arg tra "${translation}" \
		--arg abb "${abbreviation}" \
		--arg dir "${textdirection}" \
		--arg fhash "${fileHash}" \
		--arg fname "${fileName}" \
		'{language: $lang, translation: $tra, abbreviation: $abb, textdirection: $dir, filename: $fname, hash: $fhash, id: $id}' )
	# load the values for json
	jq_t_args+=( --arg "key$nr"   "$abbreviation"   )
	jq_t_args+=( --argjson "value$nr" "$JSON_STRING" )
	# build query for jq
	jq_t_query+=" | .[\$key${nr}]=\$value${nr}"
	# create/update the Bible file checksum
	echo "${fileHash}" > "$hashFileName"
	echo "${nr}	${filename}	${fileHash}" >> checksum
	# load the values for json
	jq_args+=( --arg "key$nr"   "$filename"   )
	jq_args+=( --arg "value$nr" "$fileHash" )
	# build query for jq
	jq_query+=" | .[\$key${nr}]=\$value${nr}"
	#next
	nr=$((nr+1))
done

# run the generated command with jq
jq "${jq_args[@]}" "$jq_query" <<<'{}' > checksum.json
jq "${jq_t_args[@]}" "$jq_t_query" <<<'{}' > translations.json

# done with hash
echo "done"
