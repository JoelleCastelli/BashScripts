#!/bin/bash

# On déclare les constantes
declare -r ROOT_UID=0
declare -r SUCCESS=0
declare -r ERROR=13
declare -r NB_USERS=10

# On vérifie que l'utilisateur soit root
if [ $UID -ne $ROOT_UID ]
then
  echo "Vous devez être root pour lancer ce script !"
  exit $ERROR
fi  

i=1
while [ $i -le $NB_USERS ]
do
	# On génère un nom aléatoire qui sera également le mot de passe
	username=user$RANDOM
	password=$username

	# On vérifie si l'utilisateur existe déjà
	grep -q "$username" /etc/passwd
	if [ $? -eq $SUCCESS ] 
	then
		# Si oui : on recommence le processus sans incrémenter le compteur
		echo "$i - L'utilisateur $username existe déjà : génération d'un nouveau nom"
	else
		# Si non : on crée un utilisateur avec un répertoire personnel et sans mot de passe
		useradd -m -g users -s /bin/bash "$username"
		if [ $? -eq $SUCCESS ] 
			then
				echo -e "\n$i - Le compte de $username est créé !"

				# On set un mot de passe en renvoyant le prompt vers /dev/null pour ne pas polluer la console
				echo -e "$password\n$password" | passwd $username >& /dev/null

				# On génère aléatoirement le nombre de fichiers à créer
				nb_files=$((RANDOM%6+5))
				echo "On va créer $nb_files fichiers..."
				
				# Pour chaque fichier à créer
				for j in `seq 1 $nb_files`
				do
					# On définit le nom, l'utilité de taille et une taille aléatoire
					file_name=file$j
					size_unit=M
					file_size=$((RANDOM%46+5))

					# On alloue la mémoire nécessaire au fichier
					fallocate -l $file_size$size_unit /home/$username/$file_name
					if [ $? -eq $SUCCESS ] 
					then
						echo "Le fichier $file_name de $file_size Mo a été créé !"
					else
						echo "Aïe, problème dans la création du fichier $file_name :("
					fi
				done
			else
				echo -e "\nAïe, problème dans la création de l'utilisateur $username :("
		fi

		# On incrémente le compteur pour créer l'utilisateur suivant
		i=$(($i + 1))
	fi  
done

exit $SUCCESS