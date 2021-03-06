#!/bin/bash
#===============================================================================
#
#          FILE:  sec_launch.sh
# 
#         USAGE:  ./sec_launch.sh 
# 
#   DESCRIPTION:  allow to launch for now R script with their dependencies in an
#		outputs folder
# 
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR:   (), 
#       COMPANY:  
#       VERSION:  1.0
#       CREATED:  06/04/2011 07:47:18 AM EDT
#      REVISION:  ---
#===============================================================================
# for security
# exit if use of uninitialised variable
set -o nounset
# I want the script to stop if something goes wrong without being well managed
set -o errexit
# I want fail to propagate through pipes
set -o pipefail
echo "let's go"

# parameters
outputs_folder="../outputs/"
paramFile="parameters_sampler.R"
keywords_lines_to_get_R="source read load compilLoad" 
keywords_lines_to_get_C="#include" 

# create output $outputs_folder
if [[ ! -e "$outputs_folder" ]] ; then
	mkdir "$outputs_folder"
fi
echo "output ok"
if [[ $# < 1 ]] ; then # if not at least one argument (first is always process name)
	echo "Don't know what to do."
	echo "syn: sec_launch.sh master_file.r"
	exit 2
fi
echo "input ok: $1"
# get the name in the R file
name_line=$(grep -m 1 "name.*<-" $1) || name_line=""
if [[ $name_line == "" ]] ; then
	if [[ -e $paramFile ]] ; then
		name_line=$(grep -m 1 "name.*<-" $paramFile ) || name_line=""
	fi
	if [[ $name_line == "" ]] ; then
		echo "cannot find name for the simulation"
		exit 1
	fi
fi

echo "name_line:$name_line"
name=$(echo "$name_line" | sed -e "s/^.*\"\(.*\)\".*/\1/") || name=" "
if [[ $name == " " ]] ; then 
	echo "The name cannot be recognized."
	exit 2
fi
echo "name:$name"
	
mast=$1
mast_name=$(basename "$name" r)
mast_name=$(basename "$mast_name" r)

timestamp=$(date "+%Y%m%d-%H%M%S")
out_fold="$outputs_folder$timestamp$mast_name/"
mkdir "$out_fold"
cd "$out_fold"
out_fold="$PWD/"
cd "$OLDPWD"
echo "$out_fold created"
if [[ -e "R" ]] ; then 
cp -r R "$out_fold"
fi
echo "initial out_fold: $out_fold"

# copy needed files
function copy_with_dep {
local current="$1"
echo coying $current
if [[ "$current" != "." ]] ; then
	echo "PWD: $PWD 1: $current  2: $2"
	local oldDir="$PWD"
	local newDir=$(dirname "$current")
	if [[ "$newDir" != "." ]] ; then
		local out_dir="$2$newDir/"
		echo "New out_dir:$out_dir"
		if [[ ! -e "$out_dir" ]] ; then
			echo "Making $out_dir"
			mkdir "$out_dir"
		fi
	else
		local out_dir="$2"
	fi
	echo "out_dir: $out_dir"
	cp "$current" "$out_dir"
	local extension="${1##*.}"
	if [[ $extension == "c" ]] ; then 
		local keywords_lines_to_get=$keywords_lines_to_get_C
		local language="c"
	elif [[ $extension == "R" || $extension == "r" ]] ; then  
		local keywords_lines_to_get=$keywords_lines_to_get_R
		local language="R"
	else
		local keywords_lines_to_get=""
	fi

	for keyword in $keywords_lines_to_get
	do
		echo "keyword: $keyword in $current"
		if [[ $language == "R" ]] ; then
			# list_files=$(grep "\<"$keyword"\>.*(" "$current" | grep -v -e "#.*"$keyword | sed -e "s/^.*\"\(.*\)\".*/\1/") || list_files=" "
			list_files=$(grep "\<"$keyword"\>.*(" "$current" | grep -v -e "#.*"$keyword | sed s/"#.*"//g | awk -F "\"" '{for (i=2;i<=NF;i+=2) print $i}')  || list_files=" "
		elif [[ $language == "c" ]] ; then 
			list_files=$(grep "$keyword" "$current" | grep -v -e "\/\/.*"$keyword | sed -e "s/^.*\"\(.*\)\".*/\1/") || list_files=" "
		fi
		echo "found files: $list_files" 
		if [[ $list_files != " " ]] ; then
		  echo Dealing with $list_files
			# echo cp --parents $list_files $2
			if [[ $newDir != "." ]] ; then
				echo "Moving to $newDir"
				cd "$newDir"
			fi
			for file in $list_files
			do
			  echo Dealing with $file
				if [[ -e $file ]] ; then 
				  echo Why not
					copy_with_dep "$file" "$out_dir"
				fi
				if [[ "${file##*.}" == "so" ]] ; then 
					source="${file%.*}.c"
					if [[ -e "$source" ]] ; then
						copy_with_dep "$source" "$out_dir"
					fi
				fi
			done
			echo back to $current
			cd "$oldDir"
		fi
	done
fi
return 
}
set -x
copy_with_dep "$mast" "$out_fold"
echo "come on"

# launch it
cd "$out_fold"
# R --interactive --save < $mast 
R CMD BATCH "$mast" output.lst
echo "$mast launched in $out_fold"

exit 0
