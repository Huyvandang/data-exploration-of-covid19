-- Select data I want to use

SELECT location,date,total_cases,new_cases,total_deaths,population
FROM coviddeaths
ORDER BY 1,2

-- I want to look at Total Cases vs Total Deaths as a death percentage

SELECT location,date,total_cases,total_deaths,(CAST(total_deaths AS decimal)/total_cases)*100 AS DeathPercentage
FROM coviddeaths
ORDER BY 1,2

-- Lets see the results for the UK
	-- The results will show the likelihood of dying in the UK as a percentage ordered by date

SELECT location,date,total_cases,total_deaths,(CAST(total_deaths AS decimal)/total_cases)*100 AS DeathPercentage
FROM coviddeaths
WHERE location LIKE '%Kingdom%'
ORDER BY 1,2

-- I want to see the Total Cases vs Population
	-- Below shows what percentage of population had Covid

SELECT location,date,population,total_cases,
(CAST(total_cases AS decimal)/population)*100 AS PercentPopulationInfected
FROM coviddeaths
-- WHERE location LIKE '%Kingdom%'
ORDER BY 1,2

-- Look at Countries with highest infection rate compared to population

SELECT location,population,MAX(total_cases) AS HighestInfectionCount,
MAX((CAST(total_cases AS decimal)/population))*100 AS PercentPopulationInfected
FROM coviddeaths
-- WHERE location LIKE '%Kingdom%'
GROUP BY location,population
ORDER BY PercentPopulationInfected DESC

-- Show Countries with the highest death count per population

SELECT location, MAX(total_deaths) AS TotalDeathCount
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY TotalDeathCount DESC

-- Which continents had the highest death count per population?

SELECT location, MAX(total_deaths) AS TotalDeathCount
FROM coviddeaths
WHERE continent IS NULL
GROUP BY location
ORDER BY TotalDeathCount DESC

-- Replace total_cases column with '0' entry to 'NULL' and continent column with blank entries to 'NULL'

UPDATE coviddeaths
SET total_cases = NULLIF(total_cases,'0'), continent = NULLIF(continent,'')

-- Replace '0' values to 'NULL' on new_cases and new_deaths column

UPDATE coviddeaths
SET new_cases = NULLIF(new_cases,'0'), new_deaths = NULLIF(new_deaths,'0')

-- Show the Death percentage of each continent per date

SELECT continent,date,SUM(new_deaths) AS total_deaths,SUM(new_cases) AS total_cases,
CONCAT(ROUND(SUM(new_deaths::decimal)/SUM(new_cases::decimal)*100,2),'%') AS death_percentage
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY continent,date
ORDER BY date

-- Show the total deaths, cases and the Death percentage for the whole world 

SELECT SUM(new_deaths) AS total_deaths,SUM(new_cases) AS total_cases,
CONCAT(ROUND(SUM(new_deaths::decimal)/SUM(new_cases::decimal)*100,2),'%') AS death_percentage
FROM coviddeaths
WHERE continent IS NOT NULL
-- GROUP BY continent,date
ORDER BY 1,2

-- Join both coviddeaths and covidvaccinations table with the 'location' and 'date' columns

SELECT *
FROM coviddeaths
JOIN covidvaccinations
ON coviddeaths.location = covidvaccinations.location
AND coviddeaths.date = covidvaccinations.date

-- What are the total amount of people in the world that are vaccinated in each continent and location?

SELECT coviddeaths.continent,coviddeaths.location,coviddeaths.date,coviddeaths.population,covidvaccinations.new_vaccinations
FROM coviddeaths
JOIN covidvaccinations
ON coviddeaths.location = covidvaccinations.location
AND coviddeaths.date = covidvaccinations.date
WHERE coviddeaths.continent IS NOT NULL
ORDER BY 2,3

-- Show the rolling total of vaccinations

SELECT coviddeaths.continent,coviddeaths.location,coviddeaths.date,coviddeaths.population,covidvaccinations.new_vaccinations,
SUM(covidvaccinations.new_vaccinations::decimal) OVER (PARTITION BY coviddeaths.location ORDER BY coviddeaths.location,coviddeaths.date) AS rollingtotalvaccinated
FROM coviddeaths
JOIN covidvaccinations
ON coviddeaths.location = covidvaccinations.location
AND coviddeaths.date = covidvaccinations.date
WHERE coviddeaths.continent IS NOT NULL
ORDER BY 2,3

-- Use a (CTE)
	-- To calculate rolling percentage of population vaccinated

WITH popvsvac (continent,location,date,population,new_vaccinations,rollingtotalvaccinated)
AS
(
SELECT coviddeaths.continent,coviddeaths.location,coviddeaths.date,coviddeaths.population,covidvaccinations.new_vaccinations,
SUM(covidvaccinations.new_vaccinations::decimal) OVER (PARTITION BY coviddeaths.location ORDER BY coviddeaths.location,coviddeaths.date) AS rollingtotalvaccinated
FROM coviddeaths
JOIN covidvaccinations
ON coviddeaths.location = covidvaccinations.location
AND coviddeaths.date = covidvaccinations.date
WHERE coviddeaths.continent IS NOT NULL
)
SELECT *, CONCAT(ROUND((rollingtotalvaccinated/population)*100,2),'%') AS rollingpercentvaccinated
FROM popvsvac

-- Alternatively, a TEMP table can be used

CREATE TABLE percentpopulationvaccinated
(
continent VARCHAR(250),
location VARCHAR(250),
date VARCHAR(50),
population NUMERIC,
new_vaccinations NUMERIC,
rollingtotalvaccinated NUMERIC
)

-- Insert date into new TEMP table

INSERT INTO percentpopulationvaccinated
SELECT coviddeaths.continent,coviddeaths.location,coviddeaths.date,coviddeaths.population,covidvaccinations.new_vaccinations,
SUM(covidvaccinations.new_vaccinations::decimal) OVER (PARTITION BY coviddeaths.location ORDER BY coviddeaths.location,coviddeaths.date) AS rollingtotalvaccinated
FROM coviddeaths
JOIN covidvaccinations
ON coviddeaths.location = covidvaccinations.location
AND coviddeaths.date = covidvaccinations.date
WHERE coviddeaths.continent IS NOT NULL

-- Show rolling percent of population vaccinated from this newly created TEMP table

SELECT *,CONCAT(ROUND((rollingtotalvaccinated/population)*100,2),'%') AS rollingpercentvaccinated
FROM percentpopulationvaccinated

-- If we want to modify the inserted information in the newly created TEMP table, use DROP TABLE IF EXISTS to remove the old table and create the new TEMP table with the modifications

DROP TABLE IF EXISTS percentpopulationvaccinated

-- Recreate the TEMP table

CREATE TABLE percentpopulationvaccinated
(
continent VARCHAR(250),
location VARCHAR(250),
date VARCHAR(50),
population NUMERIC,
new_vaccinations NUMERIC,
rollingtotalvaccinated NUMERIC
)

-- Insert the modified information to the TEMP table

INSERT INTO percentpopulationvaccinated
SELECT coviddeaths.continent,coviddeaths.location,coviddeaths.date,coviddeaths.population,covidvaccinations.new_vaccinations,
SUM(covidvaccinations.new_vaccinations::decimal) OVER (PARTITION BY coviddeaths.location ORDER BY coviddeaths.location,coviddeaths.date) AS rollingtotalvaccinated
FROM coviddeaths
JOIN covidvaccinations
ON coviddeaths.location = covidvaccinations.location
AND coviddeaths.date = covidvaccinations.date

-- Recall the rolling percent of population vaccinated from this newly modified TEMP table

SELECT *,CONCAT(ROUND((rollingtotalvaccinated/population)*100,2),'%') AS rollingpercentvaccinated
FROM percentpopulationvaccinated

-- Create VIEW to store data for later visualisations

CREATE VIEW populationvaccinatedpercent AS
SELECT *,CONCAT(ROUND((rollingtotalvaccinated/population)*100,2),'%') AS rollingpercentvaccinated
FROM percentpopulationvaccinated

-- Recall the newly created VIEW

SELECT * 
FROM populationvaccinatedpercent

-- BUSINESS CASE QUESTIONS

SELECT location, total_cases, date
FROM coviddeaths 
GROUP BY location, total_cases, date
ORDER BY 1

-- Postgresql default datestyle format is YMD
	-- Change datestyle to match .csv file date format

SET datestyle to DMY

-- Select date column with new datatype; 'DATE'

SELECT CAST(date AS DATE)
FROM coviddeaths
ORDER BY date

-- At which point in time did we see Covid cases decrease in the UK?
	-- Use this data to show when businesses likely went back to a normality
	-- Which patterns occur that may have had a direct impact on businesses like retail or public sectors?

SELECT location,date::date,population,new_cases
FROM coviddeaths
WHERE location LIKE '%Kingdom'
AND new_cases IS NOT NULL
GROUP BY date,location,population,new_cases
ORDER BY date

-- Expand on this by taking a look at the covid vaccinations and covid deaths datasets 
	-- Are there any relationships between new and total vaccinations from the covidvaccinations table and new cases from the coviddeaths table?

SELECT coviddeaths.location,TO_CHAR(CAST(coviddeaths.date AS date),'DDMMYYYY'),coviddeaths.new_cases,covidvaccinations.new_vaccinations,covidvaccinations.total_vaccinations,coviddeaths.population
FROM coviddeaths
JOIN covidvaccinations
ON coviddeaths.location = covidvaccinations. location
AND coviddeaths.date = covidvaccinations.date
WHERE coviddeaths.location lIKE '%Kingdom%' 
AND coviddeaths.new_cases IS NOT NULL
GROUP BY coviddeaths.location,coviddeaths.date,coviddeaths.date,coviddeaths.new_cases,covidvaccinations.new_vaccinations,covidvaccinations.total_vaccinations,coviddeaths.population
ORDER BY coviddeaths.date

-- Which country was affected the most by Covid 19 deaths?
	-- Remove continents showing up in the location column

SELECT location,SUM(total_deaths) AS totaldeathcount
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location
HAVING SUM(total_deaths) >1 --Used to filter out NULL results with aggregate functions
ORDER BY totaldeathcount DESC LIMIT 1

-- A pharmacy supplying vaccines have a limited amount that they could supply for the world
	-- How can they distribute them evenly? 
	-- Show results as a percentage for clarity
	
SELECT SUM(population) OVER () AS SUMtotal,location
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location,population
ORDER BY population DESC
-- This query calcualtes the total population

SELECT population,location,CONCAT(ROUND((population::decimal/8045247353)*100,2),'%') AS populationpercentage
FROM coviddeaths
WHERE continent IS NOT NULL
GROUP BY location,population
ORDER BY population DESC

-- Is there a correlation between age and deaths
-- Is there a correlation between 

SELECT SUM(new_cases) AS total_cases,SUM(new_deaths) AS total_deaths,
CONCAT(ROUND(SUM(new_deaths::decimal)/SUM(new_cases::decimal)*100,2),'%') AS deathpercentage
FROM coviddeaths
WHERE continent IS NOT NULL
ORDER BY 1,2

-- Total death count split into continents 

SELECT location,SUM(new_deaths) AS totaldeathcount
FROM coviddeaths
WHERE continent IS NULL
AND location NOT IN ('World','European Union','International','High income','Low income','Lower middle income','Upper middle income')
GROUP BY location
ORDER BY 1,2

SELECT location,population,MAX(total_cases) AS highestinfectedcount,
(MAX(total_cases::decimal)/MAX(population::decimal))*100 AS percentpopulationinfected																		
FROM coviddeaths
GROUP BY location,population
ORDER BY percentpopulationinfected DESC

SELECT location,population,date,MAX(total_cases) AS highestinfectioncount,
(MAX(total_cases::decimal)/MAX(population::decimal))*100 AS percentpopulationinfected
FROM coviddeaths
GROUP BY location,population,date
ORDER BY percentpopulationinfected DESC

SELECT location,population,date,MAX(total_cases) AS highestinfectioncount,
(MAX(total_cases::decimal)/MAX(population::decimal))*100 AS percentpopulationinfected
FROM coviddeaths
GROUP BY location,population,date