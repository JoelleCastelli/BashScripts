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

# On initialise les variables utiles
list1=/home/suid_guid_exe
list2=/home/list2
zone="."
format="%i:%a"

# On récupère les exécutables avec une autorisation au moins égale à 2000 ou 4000
# On récupère les fichiers au format "inode:permissions(octal):nom"
# On trie le fichier et stocke le résultat dans un fichir list2
find $zone \( -perm -2000 -o -perm -4000 \) -exec stat --format $format {} ';' 2> /dev/null | sort -n > $list2

# On vérifie s'il existe déjà un fichier list1 pour comparer les données
if [ -f $list1 ]
then
    # Si le fichier existe : on compare les listes bit à bit
    cmp -s $list1 $list2
    if [ $? -eq $SUCCESS ]
    then
        echo -e "\nLes listes de fichiers sont identiques : aucune modification n'a été réalisée.\n"
    else
        # On met la liste des fichiers trouvés dans un tableau
        tab_list2=(`awk '{print $1}' $list2`)

        # On boucle sur tous les fichiers trouvés
        for i in "${tab_list2[@]}"
        do
            # On récupère les informations utiles
            id="`echo $i | cut -d: -f1`"
            rights="`echo $i | cut -d: -f2`"
                
            if grep -q "$i:$rights" $list1
            then
                # Si l'inode et les droits sont exactement les mêmes que dans la liste 1 :
                # Le fichier n'a pas été modifié : on retire la ligne de la liste 1
                sed -i "/^$id/d" $list1
            elif grep -q "^$id:" $list1
            then
                # Si l'inode est trouvé mais que les droits sont différents :
                # On récupère le(s) nom(s) de fichier(s) associé(s) à l'inode et la date de dernière modification
                # On stocke le résultat dans une chaîne de caractères
                names=(`find $zone -inum $id`)
                for name in "${names[@]}"
                do
                    date="`date -r $name`"
                    updated_files="$updated_files$name -> Dernière modification : $date\n"
                done
                # On retire la ligne de la liste 1
                sed -i "/^$id:/d" $list1
            else
                # Si l'inode n'a pas été trouvé dans la liste 1 :
                # Le fichier a gagné un droit SUID ou GUID
                # On récupère le(s) nom(s) de fichier(s) associé(s) à l'inode et la date de dernière modification
                # On stocke le résultat dans une chaîne de caractères
                names=(`find $zone -inum $id`)
                for name in "${names[@]}"
                do
                    date="`date -r $name`"
                    new_files="$new_files$name -> Dernière modification : $date\n"
                done
            fi
        done

        # Si la chaîne updated_files n'est pas vide : on affiche la liste des fichiers
        [ -n "$updated_files" ]
        if [ $? -eq $SUCCESS ] 
        then
            echo -e "\e[93m Fichiers modifiés :\e[0m"
            echo -e $updated_files
        fi

        # Si la chaîne new_files n'est pas vide : on affiche la liste des fichiers
        [ -n "$new_files" ]
        if [ $? -eq $SUCCESS ] 
        then
            echo -e "\e[92m Fichiers qui ont gagné un droit SUID et/ou GUID :\e[0m"
            echo -e $new_files
        fi

        # Si la liste initiale n'est pas vide : on affiche la liste des fichiers restant
        [ -s $file1 ]
        if [ $? -ne $SUCCESS ] 
        then    
            echo -e "\e[91m Fichiers qui ont perdu un droit SUID et/ou GUID :\e[0m"
            for j in `cat $list1`
            do
                id="`echo $j | cut -d: -f1`"
                names=(`find $zone -inum $id`)
                for name in "${names[@]}"
                do
                    date="`date -r $name`"
                    echo "$name -> Dernière modification : $date\n"
                done
            done
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