# Informazioni cartella
In questa cartella ci sono i seguenti file:
1. Dockerfile contenente l'immagine un container avente le seguenti caratteristiche: ha un webserver flask a cui viene inviato il messaggio del lavoro da eseguire (no-grafica); legge i file dal bucket; esegue il codice LCS, inserisce i risultati nel bucket e mette nella coda dei risultati il messaggio risultato.   
2. Cartella del webserver 