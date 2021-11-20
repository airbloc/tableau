USE SCHEMA INFORMATION_SCHEMA;

CREATE OR REPLACE TABLE SANDBOX.TEST.POPULATION_WEIGHT AS
WITH population AS (
    SELECT FIELD_GROUP_1              AS CITY,
           CASE
               WHEN FIELD_GROUP_3 IS NOT NULL THEN CONCAT(FIELD_GROUP_2, ' ', FIELD_GROUP_3)
               WHEN FIELD_GROUP_1 = '세종특별자치시' THEN '세종특별자치시'
               ELSE FIELD_GROUP_2 END AS DISTRICT,
           'male'                     AS GENDER,
           SUM(MALE_POPULATION)       AS POPULATION
    FROM SANDBOX.TEST.POPULATION
    WHERE DISTRICT IS NOT NULL
    GROUP BY CITY, DISTRICT

    UNION ALL

    SELECT FIELD_GROUP_1              AS CITY,
           CASE
               WHEN FIELD_GROUP_3 IS NOT NULL THEN CONCAT(FIELD_GROUP_2, ' ', FIELD_GROUP_3)
               ELSE FIELD_GROUP_2 END AS DISTRICT,
           'female'                   AS GENDER,
           SUM(FEMALE_POPULATION)     AS POPULATION
    FROM SANDBOX.TEST.POPULATION
    WHERE DISTRICT IS NOT NULL
    GROUP BY CITY, DISTRICT
),
     users AS (
         SELECT ADDRESS_CITY                                                        AS CITY,
                CASE WHEN CITY = '세종특별자치시' THEN '세종특별자치시' ELSE ADDRESS_DISTRICT END AS DISTRICT,
                GENDER,
                COUNT(DISTINCT (ADID))                                              AS SAMPLE_SIZE
         FROM AIRBLOC.PUBLIC.USERS
         GROUP BY CITY, DISTRICT, GENDER
         ORDER BY CITY, DISTRICT, GENDER
     ),
     gender_population AS (
         SELECT users.CITY,
                users.DISTRICT,
                users.GENDER,
                SUM(population.POPULATION)                          AS POPULATION,
                SUM(users.SAMPLE_SIZE)                              AS SAMPLE_SIZE,
                SUM(population.POPULATION) / SUM(users.SAMPLE_SIZE) AS WEIGHT
         FROM users
                  LEFT JOIN population ON population.CITY = users.CITY AND population.DISTRICT = users.DISTRICT AND
                                          population.DISTRICT = users.DISTRICT
         GROUP BY users.CITY,
                  users.DISTRICT,
                  users.GENDER
     )
SELECT *
FROM gender_population;


