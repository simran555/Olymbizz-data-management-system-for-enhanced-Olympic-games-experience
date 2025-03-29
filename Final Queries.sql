-- HYPOTHESIS 1: to find the average speed of athletes who participated in events and won medals based in particular sports
-- hypothesis does high speed means more winning chances
CREATE OR REPLACE VIEW speed_vs_winning_chance AS
WITH MedalInfo AS (
    SELECT
        A.athleteID,
        COUNT(M.medalType) AS NumMedals,
        AVG(PD.speed) AS AvgSpeed
    FROM
        ATHLETES_UPADATED A
    JOIN
        PERFORMANCE_DETAILS PD ON A.athleteID = PD.athleteID
    LEFT JOIN
        MEDALS_UPDATED M ON A.athleteID = M.athleteID
    JOIN 
        EVENTS_UPDATED E ON M.eventID = E.eventID
    WHERE
        E.EventCategory = 'Swimming' -- Replace 'your_swimming_sport_id' with the actual ID for the "Swimming" sports category
    GROUP BY
        A.athleteID
)
SELECT
    MI.athleteID,
    A.fname,
    A.lname,
    MI.NumMedals,
    MI.AvgSpeed
FROM
    ATHLETES_UPDATED A
JOIN
    MedalInfo MI ON A.athleteID = MI.athleteID;
SELECT * FROM speed_vs_winning_chance;

--2  Find the total viewership numbers for a specific event:

DROP VIEW IF EXISTS viewership_across_events;
CREATE OR REPLACE VIEW viewership_across_events AS
SELECT eventname AS Event_Name, trim(to_char(SUM(viewershipnumbers),'999,999,999')) AS Total_Viewership  
FROM events_updated a 
JOIN BROADCAST_EVENTS b ON a.eventID = b.eventID
JOIN BROADCAST c ON c.broadcastID = b.broadcastID
JOIN TELECAST d ON c.broadcastID = d.broadcastID
JOIN VIEWERSHIP e ON e.viewershipID = d.viewershipID
GROUP BY eventname
ORDER BY Total_Viewership DESC
;
SELECT * FROM viewership_across_events ;

SELECT * FROM broadcast ;
SELECT * FROM viewership ;
SELECT * FROM telecast ;
SELECT * FROM broadcast_events ;

--3 Find Athletes with the Highest Medal Count and rank them according to each event

SELECT * FROM MEDALS ;

DROP VIEW IF EXISTS athletes_medal_count ;
CREATE OR REPLACE VIEW athletes_medal_count AS
SELECT A.Fname || ' ' || A.Lname AS Athlete_Name, A.country, E.eventName, COUNT(M.medalID) AS medal_count,
RANK() OVER(PARTITION BY E.eventname ORDER BY COUNT(M.medalID) DESC) AS event_rank
FROM ATHLETES_UPDATED A
JOIN MEDALS_UPDATED M ON A.athleteID = M.athleteID
JOIN EVENTS_UPDATED E ON M.eventID = E.eventID
GROUP BY A.Fname || ' ' || A.Lname, A.country, E.eventName
ORDER BY A.Fname || ' ' || A.Lname DESC
;

SELECT * FROM athletes_medal_count ;

--4 Identify Athletes Whose Performance Improved or Declined

DROP VIEW IF EXISTS athletes_performance ;
CREATE OR REPLACE VIEW athletes_performance AS
SELECT 
A.athleteID, A.Fname || ' ' || A.Lname as Athlete_Name, 
P.initial_speed, P.latest_speed,
CASE 
WHEN P.latest_speed > P.initial_speed THEN 'Improved'
WHEN P.latest_speed < P.initial_speed THEN 'Declined'
ELSE 'Stable'
END AS performance_trend
FROM 
ATHLETES_UPDATED A
INNER JOIN (
SELECT 
athleteID, FIRST_VALUE(speed) OVER (PARTITION BY athleteID ORDER BY dateRecorded ASC) AS initial_speed,
FIRST_VALUE(speed) OVER (PARTITION BY athleteID ORDER BY dateRecorded DESC) AS latest_speed
FROM 
PERFORMANCE_DETAILS
) P ON A.athleteID = P.athleteID
GROUP BY A.athleteID, A.Fname || ' ' || A.Lname, 
P.initial_speed, P.latest_speed,
CASE 
WHEN P.latest_speed > P.initial_speed THEN 'Improved'
WHEN P.latest_speed < P.initial_speed THEN 'Declined'
ELSE 'Stable'
END 
ORDER BY A.athleteID
;
SELECT * FROM athletes_performance ;

--5 Identify Athletes Who Won Medals in Consecutive Olympics: 
-- Assuming Olympics occur every 4 years

DROP VIEW IF EXISTS athletes_consecutive_medals ;
CREATE OR REPLACE VIEW athletes_consecutive_medals AS
SELECT A.athleteID, A.Fname, A.Lname, EXTRACT(YEAR FROM E1.year) AS Year1,
EXTRACT(YEAR FROM E2.year) AS Year2
FROM ATHLETES_UPDATED A
INNER JOIN MEDALS_UPDATED M1 ON A.athleteID = M1.athleteID
INNER JOIN PLAYS_IN P1 ON A.athleteID = P1.athleteID
INNER JOIN EDITION E1 ON P1.editionid = E1.editionID
INNER JOIN MEDALS_UPDATED M2 ON A.athleteID = M2.athleteID
INNER JOIN PLAYS_IN P2 ON A.athleteID = P2.athleteID
INNER JOIN EDITION_UPDATED E2 ON P2.editionid = E2.editionID
WHERE EXTRACT(YEAR FROM E1.year) + 4 = EXTRACT(YEAR FROM E2.year)
AND E1.editionID <> E2.editionID
GROUP BY A.athleteID, A.Fname, A.Lname, E1.year, E2.year
ORDER BY A.athleteID, EXTRACT(YEAR FROM E1.year)
;

SELECT * FROM athletes_consecutive_medals ;

--6 Viewership trends and insights

CREATE OR REPLACE VIEW viewership_trends AS
WITH RankedViewership AS (
    SELECT
        V.ViewershipID, V.ViewershipNumbers, V.ViewershipDate, V.ViewershipTime, 
        B.broadcastID, E.eventID, E.eventname, A.athleteID, A.fname,
        RANK() OVER (
            PARTITION BY A.Fname || ' ' || A.Lname ORDER BY V.ViewershipNumbers DESC
            ) AS ViewerRank,
        LAG(V.ViewershipNumbers) OVER (
            ORDER BY V.ViewershipNumbers DESC
            ) AS PrevViewershipNumbers
    FROM
        VIEWERSHIP V
        JOIN TELECAST T ON V.ViewershipID = T.ViewershipID
        JOIN BROADCAST B ON T.broadcastID = B.broadcastID
        JOIN BROADCAST_EVENTS BE ON B.broadcastID = BE.broadcastID
        JOIN EVENTS_UPDATED E ON BE.eventID = E.eventID
        JOIN MEDALS_UPDATED M ON E.eventID = M.eventID
        JOIN ATHLETES_UPDATED A ON M.athleteID = A.athleteID
)
SELECT
    R.eventname, A.Fname || ' ' || A.Lname AS "ATHLETE NAME", R.ViewershipDate, R.ViewerRank, 
    R.ViewershipNumbers AS "CURRENT VIEWERSHIP", R.PrevViewershipNumbers AS "PREVIOUS VIEWERSHIP", 
    R.ViewershipNumbers - R.PrevViewershipNumbers AS "VIEWERSHIP CHANGE"
FROM
    RankedViewership R
    JOIN ATHLETES_UPDATED A ON R.athleteID = A.athleteID
ORDER BY
    R.ViewerRank
    ;
SELECT * FROM viewership_trends;
COMMIT;

--7. Cumulative Medal Count Over Time for Each Country

DROP VIEW IF EXISTS country_medals ;
CREATE OR REPLACE VIEW country_medals AS
SELECT A.country, PD.daterecorded, COUNT(PD.medal) OVER (PARTITION BY A.country ORDER BY PD.daterecorded) as CumulativeMedals
FROM PERFORMANCE_DETAILS PD
JOIN ATHLETES_UPDATED A ON PD.athleteID = A.athleteId
ORDER BY 3 DESC
;
SELECT * FROM country_medals ;

--8 -- Compare the performance of host countries in terms of the number of athletes and their overall success.
CREATE OR REPLACE VIEW host_country_performance AS
WITH HostCountrySummary AS (
    SELECT
        E.host_country,
        COUNT(DISTINCT PI.athleteID) AS TotalAthletes,
        COUNT(DISTINCT M.medalID) AS TotalMedals
    FROM
        EDITION E
        JOIN PARTS_OF PO ON E.editionID = PO.editionID
        JOIN COUNTRY C ON PO.countryID = C.countryID
        LEFT JOIN PLAYS_IN PI ON E.editionID = PI.editionID
        LEFT JOIN MEDALS_UPDATED M ON PI.athleteID = M.athleteID
    GROUP BY
        E.host_country
)
SELECT
    H.host_country,
    H.TotalAthletes,
    H.TotalMedals,
    RANK() OVER (ORDER BY H.TotalMedals DESC) AS MedalRank
FROM
    HostCountrySummary H;
SELECT * FROM host_country_performance;

SELECT * FROM MEDALS_UPDATED;

-- 9.increase in viewership based on athlete performance in particular event;
CREATE OR REPLACE VIEW viewership_vs_athlete AS
WITH RankedViewership AS (
    SELECT
        V.ViewershipID, V.ViewershipNumbers, V.ViewershipDate, V.ViewershipTime, 
        B.broadcastID, E.eventID, E.eventname, A.athleteID, A.fname,
        RANK() OVER (
            ORDER BY V.ViewershipNumbers DESC
            ) AS ViewerRank,
        LAG(V.ViewershipNumbers) OVER (
            ORDER BY V.ViewershipNumbers DESC
            ) AS PrevViewershipNumbers
    FROM
        VIEWERSHIP V
        JOIN TELECAST T ON V.ViewershipID = T.ViewershipID
        JOIN BROADCAST B ON T.broadcastID = B.broadcastID
        JOIN BROADCAST_EVENTS BE ON B.broadcastID = BE.broadcastID
        JOIN EVENTS_UPDATED E ON BE.eventID = E.eventID
        JOIN MEDALS_UPDATED M ON E.eventID = M.eventID
        JOIN ATHLETES_UPDATED A ON M.athleteID = A.athleteID
)
SELECT
    R.eventname, A.Fname || ' ' || A.Lname AS "ATHLETE NAME", R.ViewershipDate, R.ViewerRank, 
    R.ViewershipNumbers AS "CURRENT VIEWERSHIP", R.PrevViewershipNumbers AS "PREVIOUS VIEWERSHIP", 
    R.ViewershipNumbers - R.PrevViewershipNumbers AS "VIEWERSHIP CHANGE"
FROM
    RankedViewership R
    JOIN ATHLETES_UPDATED A ON R.athleteID = A.athleteID
ORDER BY
    R.ViewerRank;
SELECT * FROM viwership_vs_athlete;

 --10.       to retrieve information about the previous and next events based on the event date.
CREATE OR REPLACE VIEW previous_and_next_events AS
SELECT
    eventID,
    eventname,
    year,
    LEAD(eventname) OVER (ORDER BY year) AS nextEvent,
    LAG(eventname) OVER (ORDER BY year) AS previousEvent
FROM
    EVENTS_UPDATED;
COMMIT;

SELECT * FROM previous_and_next_events;

--11 Retrieve top-performing athletes based on the number of gold medals

CREATE OR REPLACE VIEW top_performing_athletes AS
SELECT Athletes.AthleteID, ATHLETES.fname || ' '|| ATHLETES.lname AS athletename, COUNT(Medals.medalType) AS Gold_Medals
FROM Athletes_UPDATED
JOIN Performance_Details ON Athletes.AthleteID = Performance_Details.AthleteID
JOIN Medals_UPDATED ON Performance_Details.AthleteID = Medals.AthleteID
WHERE medalType = 'Gold'
GROUP BY Athletes.AthleteID, Fname, Lname  -- Include non-aggregated columns in the GROUP BY
ORDER BY Gold_Medals DESC
FETCH FIRST 10 ROWS ONLY;
SELECT * FROM top_performing_athletes;

-- 12  Event Popularity Trend

DROP VIEW IF EXISTS event_popularity ;
CREATE OR REPLACE VIEW event_popularity AS
SELECT *
FROM
(
SELECT E.eventname, E.eventdate, E.attendance,
COALESCE(LAG(E.attendance) OVER (PARTITION BY E.eventname ORDER BY E.eventdate),0) as Previous_Editions_Attendance,
COALESCE(E.attendance - LAG(E.attendance) OVER (PARTITION BY E.eventname ORDER BY E.eventdate),0) as Attendance_Change
FROM EVENTS_UPDATED E
)
WHERE Previous_Editions_Attendance != 0
;
SELECT * FROM event_popularity ;    

select * from events_2;


