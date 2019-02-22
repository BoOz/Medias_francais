#!/bin/sh
# Base de données diffusion ACPM
# Création et mise à jour à partir du site http://www.acpm.fr/

: <<'DOC'

	Mettre à jour le tableau de diffusion ACPM.
	
	Usage : 
		cd /la/ou/est/le/clone/data
		sh diffusion_ACPM.sh 
	
	Ce script utilise les commandes suivantes :
		- awk pour lire le fichier tsv
		- curl pour lire le site http://www.acpm.fr/
		- comm et join pour enregistrer et mettre à jour les données dans un fichier tsv

DOC

echo "\n*** Calcul de la diffusion ACPM ***\n\n"

# Préparer une liste d'urls à consulter.

# Lister les medias concernés.
# Colonne 6 = GPE et colonne 3 = Média.

cat "../medias_francais.tsv" | awk -F "	" '

	$6 == "GPE" && $3 == "Média" {
 		 print $1 "	" $2 > "medias_acpm.tmp"
 	}
 
 '
 
medias=$(cat medias_acpm.tmp)

# déduire l'url ACPM : http://www.acpm.fr/Support/xx-yy
echo "$medias" | while read media ; do	
	publication=$(echo "$media" | cut -d"	" -f2 | tr "A-Zéà É’," "a-zea\-e\--" | sed -e's/--*/-/g')
	echo "$media	http://www.acpm.fr/Support/$publication"  >> medias_acpm_urls.tmp
done
rm medias_acpm.tmp


# Lire en ligne les données de diffusion de chaque média
entete="Période	id	publication	url_ACPM	diffusion france payee	% diffusion france payee	diffusion totale	% diffusion totale"
echo "$entete"

cat medias_acpm_urls.tmp | while read media ; do
	page=""
	
	# recuperer l'url...
	id=$(echo "$media" | cut -d"	" -f1)
	publication=$(echo "$media" | cut -d"	" -f2)
	url=$(echo "$media" | cut -d"	" -f3)
	# urls_speciales
	url=$(echo "$url" | sed -e 's/vsd$/vsd-mensuel/g' -e's/&/et/g')
	
	# lire la page
	page=$(curl -s "$url")
	# prendre la partie qui nous interesse
	data=$(echo "$page" | tr "\n" " " | sed -e 's/^.*Résultats de diffusion//g' | grep -Eo '<div class="tendence-table">.*' | sed -e 's/<div class="section-support" id="historique">.*//g')
	# nettoyage des données
	data=$(echo "$data" | sed "s/ //g" | sed -e 's/<span[^>]*>//g' | tr "<" "\n" | grep -Eo "(^td|^ths).*" | sed "s/^.*>//g" | sed '/^$/d')
	
	annee=$(echo "$data" | sed -n 1p)
	diffusion_france_payee=$(echo "$data" | sed -n 4p)
	var_diffusion_france_payee=$(echo "$data" | sed -n 5p)
	diffusion_totale=$(echo "$data" | sed -n 7p)
	var_diffusion_totale=$(echo "$data" | sed -n 8p)
	
	echo "$annee	$id	$publication	$url	$diffusion_france_payee	$var_diffusion_france_payee	$diffusion_totale	$var_diffusion_totale"
	echo "$annee	$id	$publication	$url	$diffusion_france_payee	$var_diffusion_france_payee	$diffusion_totale	$var_diffusion_totale" >> diffusion_acpm.nouveau

done
rm medias_acpm_urls.tmp

# Enregistrer / mettre a jour les données dans un fichier diffusion_acpm.txt.

# trier le nouveau fichier
contenu=$(cat diffusion_acpm.nouveau | sort | uniq)
echo "$contenu" > diffusion_acpm.nouveau.tmp

# y'a t'il un fichier existant ?
if [ ! -f "diffusion_acpm.txt" ]
	then
		echo "création du fichier diffusion_ACPM.txt"
		echo "$entete\n$contenu" > "diffusion_ACPM.txt"
	else
		# fichier original sans entete
		tail -n +2 diffusion_ACPM.txt > diffusion_ACPM.txt.tmp
		
		# Mise à jour des données
				
		# remplacer les lignes mofifiées avec les valeur du nouveau fichier.
		lignes_communes_mises_a_jour=$(join -12 -22 -t $'\t' -o 1.1,1.2,1.3,1.4,2.5,2.6,2.7,2.8 "diffusion_ACPM.txt.tmp" "diffusion_ACPM.nouveau.tmp")
		echo "$lignes_communes_mises_a_jour" > maj.tmp
		
		# ajouter les lignes disparues dans le nouveau (pellerin) si pas deja de ligne dans le fichier.
		lignes_enlevees=$(comm -1 -3 "diffusion_ACPM.nouveau.tmp" "diffusion_ACPM.txt.tmp")
		echo "$lignes_enlevees" | while read l ; do
			periode=$(echo "$l" | cut -f1)
			id=$(echo "$l" | cut -f2)
			# a t'on déja cette ligne ?
			ligne=$(cat maj.tmp | grep -Eo "^$periode	$id.*")
			if (( ${#ligne} == 0 ))
				then
					echo "$l" >> maj.tmp
			fi
		done
		
		# ajouter les lignes nouvelles.
		# dans le  nouveau fichier mais pas l'ancien (lol magazine).
		lignes_ajoutees=$(comm -2 -3 "diffusion_ACPM.nouveau.tmp" "diffusion_ACPM.txt.tmp")
		echo "$lignes_ajoutees" | while read l ; do
			periode=$(echo "$l" | cut -f1)
			id=$(echo "$l" | cut -f2)
			# a t'on déja cette ligne ?
			ligne=$(cat maj.tmp | grep -Eo "^$periode	$id.*")
			if (( ${#ligne} == 0 ))
				then
					echo "$l" >> maj.tmp
			fi
		done
		
		cat maj.tmp | sort | uniq > diffusion_ACPM.txt
		# remettre l'entete
		c=$(cat diffusion_ACPM.txt)
		echo "$entete\n$c" > diffusion_ACPM.txt
fi

[ -f "diffusion_ACPM.nouveau" ] && rm diffusion_ACPM.nouveau
rm *.tmp

echo "";
