# ELT proces datasetu Australian Transport Infrastructure
Tento repozitár predstavuje implementáciu ELT procesu v Snowflake pre analýzu dopravnej infraštruktúry Austrálie.
Projekt využíva dáta o cestnej sieti, železniciach a obslužných staniciach (čerpacie a nabíjacie stanice). 
Výsledný dátový sklad je navrhnutý podľa architektúry **Star Schema**, čo umožňuje efektívnu multidimenzionálnu analýzu technických parametrov a regionálnej dostupnosti infraštruktúry.

## 1. Úvod a popis zdrojových dát
Cieľom analýzy je preskúmať konektivitu a vybavenosť austrálskych štátov dopravnými prvkami. Zameriavame sa na:
* **Kvalitu cestnej siete:** Analýza rýchlostných limitov a počtu jazdných pruhov.
* **Dostupnosť paliva:** Porovnanie tradičných čerpacích staníc s modernými nabíjacími bodmi pre elektromobily (EV).
* **Železničnú infraštruktúru:** Prehľad staníc a tratí v jednotlivých jurisdikciách.
* **Regionálne rozdiely:** Porovnanie technických parametrov ciest medzi štátmi.

### Zdrojové dáta
Dáta pochádzajú z otvorených zdrojov (Geoscience Australia a OpenStreetMap) dostupných cez Snowflake Marketplace. Dataset obsahuje päť hlavných staging tabuliek:
* `STG_GA_NATIONAL_ROADS` – informácie o národných cestách.
* `STG_GA_PETROL_STATIONS` – poloha a vlastníci čerpacích staníc.
* `STG_OSM_EV_CHARGERS` – údaje o nabíjacích staniciach pre elektromobily.
* `STG_GA_RAILWAY_LINES` – metadata o železničných tratiach.
* `STG_GA_RAILWAY_STATIONS` – zoznam železničných staníc.
## 1.1 ERD diagram
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na entitno-relačnom diagrame (ERD):
<img width="1289" height="1033" alt="schema" src="https://github.com/user-attachments/assets/a758f05f-529b-46de-af75-1935be34c10c" />
