#!/bin/bash

declare -r ROOT_UID=0
declare -r SUCCESS=0
declare -r ERROR=13

# On vérifie que l'utilisateur soit root
if [ $UID -ne $ROOT_UID ]
then
  echo "Vous devez être root pour lancer ce script !"
  exit $ERROR
fi  

i=1
while [ $i -le 10 ]
	do
		username=user$RANDOM
		password=$username

		# On vérifie si l'utilisateur existe (q pour quiet : on n'affiche rien)
		grep -q "$username" /etc/passwd
		if [ $? -eq $SUCCESS ] 
		then	
			echo "$i - L'utilisateur $username existe déjà : génération d'un nouveau nom"
		else
			# On crée un utilisateur sans mot de passe
			# -m : crée un répertoire personnel
			# -g users : met dans le groupe users
			# -s /bin/bash : spécifie le shell bash par défaut pour le user
			useradd -m -g users -s /bin/bash "$username"
			if [ $? -eq $SUCCESS ] 
				then
					echo "$i - Le compte de $username est créé !"
				else
					echo "Aïe, problème dans la création de l'utilisateur $username :("
			fi

			# On set un mot de passe (-e interprète les caractères échapés)
			# On renvoie le prompt vers /dev/null pour ne pas polluer la console
			echo -e "$password\n$password" | passwd $username >& /dev/null

			# On crée les fichiers
			nb_files=$((RANDOM%6+5))
			echo "On va créer $nb_files fichiers..."
			
			for j in `seq 1 $nb_files`
				do
					file_name=file$j
					size_unit=M
					file_size=$((RANDOM%46+5))

					# On copie de /dev/random vers la cible et on écrit un bloc de la taille random
					# On renvoie vers /dev/null pour ne pas polluer la console
					#dd if=/dev/urandom of=/home/$username/$file_name bs=$file_size$size_unit count=1 >& /dev/null
					fallocate -l $file_size$size_unit /home/$username/$file_name
					if [ $? -eq $SUCCESS ] 
					then
						echo "Le fichier $file_name de $file_size Mo a été créé !"
					else
						echo "Aïe, problème dans la création du fichier $file_name :("
					fi
				done
			echo " "

			# On passe à la création du prochain utilisateur
			i=$(($i + 1))
		fi  
	done
exit 0