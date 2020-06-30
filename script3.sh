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

# On initialise les variables utiles et de mise en forme
list1=/home/suid_guid_exe
list2=/home/list2
zone="."
format="%i:%a"
bold=$(tput bold)
normal=$(tput sgr0)

# On récupère les exécutables avec une autorisation au moins égale
# à 2000 ou 4000 au format "inode:permissions(octal)"
# On trie la liste, retire les doublons et stocke le résultat dans un fichier list2
find $zone \( -perm -2000 -o -perm -4000 \) -exec stat --format $format {} ';' 2> /dev/null | sort -n -u > $list2

# On vérifie s'il existe déjà un fichier list1 pour comparer les données
if [ -f $list1 ]
then
    # Si le fichier existe : on compare les listes bit à bit
    cmp -s $list1 $list2
    if [ $? -eq $SUCCESS ]
    then
        echo -e "\nLes listes de fichiers sont identiques : aucune modification n'a été réalisée.\n"
    else
        # Si les listes sont différentes : on met les fichiers trouvés dans un tableau
        tab_list2=(`awk '{print $1}' $list2`)

        # On boucle sur tous les fichiers trouvés
        for i in "${tab_list2[@]}"
        do
            # On récupère les informations utiles
            id="`echo $i | cut -d: -f1`"
            current_rights="`echo $i | cut -d: -f2`"
                
            if grep -q "$i:$current_rights" $list1
            then
                # Si l'inode et les droits sont exactement les mêmes que dans la liste 1
                # Le fichier n'a pas été modifié : on retire la ligne de la liste 1
                sed -i "/^$id/d" $list1
            elif grep -q "^$id:" $list1
            then
                # Si l'inode est trouvé mais que les droits sont différents
                # On récupère le(s) nom(s) de fichier(s) associé(s) à l'inode et la date de dernière modification
                # On stocke le résultat dans une chaîne de caractères
                names=(`find $zone -inum $id`)
                file=`grep "^$id:" $list1`
                previous_rights=`echo $file | cut -d: -f2`
                for name in "${names[@]}"
                do
                    date="`date -r $name`"
                    updated_files="$updated_files$name"
                    updated_files="$updated_files\nDernière modification : $date"
                    updated_files="$updated_files\nDroits précédents : $previous_rights - Droits actuels : $current_rights\n"
                done
                # On retire la ligne de la liste 1
                sed -i "/^$id:/d" $list1
            else
                # Si l'inode n'a pas été trouvé dans la liste 1 : le fichier a gagné un droit SUID ou GUID
                # On récupère le(s) nom(s) de fichier(s) associé(s) à l'inode et la date de dernière modification
                # On stocke le résultat dans une chaîne de caractères
                names=(`find $zone -inum $id`)
                for name in "${names[@]}"
                do
                    date="`date -r $name`"
                    new_files="$new_files$name"
                    new_files="$new_files\nDernière modification : $date"
                    new_files="$new_files\nDroits actuels : $current_rights\n"
                done
            fi
        done

        # Si la liste initiale n'est pas vide : on récupère la liste des fichiers restant
        [ -s $file1 ]
        if [ $? -eq $SUCCESS ] 
        then
            # On boucle sur chaque ligne du fichier
            for j in `cat $list1`
            do
                # On récupère l'inode, les droits précédents et le(s) nom(s) de fichier(s) associé(s) à l'inode
                id="`echo $j | cut -d: -f1`"
                previous_rights="`echo $j | cut -d: -f2`"
                names=(`find $zone -inum $id`)
                for name in "${names[@]}"
                do
                    # Pour chaque nom de fichier, on stocke les informations dans une chaîne de caractères
                    date="`date -r $name`"
                    current_rights=`stat $name --format "%a"`
                    deleted_files="$deleted_files$name"
                    deleted_files="$deleted_files\nDernière modification : $date"
                    deleted_files="$deleted_files\nDroits précédents : $previous_rights - Droits actuels : $current_rights\n"
                done
            done
        fi

        # Si la chaîne new_files n'est pas vide : on affiche la liste des fichiers
        [ -n "$new_files" ]
        if [ $? -eq $SUCCESS ] 
        then
            echo -e "\e[92m\n${bold}Fichiers qui ont gagné un droit SUID et/ou GUID :${normal}\e[0m"
            echo -e $new_files
        fi

        # Si la chaîne updated_files n'est pas vide : on affiche la liste des fichiers
        [ -n "$updated_files" ]
        if [ $? -eq $SUCCESS ] 
        then
            echo -e "\e[93m\n${bold}Fichiers modifiés :${normal}\e[0m"
            echo -e $updated_files
        fi
        
        # Si la chaîne deleted_files n'est pas vide : on affiche la liste des fichiers
        [ -n "$deleted_files" ]
        if [ $? -eq $SUCCESS ] 
        then
            echo -e "\e[91m\n${bold}Fichiers qui ont perdu un droit SUID et/ou GUID :${normal}\e[0m"
            echo -e $deleted_files
        fi

        # Les nouvelles données deviennent la liste de référence
        cp $list2 $list1
        if [ $? -eq $SUCCESS ] 
        then    
            echo -e "La liste de référence a été mise à jour !\n"
        else
            echo -e "Aïe, problème dans la mise à jour de la liste de référence :(\n"
        fi
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

# On supprime le fichier list2
rm $list2