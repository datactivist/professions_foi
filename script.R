# scraping de https://programme-candidats.interieur.gouv.fr/

#boilerplate

library(readr)
library(rvest)
library(stringr)
library(rex)
library(multi)
library(tidyverse)

rex_mode()

circos <- read_csv("./circonscriptions.csv")

nom <- rex("\n", 
    spaces, 
    capture(name = "nom",
            something),
    ", ",
    capture(name = "prenom",
            something),
    newline)

# la fonction qui télécharge toutes les professions de foi pour une circo donnée

telecharger <- function(department, circo) {
  
    # les pages sont générées par du javascript, donc on ne peut les lire directement
    # on utilise phantom.js pour générer le html
  
    write_lines(paste0("// scrape_site.js\nvar webPage = require('webpage');\nvar page = webPage.create();\nvar fs = require('fs');\nvar path = 'temppage.html'\n\npage.open('", "https://programme-candidats.interieur.gouv.fr/elections/1/departments/", department, "/circonscriptions/", circo, "', function (status) {\nvar content = page.content;\nfs.write(path,content,'w')\nphantom.exit();\n});"), "./scrape_site.js", append = FALSE)
    
    system("phantomjs ./scrape_site.js")
    
    # ensuite on peut scraper classiquement
    
    page <- read_html("./temppage.html")
    candidat <- page %>% 
      html_nodes("#my-table .ng-scope .ng-binding:nth-child(1)") %>% 
      html_text() %>% 
      re_matches(nom) %>% 
      rename(nom_candidat = nom, prenom_candidat = prenom)
    suppleant <- page %>% 
      html_nodes("#my-table .ng-scope .ng-binding+ .ng-binding") %>% 
      html_text() %>% 
      re_matches(nom) %>% 
      rename(nom_suppleant = nom, prenom_suppleant = prenom)
    liens <- page %>% 
      html_nodes(".no-border:nth-child(1)") %>% 
      html_attr("href") %>% 
      as_tibble() %>% 
      rename(lien = value)
    df <- bind_cols(candidat, suppleant, liens)
    df <- df %>% 
      filter(!is.na(nom_candidat)) %>% 
      mutate(departement = str_pad(department, 3, "left", "0"),
             circonscription = str_pad(circo, 2, "left", "0"),
             code_circo = paste0(departement, circonscription))
    
    # on crée préventivement le dossier s'il n'existe pas
    
    dir.create(paste0(department, "/", circo, "/"), recursive = TRUE)
    
    # à passer en map !
    
    for (i in 1:nrow(df)) {
      
      # on télécharge effectivement les professions de foi
      
      downloader::download(paste0("https://programme-candidats.interieur.gouv.fr/", df$lien[i]), 
                           destfile = paste0(department, "/", circo, "/", df$nom_candidat[i], ".pdf"))
      # évitons de se faire kicker pour surcharge du serveur
      Sys.sleep(0.5)
    }
    df$path <- paste0("./", department, "/", circo, "/", df$nom_candidat, ".pdf")
    return(df)
}

safe_telecharger <- possibly(telecharger, otherwise = data_frame(nom_candidat = character(), prenom_candidat = character(), nom_suppleant = character(), prenom_suppleant = character(), departement = character(), circonscription = character(), code_circo = character()))

# il ne reste plus qu'à appeler la fonction pour chaque circo

professions_foi <- map2_df(
  circos$Département, 
  circos$Circonscription,
  ~ safe_telecharger(.x, .y)
)
