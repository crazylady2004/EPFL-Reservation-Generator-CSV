#!/bin/bash

# Exécute la requête MySQL et exporte le résultat au format CSV
mysql -u root -pmariadb123 -h 0.0.0.0 -e "
USE Reservation_EPFL;
SELECT obj.nom AS salle, 
       REPLACE(REPLACE(REPLACE(obj.descr, CHAR(10), '/'), CHAR(13), '/'), ',', '/') AS description, 
       COUNT(dates.date) AS nbr_res, 
       GROUP_CONCAT(DISTINCT users.sciper ORDER BY users.sciper SEPARATOR '; ') AS all_scipers 
FROM obj 
LEFT JOIN res ON obj.id = res.obj_id 
LEFT JOIN dates ON res.id = dates.res_id 
LEFT JOIN users ON obj.id = users.obj_id 
WHERE dates.date >= '2024-01-01' 
AND dates.date BETWEEN res.datedeb AND res.datefin 
GROUP BY obj.nom 
ORDER BY obj.nom;" | sed 's/\t/,/g' > /Users/dorer/sql2csv.csv

csv_file="/Users/dorer/sql2csv.csv"
output_file="/Users/dorer/add_mail2csv.csv"
first_line=true

get_email() {
    local sciper="$1"
    local email=$(ldapsearch -H ldap://ldap.epfl.ch -b 'o=epfl,c=ch' -LLL -x "(uniqueIdentifier=${sciper})" mail | grep "mail:" | cut -d' ' -f2 | sort -u)
    echo "$email"
}

while IFS=, read -r salle description nbr_res all_scipers; do
    IFS=';' read -ra scipers <<< "$all_scipers"
    emails=()

    for sciper in "${scipers[@]}"; do
        sciper=$(echo "$sciper" | xargs)
        mail=$(get_email "$sciper")

        if [ -n "$mail" ]; then
            emails+=("$mail")
        fi
    done

    emails_concatenated=$(IFS=\; ; echo "${emails[*]}")

    if [ "$first_line" = true ]; then
        echo "salle,description,nbr_res,all_scipers,emails_concatenated" > "$output_file"
        first_line=false
    fi

    echo "$salle,$description,$nbr_res,$all_scipers,$emails_concatenated" >> "$output_file"
done < "$csv_file"

