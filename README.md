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
### 1.1 ERD diagram
Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na entitno-relačnom diagrame (ERD):
<img width="1289" height="1033" alt="schema" src="https://github.com/user-attachments/assets/a758f05f-529b-46de-af75-1935be34c10c" />

## 2. Dimenzionálny model
V projekte bola navrhnutá schéma hviezdy (star schema), ktorá obsahuje 1 tabuľku faktov fact_transport_infrastructure prepojenú so 6 dimenziami:
* `dim_state:` Číselník štátov Austrálie (kód štátu a celý názov).
* `dim_location:` Geografické údaje zahŕňajúce názvy predmestí a PSČ.
* `dim_road_info:` Technické atribúty ciest (hierarchia, názov ulice, povrch).
* `dim_station_info:` Informácie o obslužných staniciach (názov, operátor, typ paliva).
* `dim_infrastructure_type:` Kategorizácia typov (Cesta, Železnica, Služba).
* `dim_date:` Časová dimenzia (deň, mesiac, rok, štvrťrok).
Štruktúra hviezdicového modelu je znázornená na diagrame nižšie:
<img width="867" height="859" alt="Star schema" src="https://github.com/user-attachments/assets/aad09f55-b9c7-41ec-8e38-3a8f04358be9" />


## 3. ELT proces v Snowflake
ELT proces pozostával z troch hlavných fáz: extrahovanie (Extract), načítanie (Load) a transformácia (Transform). Tento proces bol implementovaný priamo v Snowflake, kde sme využili zdieľaný dataset (Data Sharing) na vytvorenie viacdimenzionálneho modelu pre analýzu infraštruktúry.
### 3.1 Extract (Extrahovanie dát)
V tomto projekte dátu neimportoval z externých .csv súborov, ale využil dátu dostupné v Snowflake Marketplace. Zdrojový dataset s názvom TRANSPORT__LINES_AND_FIXTURES__AUSTRALIA__FREE obsahuje komplexné priestorové údaje o doprave v Austrálii.

#### Príklad kódu:

```sql
use warehouse chipmunk_wh;
use database chipmunk_db;
create schema if not exists chipmunk_lab11;
use schema chipmunk_lab11;
```

### 3.3 Transform (Transformácia dát)

V tejto fáze boli dáta zo staging tabuliek vyčistené, transformované a obohatené o analytické výpočty. Hlavným cieľom bolo vytvorenie hviezdicovej schémy.
Dimenzie boli navrhnuté tak, aby poskytovali geografický a technický kontext. Napríklad DIM_STATE transformuje skratky štátov na ich plné názvy pomocou podmienky CASE. Z hľadiska SCD ide o SCD Typ 0 (statické údaje).

####Príklad kódu:
```sql
CREATE OR REPLACE TABLE DIM_STATE AS
SELECT ROW_NUMBER() OVER (ORDER BY state_code) AS idDIM_STATE,state_code,
CASE 
WHEN state_code = 'NSW' THEN 'New South Wales'
WHEN state_code = 'VIC' THEN 'Victoria'
WHEN state_code = 'QLD' THEN 'Queensland'
WHEN state_code = 'WA' THEN 'Western Australia'
WHEN state_code = 'SA' THEN 'South Australia'
WHEN state_code = 'TAS' THEN 'Tasmania'
WHEN state_code = 'ACT' THEN 'Australian Capital Territory'
WHEN state_code = 'NT' THEN 'Northern Territory'
ELSE 'Unknown'
END AS state_name
FROM (SELECT DISTINCT STATION_STATE AS state_code FROM STG_GA_PETROL_STATIONS);
```
 #### Faktová tabuľka:
 FACT_TRANSPORT_INFRASTRUCTURE spája metriky (počet pruhov, rýchlosť, dĺžka) s dimenziami. Do tejto tabuľky sme implementovali okenné funkcie pre pokročilú analýzu:
* `RANK():` Určuje poradie dĺžky cesty v rámci každého štátu.
* `AVG() OVER():` Vypočítava priemernú rýchlosť pre celú kategóriu cesty bez agregácie riadkov.
  
#### Príklad kódu:
```sql
CREATE OR REPLACE TABLE FACT_TRANSPORT_INFRASTRUCTURE AS
SELECT 
UUID_STRING() AS idFACT_TRANSPORT_INFRASTRUCTURE,
src.LANE_COUNT AS lane_count,
src.SPEED AS speed,
src.SHAPE_LENGTH AS shape_length,
RANK() OVER (PARTITION BY src.STATE ORDER BY src.SHAPE_LENGTH DESC) AS road_rank_in_state,
AVG(src.SPEED) OVER (PARTITION BY src.HIERARCHY) AS avg_speed_category,
s.idDIM_STATE,
l.idDIM_LOCATION,
ri.idDIM_ROAD_INFO,
si.idDIM_STATION_INFO,
it.idDIM_INFRASTRUCTURE_TYPE,
t.idDIM_TIME
FROM STG_GA_NATIONAL_ROADS src
LEFT JOIN DIM_STATE s ON src.STATE = s.state_code
LEFT JOIN DIM_LOCATION l ON src.STATE = l.state_code AND src.STREET_NAME = l.suburb_name
LEFT JOIN DIM_ROAD_INFO ri ON src.HIERARCHY = ri.hierarchy AND src.STREET_NAME = ri.street_name
LEFT JOIN DIM_TIME t ON src.DATE_CREATED::DATE = t.date
CROSS JOIN (SELECT idDIM_INFRASTRUCTURE_TYPE FROM DIM_INFRASTRUCTURE_TYPE WHERE infra_type = 'Road' LIMIT 1) it
LEFT JOIN (SELECT idDIM_STATION_INFO FROM DIM_STATION_INFO LIMIT 1) si ON 1=1;
```

Po úspešnom vytvorení všetkých dimenzií a faktovej tabuľky boli staging tabuľky odstránené, aby sa uvoľnilo miesto a predišlo sa duplicite dát:

#### Príklad kódu:

```sql
DROP TABLE IF EXISTS STG_GA_NATIONAL_ROADS;
DROP TABLE IF EXISTS STG_GA_MAJOR_ROADS;
DROP TABLE IF EXISTS STG_GA_PETROL_STATIONS;
DROP TABLE IF EXISTS STG_OSM_EV_CHARGERS;
DROP TABLE IF EXISTS STG_GA_RAILWAY_LINES;
DROP TABLE IF EXISTS STG_GA_RAILWAY_STATIONS;
```
## 4 Vizualizácia dát

Dashboard obsahuje 6 vizualizácií, ktoré poskytujú základný prehľad o rôzne analýzy a pohodlie pre cestu, rôzne podrobnosti o cestných palivách a diaľniciach.

<img width="1871" height="824" alt="Знімок екрана 2026-01-06 020232" src="https://github.com/user-attachments/assets/578ded6a-7def-48f6-8583-0f7e0f3d6758" />

### Graf 1 Analýza rýchlostných obmedzení:
<img width="1655" height="230" alt="изображение" src="https://github.com/user-attachments/assets/49ee4dbd-d1c1-4a3d-9c98-e4ac3ec132f9" />

```sql
use warehouse chipmunk_wh;
use database chipmunk_db;
use schema chipmunk_lab11;
SELECT 
ri.hierarchy,
ri.street_name,
f.speed AS current_road_speed,
f.avg_speed_category
FROM FACT_TRANSPORT_INFRASTRUCTURE f
JOIN DIM_ROAD_INFO ri ON f.idDIM_ROAD_INFO = ri.idDIM_ROAD_INFO
WHERE f.speed IS NOT NULL
ORDER BY f.speed DESC
LIMIT 20;
```

### Graf 2 Pomer palív:
<img width="1569" height="769" alt="изображение" src="https://github.com/user-attachments/assets/ffcedad9-52ae-4052-b708-37a4012fba09" />

```sql
use warehouse chipmunk_wh;
use database chipmunk_db;
use schema chipmunk_lab11;

SELECT fuel_type, COUNT(*) as count 
FROM DIM_STATION_INFO 
GROUP BY fuel_type;
```

### Graf 3 Operátori podľa typu paliva:
<img width="1573" height="530" alt="изображение" src="https://github.com/user-attachments/assets/fda20125-10b3-4e98-9d5a-4208d445b435" />

```sql
SELECT operator, fuel_type, COUNT(*) as count
FROM DIM_STATION_INFO
WHERE operator != 'Unknown'
GROUP BY operator, fuel_type
ORDER BY count DESC
LIMIT 15;
```


### Graf 4 Aktivita infraštruktúry podľa štátov:
<img width="1495" height="494" alt="изображение" src="https://github.com/user-attachments/assets/f6f316b1-05a3-425b-b2ca-dd8ecd5d2060" />

```sql
use warehouse chipmunk_wh;
use database chipmunk_db;
create schema if not exists chipmunk_lab11;
use schema chipmunk_lab11;

SELECT 
    s.state_name, 
    si.fuel_type, 
    COUNT(*) as celkovo
FROM FACT_TRANSPORT_INFRASTRUCTURE f
JOIN DIM_STATE s ON f.idDIM_STATE = s.idDIM_STATE
JOIN DIM_STATION_INFO si ON f.idDIM_STATION_INFO = si.idDIM_STATION_INFO
GROUP BY s.state_name, si.fuel_type;
```
### Graf 5 Detailná tabuľka lokalít:
<img width="1537" height="698" alt="изображение" src="https://github.com/user-attachments/assets/ba6dc71c-65c2-43e4-9c50-3fab5b57cdd3" />

```sql
use warehouse chipmunk_wh;
use database chipmunk_db;
create schema if not exists chipmunk_lab11;
use schema chipmunk_lab11;

SELECT 
    l.suburb_name as mesto, 
    l.state_code as stat,
    COUNT(si.idDIM_STATION_INFO) as pocet_sluzieb
FROM FACT_TRANSPORT_INFRASTRUCTURE f
JOIN DIM_LOCATION l ON f.idDIM_LOCATION = l.idDIM_LOCATION
JOIN DIM_STATION_INFO si ON f.idDIM_STATION_INFO = si.idDIM_STATION_INFO
GROUP BY l.suburb_name, l.state_code
ORDER BY pocet_sluzieb DESC
LIMIT 15;
```
### Graf 6 Počet jazdných pruhov:
<img width="1514" height="474" alt="изображение" src="https://github.com/user-attachments/assets/0d919d89-4644-471b-9392-2db8915f0985" />

```sql
use warehouse chipmunk_wh;
use database chipmunk_db;
create schema if not exists chipmunk_lab11;
use schema chipmunk_lab11;
SELECT 
    s.state_code, 
    f.lane_count, 
    COUNT(*) as count
FROM FACT_TRANSPORT_INFRASTRUCTURE f
JOIN DIM_STATE s ON f.idDIM_STATE = s.idDIM_STATE
WHERE f.lane_count IS NOT NULL
GROUP BY s.state_code, f.lane_count;
```

---

**Autor:** DENYS KOVALOV

---
