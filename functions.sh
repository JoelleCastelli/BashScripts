#!/bin/bash

get_readable_size()
(
    # On récupère la taille à "traduire" en paramètre
    nb_of_bytes=$1
    str=""
    units=(" octets" " Ko et " " Mo, " " Go, ")

    # On boucle de 3 à 0 (1024³ = Go, 1024² = Mo...)
    for j in {3..0}
    do
        # Division entière du nombre d'octets par 1024^$i
        unit_in_bytes=`echo "1024^$j" | bc`
        nb_of_units=$(($nb_of_bytes / $unit_in_bytes))

        # On concatène la chaîne vide avec "valeur_entiere unité_en_cours" (+ gestion du singulier)
        if [[ $j == 0 && $nb_of_units < 2 ]]
        then
            units[$j]=" octet"
        fi
        str=$str$nb_of_units${units[$j]};

        # On retire autant d'octets que la valeur trouvée (en octets)
        bytes_to_remove=$(($nb_of_units * $unit_in_bytes))
        nb_of_bytes=$(($nb_of_bytes - $bytes_to_remove))
    done

    # On renvoie la taille finale lisible
    echo $str
)