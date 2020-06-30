#!/bin/bash

# On déclare les constantes et on inclut le fichier de fonctions
declare -r TRUE=0
declare -r FALSE=1
declare -r ROOT_UID=0
declare -r SUCCESS=0
declare -r ERROR=13
source ./functions.sh

# On vérifie que l'utilisateur soit root
if [ $UID -ne $ROOT_UID ]
then
  echo "Vous devez être root pour lancer ce script !"
  exit $ERROR
fi

# On récupère les utilisateurs humains et leurs répertoires personnels
# humain =  UID supérieur ou égal à 1000 et username différent de "nobody"
usernames=(`awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd`)
folders=(`awk -F: '$3 >= 1000 && $1 != "nobody" {print $6}' /etc/passwd`)

# On crée un tableau "human_users" avec des valeurs au format "taille(octets):répertoire:username"
nb_folders=$((${#folders[*]} - 1))
for i in `seq 0 $nb_folders`
do
    human_users+=("`du -sb ${folders[$i]} | cut -f1`:${folders[$i]}:${usernames[$i]}")
done

# On les classe par ordre décroissant grâce au tri shaker
swapped=$TRUE
start=0
end=$((${#human_users[*]} - 2)) # -2 car on compare human_users[i] à human_users[i+1]
while [ $swapped -eq $TRUE ]
do
    swapped=$FALSE
    # Aller : recherche de la plus petite valeur
    for i in `seq $start $end`
    do
        # Si human_users[i] < human_users[i+1]
        value=`echo ${human_users[$i]} | cut -d: -f1`
        next_index=$(($i + 1))
        next_value=`echo ${human_users[$next_index]} | cut -d: -f1`
        if [ $value -lt $next_value ]
        then
            # On inverse les positions des valeurs
            temp=${human_users[$i]}
            human_users[$i]=${human_users[$next_index]}
            human_users[$next_index]=$temp
            swapped=$TRUE
        fi
    done
    # La valeur la plus petite est désormais au bout du tableau et n'a pas besoin d'être réévaluée
    # On décrémente la valeur de fin de la boucle pour optimiser le processus
    end=$(($end - 1))


    # Retour : recherche de la plus grande valeur
    for i in `seq $end -1 $start`
    do
        # Si human_users[i] < human_users[i+1]
        value=`echo ${human_users[$i]} | cut -d: -f1`
        next_index=$(($i + 1))
        next_value=`echo ${human_users[$next_index]} | cut -d: -f1`
        if [ $value -lt $next_value ]
        then
            # On inverse les positions des valeurs
            temp=${human_users[$i]}
            human_users[$i]=${human_users[$next_index]}
            human_users[$next_index]=$temp
            swapped=$TRUE
        fi
    done
    # La valeur la plus grande est désormais au début du tableau et n'a pas besoin d'être réévaluée
    # On incrémente la valeur du début de la boucle pour optimiser le processus
    start=$(($start + 1))
done


# On crée un nouveau module du message of the day auquel on donne les droits d'exécution
# On y écrit le résultat qu'on affiche aussi en console
motd_top5="/etc/update-motd.d/99-top5-disk-consumers"
echo "#!/bin/bash" > $motd_top5
chmod +x $motd_top5
echo 'echo -e "\e[36mLes plus gros consommateurs de disque sont :\e[0m"' >> $motd_top5
echo -e "\nLes plus gros consommateurs de disque sont :"

# S'il y plus de 5 utilisateurs, on fait un top 5
# Sinon, on affiche tous les utilisateurs
if [ ${#human_users[*]} -gt 5 ]
then
    end=4
else
    end=$((${#human_users[*]} - 1))
fi

# Pour chacun des plus gros consommateurs
for i in `seq 0 $end`
do
    # On récupère la taille du répertoire personnel en octets
    # grâce à la fonction get_readable_size qui retourne une chaîne de caractères
    folder_size_bytes=`echo ${human_users[$i]} | cut -d: -f1`
    folder_readable_size=`get_readable_size $folder_size_bytes`
    
    # On écrit sur le fichier du motd ainsi qu'en console
    username=`echo ${human_users[$i]} | cut -d: -f3`
    echo "echo -e '\e[36m- $username -> $folder_readable_size\e[0m'" >> $motd_top5
    echo "- $username -> $folder_readable_size"
done

echo -e "\nLe message d'accueil a été mis à jour !\n"


# On modifie le fichier bashrc de tous les utilisateurs humains
for j in "${human_users[@]}"
do
    # On localise le fichier bashrc
    repository=`echo $j | cut -d: -f2`
    filepath=$repository/.bashrc

    # On récupère la taille du répertoire personnel
    rep_size=`du -sb $repository | cut -f1`

    # On vérifie s'il existe déjà une règle sur le fichier
    grep -q "#Alerte : 100 Mo" $filepath
    if [ $? -eq $SUCCESS ] 
    then    
        # Si oui, on ne fait rien
        continue
    else
        # Sinon, on l'écrit dynamiquement dans le fichier
        readable_size=`get_readable_size $rep_size`

        # On affiche le commentaire qui identifie la présence de l'alerte
        echo -e "\n#Alerte : 100 Mo" >> $filepath
        # On récupère les variables utiles, dont la taille mise à jour à chaque ouverture du bashrc
        echo "repository=$repository" >> $filepath
        echo 'size=`du -sb $repository | cut -f1`' >> $filepath
        # Si la taille du répertoire est supérieure à 104857600 octets (100 Mo), une alerte s'affiche
        echo 'if [ $size -gt 104857600 ]' >> $filepath
        echo "then" >> $filepath
        echo "echo -e '\e[33mAlerte : vous avez dépassé la limite des 100 Mo !\e[0m'" >> $filepath
        echo "echo -e '\e[33mLa taille de votre répertoire est de $readable_size\e[0m'" >> $filepath
        echo "fi" >> $filepath

        username=`echo $j | cut -d: -f3`
        echo "Le fichier bashrc de $username a été mise à jour"
    fi
done

exit $SUCCESS