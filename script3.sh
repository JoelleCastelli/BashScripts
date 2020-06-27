#!/bin/bash

declare -r SUCCESS=0
declare -r ROOT_UID=0
declare -r ERROR=13

# On vérifie que l'utilisateur soit root
if [ $UID -ne $ROOT_UID ]
then
  echo "Vous devez être root pour lancer ce script !"
  exec sudo bash "$0" "$@"
fi   

list1=/home/list1
list2=/home/list2

# On récupère les exécutables avec une autorisation au moins égale à 2000 ou 4000
# SGID = perm -2000, SUID = perm -4000, les deux = perm -6000
# On récupère les fichiers au format "inode:permission:nom"
# On trie le fichier et stocke le résultat dans un fichier list2
find / \( -perm -2000 -o -perm -4000 \) -exec stat --format '%i:%n' {} ';' 2> /dev/null | sort -n > $list2

# On vérifie s'il existe déjà un fichier list1 pour comparer les données
if [ -f $list1 ]
then
    # Si le fichier existe : on compare les listes bit à bit
    cmp -s $list1 $list2
    if [ $? -eq $SUCCESS ]
    then
        echo -e "\nLes listes de fichiers sont identiques : aucune modification n'a été réalisée.\n"
    else
        echo -e "\nIl existe des différences entre les listes de fichiers :"
        # 6 cas possibles
            #   - ceux qui ont gagné un droit SUID ou GUID
            #   - ceux qui n'ont plus aucune droit SUID ou GUID
            #   - ceux qui étaient SUID et sont devenus SUID  + GUID
            #   - ceux qui étaient SUID et sont devenus GUID
            #   - ceux qui étaient GUID et sont devenus SUID  + GUID
            #   - ceux qui étaient GUID et sont devenus SUID

        # 3 méthodes
         #diff $list1 $list2 > /home/diff_list
        # On grep l'ID pourr voir s'il était déjà dans le fichier 1
        # Si oui : modifié
        # Si non : apparu

        # Fichiers uniquement dans la liste 1
        lost_rights=(`comm -23 $list1 $list2`)
        if [ ${#lost_rights[*]} -gt 0 ]
        then
            echo ${#lost_rights[*]}
            echo -e "\n\e[91mFichiers qui ont perdu leurs droits SUID et/ou GUID :\e[0m"
            lost_rights=(`comm -23 $list1 $list2`)
            for i in ${lost_rights[@]}
            do
                name="`echo $i | cut -d: -f2`"
                date="`stat --format %y $name`"
                str=$name" -> Dernière modification : "$date
                echo $str
            done
        fi

        # Fichiers uniquement dans la liste 2
        new_rights=(`comm -13 $list1 $list2`)
        if [ ${#new_rights[*]} -gt 0 ]
        then
            echo -e "\n\e[92mFichiers qui ont gagné leurs droits SUID et/ou GUID :\e[0m"
            
            for i in ${new_rights[@]}
            do
                name="`echo $i | cut -d: -f2`"
                date="`stat --format %y $name`"
                str=$name" -> Dernière modification : "$date
                echo $str
            done
        fi
        echo -e "\n"

    fi    
else 
    # Si le fichier n'existe pas : on le crée à partir des données récupérées
    echo -e "\nIl n'existe pas de liste permettant de comparer les informations."
    echo "Création de la liste de référence en cours..."
    cp $list2 $list1
    if [ $? -eq $SUCCESS ] 
    then    
        echo -e "La liste de référence a été créée !\n"
    else
        echo -e "Aïe, problème dans la création de la liste de référence :(\n"
    fi
fi

# Une fois fini : liste 2 devient la liste 1 de référence
#cp $list2 $list1