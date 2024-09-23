#!/bin/bash

############################## ap2md ##################################
# Copyright (C) 2024 Dominik Rzecki

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################

function find_page () {
	REGEX_START_PAGE_s="^([[:digit:]]+)"

	page=$(pdfgrep -n -e "$1" $2) 

	if [[ $page =~ $REGEX_START_PAGE_s ]]
	then
		echo $((${BASH_REMATCH[1]}))
	else
		>&2 echo "ERROR: Could not find starting/ending page of course list"
		exit 1
	fi
}

REGEX_ECTS_s='(\([[:alnum:], ]* ECTS\))'
REGEX_START_s='Prüfungsfächer und zugehörige Module'
REGEX_END_s='Kurzbeschreibung der Module'

programme=$(sed 's/.pdf//g' <<< $1)

if [ -d "$programme" ]; then
    rm -r $programme;
fi
mkdir $programme

start_page=$(find_page "$REGEX_START_s" $1)
end_page=$(find_page "$REGEX_END_s" $1)

str=$(pdftotext -enc UTF-8 -f $start_page -l $end_page $1 -)

str=$(sed '/^[^[:alpha:]+*\f]*$/d' <<< "$str")
str=$(sed 's/\f//g' <<< "$str")

start_line=$(($(grep -n -m 1 -e "$REGEX_ECTS_s" <<<"$str" | cut -f1 -d:) - 1))
end_line=$(($(grep -n -m 1 -e "$REGEX_END_s" <<<"$str" | cut -f1 -d:) - 1))

str=$(sed -n "${start_line},${end_line}p" <<< "$str")

str=$(awk "BEGIN {
		subject=\"\";
		subject_ects=0;
		total_ects=0;
		subject_index_path=\"\";
		
		system(\"echo '---\nECTS: #\n---' >> '$programme/$programme.md'\")	
		}
	{
		if(\$0 !~ /$REGEX_ECTS_s/) {
			subject = \$0;
			subject_ects = 0;
			subject_index_path = \"$programme/\" subject \"/\" subject \" (Index).md\"; 
			
			system(\"mkdir '$programme/\" subject \"'\");
			system(\"echo '---\nECTS: #\n---' >> '\" subject_index_path \"'\")

			system(\"echo '[[\"subject\" (Index)]]' >> '$programme/$programme.md'\")
		} else {
			course = \$0;

			ects = substr(course,  match(course, /$REGEX_ECTS_s/) );
			gsub(/[^[:digit:],]/, \"\", ects);
			gsub(/,/, \".\", ects);
			
			subject_ects += ects;
			total_ects += ects;

			gsub(/+|*| ?$REGEX_ECTS_s/, \"\", course);

			system(\"mkdir '$programme/\" subject \"/\" course \"'\");	
			path = \"$programme/\" subject \"/\" course \"/\" course \".md\"; 
			system(\"echo '---\nECTS: \"ects\"\n---' >> '\" path \"'\");
			
			system(\"sed -i 's/ECTS:[[:alnum:]. #]*$/ECTS: \"subject_ects\"/' '\" subject_index_path \"'\")
			system(\"echo '[[\"course\"]]' >> '\" subject_index_path \"'\")
		}
	} END {
		system(\"sed -i 's/ECTS:[[:alnum:]. #]*$/ECTS: \"total_ects\"/' '$programme/$programme.md'\")
	}" <<< "$str")

printf "Markdown structure for \033[32;1m$programme\033[0m created successfully!\nHave fun @ \033[34;1mTU Wien\033[0m!\n"
