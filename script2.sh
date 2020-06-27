#!/bin/bash

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
  exec sudo bash "$0" "$@"
#  exit $ERROR
fi  


# On récupère les usernames humains : uid >= 1000 et username != "nobody"
usernames=(`awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd`)
# On récupère leurs répertoires personnels
folders=(`awk -F: '$3 >= 1000 && $1 != "nobody" {print $6}' /etc/passwd`)

# On crée un tableau avec le format "taille(octets):répertoire:username"
end=$((${#folders[*]} - 1))
for i in `seq 0 $end`
do
    human_users+=("`du -sb ${folders[$i]} | cut -f1`:${folders[$i]}:${usernames[$i]}")
done


# On les classe par ordre décroissant grâce au tri shaker
swapped=$TRUE
start=0
end=$((${#human_users[*]} -2))
while [ $swapped -eq $TRUE ]
do
    swapped=$FALSE
    #Aller
    for i in `seq $start $end`
    do
        value=`echo ${human_users[$i]} | cut -d: -f1`
        next_index=$(($i + 1))
        next_value=`echo ${human_users[$next_index]} | cut -d: -f1`
        if [ $value -lt $next_value ]
        then
            # On swappe
            temp=${human_users[$i]}
            human_users[$i]=${human_users[$next_index]}
            human_users[$next_index]=$temp
            swapped=$TRUE
        fi
    done
    end=$(($end - 1)) #=> devrait fonctionner pour optimiser...


    # Retour
    for i in `seq $end -1 $start`
    do
        value=`echo ${human_users[$i]} | cut -d: -f1`
        next_index=$(($i + 1))
        next_value=`echo ${human_users[$next_index]} | cut -d: -f1`
        if [ $value -lt $next_value ]
        then
            # On swappe
            temp=${human_users[$i]}
            human_users[$i]=${human_users[$next_index]}
            human_users[$next_index]=$temp
            swapped=$TRUE
        fi
    done
    start=$(($start + 1)) #=> devrait fonctionner pour optimiser...
done


# On update le motd et on affiche en console
echo "#!/bin/bash" > /etc/update-motd.d/99-top5-disk-consumers
echo 'echo -e "\e[36mLes plus gros consommateurs de disque sont :\e[0m"' >> /etc/update-motd.d/99-top5-disk-consumers
echo -e "\nLes plus gros consommateurs de disque sont :"

# S'il y plus de 5 utilisateurs, on fait un top 5
# Sinon, on affiche tous les utilisateurs
if [ ${#human_users[*]} -gt 5 ]
then
    end=4
else
    end=$((${#human_users[*]} - 1))
fi

for i in `seq 0 $end`
do
    # On récupère la taille du répertoire personnel en octets
    nb_of_bytes=`echo ${human_users[$i]} | cut -d: -f1`
    readable_size=$(get_readable_size $nb_of_bytes)
    
    # Affichage en console et écriture sur le fichier
    username=`echo ${human_users[$i]} | cut -d: -f3`
    echo "echo -e '\e[36m- $username -> $readable_size\e[0m'" >> /etc/update-motd.d/99-top5-disk-consumers
    echo "- $username -> $readable_size"
done

echo -e "\nLe message d'accueil a été mis à jour !\n"


# On modifie le fichier bashrc de tous les utilisateurs humains
for j in "${human_users[@]}"
do
    # On localise le fichier bashrc
    repository=`echo $j | cut -d: -f2`
    filepath=$repository/.bashrc

    # On récupère la taille du répertoire personnel et on définit la taille limite en octets
    rep_size=`du -sb $repository | cut -f1`
    max_size=104857600

    # On vérifie s'il existe déjà une règle sur le fichier
    grep -q "#Alerte : 100 Mo" $filepath
    if [ $? -eq $SUCCESS ] 
    then    
        # Si oui, on ne fait rien
        continue
    else
        # Sinon, on l'écrit
        readable_size=$(get_readable_size $rep_size)
        echo -e "\n#Alerte : 100 Mo" >> $filepath
        echo "if [ $rep_size -gt $max_size ]" >> $filepath
        echo "then" >> $filepath
        echo "echo -e '\e[33mAlerte : vous avez dépassé la limite des 100 Mo !\e[0m'" >> $filepath
        echo "echo -e '\e[33mLa taille de votre répertoire est de $readable_size\e[0m'" >> $filepath
        echo "fi" >> $filepath
    fi
done


exit 0