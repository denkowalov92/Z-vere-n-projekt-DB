-- Graf 1 Analýza rýchlostných obmedzení:

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

-- Graf 2 Pomer palív:

use warehouse chipmunk_wh;
use database chipmunk_db;
use schema chipmunk_lab11;

SELECT fuel_type, COUNT(*) as count 
FROM DIM_STATION_INFO 
GROUP BY fuel_type;


-- Graf 3 Operátori podľa typu paliva:


SELECT operator, fuel_type, COUNT(*) as count
FROM DIM_STATION_INFO
WHERE operator != 'Unknown'
GROUP BY operator, fuel_type
ORDER BY count DESC
LIMIT 15;


-- Graf 4 Aktivita infraštruktúry podľa štátov:

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

-- Graf 5 Detailná tabuľka lokalít:

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

-- Graf 6 Počet jazdných pruhov:

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

