#!/bin/sh
# Base de données diffusion_ACPM.tsv
# Création et mise à jour à partir du site http://www.acpm.fr/

: <<'DOC'

	Mettre à jour le tableau de diffusion ACPM.
	
	Usage : 
		cd /la/ou/est/le/clone/data
		sh diffusion_ACPM.sh 
	
	Ce script utilise les commandes suivantes :
		- awk pour lire le fichier tsv
		- curl pour lire le site http://www.acpm.fr/
		- sed et grep pour extraire les données
		- comm et join pour enregistrer et mettre à jour le fichier diffusion_ACPM.tsv

DOC

# Préparer une liste d'urls à consulter.
# Lister les medias concernés : colonne 6 = GPE et colonne 3 = Média.
cat "../medias_francais.tsv" | awk -F "	" '
	$6 == "GPE" && $3 == "Média" {
 		 print $1 "	" $2 > "medias_acpm.tmp"
 	}
 
 '
medias=$(cat medias_acpm.tmp)
rm medias_acpm.tmp

# déduire l'url ACPM : http://www.acpm.fr/Support/xx-yy
echo "$medias" | while read media ; do	
	publication=$(echo "$media" | cut -d"	" -f2 | tr "A-Zéà É’," "a-zea\-e\--" | sed -e's/--*/-/g')
	echo "$media	http://www.acpm.fr/Support/$publication"  >> medias_acpm_urls.tmp
done

# Lire en ligne les données de diffusion de chaque média
echo "\nLecture des données en ligne...\n"

entete="periode	id	publication	url_ACPM	diffusion france payee	% diffusion france payee	diffusion totale	% diffusion totale"
echo "$entete"

cat medias_acpm_urls.tmp | while read media ; do
	page="" # recuperer l'url...
	id=$(echo "$media" | cut -d"	" -f1)
	publication=$(echo "$media" | cut -d"	" -f2)
	url=$(echo "$media" | cut -d"	" -f3)
	# urls_speciales à corriger
	url=$(echo "$url" | sed -e 's/vsd$/vsd-mensuel/g' -e's/&/et/g')
	
	# lire la page en ligne
	page=$(curl -s "$url")
	
	# prendre la partie qui nous interesse
	data=$(echo "$page" | tr "\n" " " | sed -e 's/^.*Résultats de diffusion//g' | grep -Eo '<div class="tendence-table">.*' | sed -e 's/<div class="section-support" id="historique">.*//g')
	# nettoyer des données
	data=$(echo "$data" | sed "s/ //g" | sed -e 's/<span[^>]*>//g' | tr "<" "\n" | grep -Eo "(^td|^ths).*" | sed "s/^.*>//g" | sed '/^$/d')
	
	# afficher les données
	annee=$(echo "$data" | sed -n 1p)
	diffusion_france_payee=$(echo "$data" | sed -n 4p)
	var_diffusion_france_payee=$(echo "$data" | sed -n 5p)
	diffusion_totale=$(echo "$data" | sed -n 7p)
	var_diffusion_totale=$(echo "$data" | sed -n 8p)
		
	echo "$annee	$id	$publication	$url	${diffusion_france_payee/ /}	${var_diffusion_france_payee/\%/}	${diffusion_totale/ /}	${var_diffusion_totale/\%/}"
	echo "$annee	$id	$publication	$url	${diffusion_france_payee/ /}	${var_diffusion_france_payee/\%/}	${diffusion_totale/ /}	${var_diffusion_totale/\%/}" >> diffusion_acpm.nouveau
done
rm medias_acpm_urls.tmp

# Enregistrer / mettre a jour les données dans un fichier diffusion_ACPM.tsv.


# Trier les nouvelles données
contenu=$(cat diffusion_acpm.nouveau | sort | uniq)
echo "$contenu" > diffusion_acpm.nouveau.tmp

if [ ! -f "diffusion_ACPM.tsv" ] # Créer le fichier ?
	then
		echo "création du fichier diffusion_ACPM.tsv"
		echo "$entete\n$contenu" > "diffusion_ACPM.tsv"
	else
		tail -n +2 diffusion_ACPM.tsv > diffusion_ACPM.tsv.tmp # Utiliser le fichier original sans entête
		
		# Mise à jour des données
				
		# Remplacer les lignes mofifiées en intégrant les valeurs du nouveau fichier.
		lignes_communes_mises_a_jour=$(join -12 -22 -t $'\t' -o 1.1,1.2,1.3,1.4,2.5,2.6,2.7,2.8 "diffusion_ACPM.tsv.tmp" "diffusion_ACPM.nouveau.tmp")
		echo "$lignes_communes_mises_a_jour" > maj.tmp
		
		# Ajouter les lignes de l'ancien fichier qui ont disparu dans le nouveau fichier et qui ne sont pas des lignes modifiées.
		lignes_enlevees=$(comm -1 -3 "diffusion_ACPM.nouveau.tmp" "diffusion_ACPM.tsv.tmp")
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
		
		# Ajouter les lignes arrivent par le nouveau fichier en qui ne sont pas dans l'ancien.
		lignes_ajoutees=$(comm -2 -3 "diffusion_ACPM.nouveau.tmp" "diffusion_ACPM.tsv.tmp")
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
		
		# Générer le tsv.
		cat maj.tmp | sort | uniq > diffusion_ACPM.tsv
		c=$(cat diffusion_ACPM.tsv)
		echo "$entete\n$c" > diffusion_ACPM.tsv
fi

# Afficher la base de donnée.
echo "\nDonnées enregistrées :\n"
cat diffusion_ACPM.tsv

[ -f "diffusion_ACPM.nouveau" ] && rm diffusion_ACPM.nouveau
rm *.tmp
