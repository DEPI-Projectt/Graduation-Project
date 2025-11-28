UPDATE factTrip
SET Reason_for_Delay = 'Weather'
WHERE Reason_for_Delay = 'Weather Conditions'


-- Total number of rides
SELECT COUNT(*) 
AS 'Total_number_of_rides' 
FROM Tickets

-- Number of Delayed rides
SELECT COUNT(*)
AS 'No.of delayed rides'
FROM factTrip
WHERE Journey_Status='Delayed'

-- Number of cancelled rides
SELECT COUNT(*)
AS 'No.of cancelled rides'
FROM factTrip
WHERE Journey_Status='Cancelled'

-- Number of completed rides
SELECT COUNT(*)
AS 'No.of completed rides'
FROM factTrip
WHERE Journey_Status='On Time'


--Total Sales
SELECT SUM(Price)
AS 'Total Sales'
FROM factTrip


-- How many refunded requests was there?
SELECT COUNT(Refund_Request)
FROM factTrip
WHERE Refund_Request='Yes'


-- How much revenue is lost due to refunded trips
SELECT
SUM(CASE WHEN f.Refund_Request = 'Yes' THEN 1 ELSE NULL END) AS refunded_trips_count,
SUM(CASE WHEN f.Refund_Request = 'Yes' THEN f.Price ELSE 0 END) AS revenue_refunded,
SUM(f.Price) AS total_revenue,
CAST(100.0 * SUM(CASE WHEN f.Refund_Request = 'Yes' THEN f.Price ELSE 0 END) / NULLIF(SUM(f.Price),0) AS DECIMAL(10,2)) AS revenue_loss_rate
FROM factTrip f

-- Revenue lost to delays only
SELECT
SUM(CASE WHEN f.Refund_Request = 'Yes' AND f.Journey_Status = 'Delayed' THEN f.Price ELSE 0 END) AS revenue_refunded_due_to_delay,
SUM(CASE WHEN f.Refund_Request = 'Yes' THEN f.Price ELSE 0 END) AS total_refunded_revenue,
CAST(100.0 * SUM(CASE WHEN f.Refund_Request = 'Yes' AND f.Journey_Status = 'Delayed' THEN f.Price ELSE 0 END) / 
NULLIF(SUM(CASE WHEN f.Refund_Request = 'Yes' THEN f.Price ELSE 0 END),0) AS DECIMAL(10,2)) AS refund_revenue_from_delays_rate
FROM factTrip f;


-- Revenue lost to cancelled trips only
SELECT
SUM(CASE WHEN f.Refund_Request = 'Yes' AND f.Journey_Status = 'Cancelled' THEN f.Price ELSE 0 END) AS revenue_refunded_due_to_cancel,
SUM(CASE WHEN f.Refund_Request = 'Yes' THEN f.Price ELSE 0 END) AS total_refunded_revenue,
CAST(100.0 * SUM(CASE WHEN f.Refund_Request = 'Yes' AND f.Journey_Status = 'Cancelled' THEN f.Price ELSE 0 END) / 
NULLIF(SUM(CASE WHEN f.Refund_Request = 'Yes' THEN f.Price ELSE 0 END),0) AS DECIMAL(5,2)) AS refund_revenue_from_cancel_rate
FROM factTrip f;


-- In the delayed trips what was the average delayed duration?
SELECT 
Avg(DATEDIFF(MINUTE,Arrival_Time,Actual_Arrival_Time)) As Avg_delayed_duration
FROM factTrip
WHERE Journey_Status='Delayed'

-- Top 3 causes for the delays
SELECT TOP 3 Reason_for_Delay, COUNT(*) AS Reason_count
FROM factTrip
WHERE Journey_Status='Delayed'
GROUP BY Reason_for_Delay
ORDER BY Reason_count DESC


-- Which departure stations consistently produce the longest delays?
SELECT TOP 20
Dep.Station_Name AS Departure_Station, 
Arr.Station_Name AS Arrival_Station,
DATEDIFF(MINUTE,F.Arrival_Time,F.Actual_Arrival_Time) As delayed_duration
FROM factTrip AS F
JOIN dimStations AS Dep 
ON F.Departure_StationID = Dep.StationID
JOIN dimStations AS Arr 
ON F.Arrival_StationID = Arr.StationID
WHERE F.Journey_Status='delayed'
ORDER BY delayed_duration DESC

-- What’s the average price difference between ticket classes, ticket types when controlling for journey distance?
WITH route_prices AS (
SELECT 
s1.Station_Name AS Departure_Station,
s2.Station_Name AS Arrival_Station,
t.Ticket_Class,
AVG(f.Price) AS AvgPrice
FROM factTrip f
JOIN Tickets t ON f.TicketID = t.TicketID
JOIN dimStations s1 ON f.Departure_StationID = s1.StationID
JOIN dimStations s2 ON f.Arrival_StationID = s2.StationID
WHERE t.Ticket_Type = 'Anytime' -- values: Anytime,Off-Peak,Advance
GROUP BY 
s1.Station_Name,
s2.Station_Name,
t.Ticket_Class
)
SELECT 
Departure_Station,
Arrival_Station,
MAX(CASE WHEN Ticket_Class = 'First Class' THEN AvgPrice END) - 
MAX(CASE WHEN Ticket_Class = 'Standard' THEN AvgPrice END) AS Price_Diff,

CASE 
WHEN MAX(CASE WHEN Ticket_Class = 'First Class' THEN AvgPrice END) IS NULL 
AND MAX(CASE WHEN Ticket_Class = 'Standard' THEN AvgPrice END) IS NOT NULL 
THEN 'Missing First Class Data'
        
WHEN MAX(CASE WHEN Ticket_Class = 'Standard' THEN AvgPrice END) IS NULL 
AND MAX(CASE WHEN Ticket_Class = 'First Class' THEN AvgPrice END) IS NOT NULL 
THEN 'Missing Standard Data'
 
ELSE 'Complete'
END AS Data_Status
FROM route_prices
GROUP BY Departure_Station,Arrival_Station -- conclusion: Null values means that there is only one class that had that exact trip,
										   




--What percentage of delayed trips actually lead to refund requests?
SELECT CAST(100.0 * SUM(CASE WHEN Refund_Request = 'Yes' THEN 1 ELSE 0 END) / 
COUNT(TicketID) AS DECIMAL(5,2)) AS DelayedTripRefundRate
FROM factTrip
WHERE Journey_Status = 'Delayed'

--Is there a time of day or day of week where delays spike?

-- HOURS OF DAY
SELECT DATEPART(HOUR, Departure_Time) AS hour_of_day,
SUM(CASE WHEN Journey_Status='Delayed' THEN 1 ELSE 0 END) AS Delayed_count,
COUNT(*) AS total_rides
FROM factTrip
GROUP BY DATEPART(HOUR, Departure_Time)
ORDER BY hour_of_day ASC

-- DAYS OF WEEK
SELECT DATENAME(WEEKDAY, c.Date) AS 'day in week', 
SUM(CASE WHEN Journey_Status='delayed' THEN 1 ELSE 0 END) AS Delayed_count,
COUNT(*) AS total_rides
FROM factTrip as f
join calendar as c on f.DateID=c.DateID
GROUP BY DATENAME(WEEKDAY, c.Date)


-- Which routes have the highest refund-to-delay ratio
SELECT
f.Departure_StationID,
f.Arrival_StationID,
s1.Station_Name AS Departure_Station,
s2.Station_Name AS Arrival_Station,
SUM(CASE WHEN f.Journey_Status = 'Delayed' THEN 1 ELSE 0 END) AS delayed_count,
SUM(CASE WHEN f.Journey_Status = 'Delayed' AND f.Refund_Request = 'Yes' THEN 1 ELSE 0 END) AS refunded_after_delay,
CAST(100.0 * SUM(CASE WHEN f.Journey_Status = 'Delayed' AND f.Refund_Request = 'Yes' THEN 1 ELSE 0 END) / 
NULLIF(SUM(CASE WHEN f.Journey_Status = 'Delayed' THEN 1 ELSE 0 END),0) AS DECIMAL(5,2)) AS refund_to_delay_pct
FROM factTrip f
JOIN dimStations s1 ON f.Departure_StationID = s1.StationID
JOIN dimStations s2 ON f.Arrival_StationID = s2.StationID
GROUP BY f.Departure_StationID, f.Arrival_StationID, s1.Station_Name, s2.Station_Name
HAVING SUM(CASE WHEN f.Journey_Status = 'Delayed' THEN 1 ELSE 0 END) >= 20
ORDER BY refund_to_delay_pct DESC;

-- what was the cause for the high refund rates?
SELECT
s1.Station_Name AS Departure_Station,
s2.Station_Name AS Arrival_Station,
f.Reason_for_Delay, 
COUNT(*) AS Refunded_Count 
FROM factTrip f
JOIN dimStations s1 ON f.Departure_StationID = s1.StationID
JOIN dimStations s2 ON f.Arrival_StationID = s2.StationID
WHERE f.Journey_Status = 'Delayed' AND f.Refund_Request = 'Yes' 
GROUP BY s1.Station_Name,  s2.Station_Name, f.Reason_for_Delay 
ORDER BY Refunded_Count DESC



--Do First class ticket classes get faster more reliable service
SELECT
t.Ticket_Class,
COUNT(*) AS trips,
CAST(100.0 * SUM(CASE WHEN f.Journey_Status = 'Delayed' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(6,2)) AS delay_rate,
AVG(CASE WHEN f.Journey_Status = 'Delayed' THEN DATEDIFF(MINUTE, Arrival_Time, Actual_Arrival_Time) END) AS avg_delay_minutes
FROM factTrip f
JOIN Tickets t ON f.TicketID = t.TicketID
GROUP BY t.Ticket_Class
ORDER BY delay_rate


