USE SCHEMA TEST;

CREATE OR REPLACE TEMPORARY TABLE ESTIMATED AS
WITH main AS (
    SELECT EVENTS.USER_BIRTH,
           EVENTS.USER_GENDER,
           EVENTS.VALUE,
           EVENTS.CURRENCY,
           EVENTS.MERCHANT_NAME,
           EVENTS.MERCHANT_ADDRESS_CITY,
           EVENTS.MERCHANT_ADDRESS_DISTRICT,
           EVENTS.MERCHANT_ADDRESS_TOWN,
           EVENTS.MERCHANT_LATITUDE,
           EVENTS.MERCHANT_LONGITUDE,
           EVENTS.MERCHANT_FIRST_CATEGORY,
           EVENTS.MERCHANT_SECOND_CATEGORY,
           EVENTS.MERCHANT_THIRD_CATEGORY,
           IFF(EVENTS.MERCHANT_THIRD_CATEGORY LIKE '%전자%', '온라인', '오프라인') AS MERCHANT_ONLINE,
           IFF(EVENTS.MERCHANT_THIRD_CATEGORY LIKE '%화장품점%', 1, 0)        AS MERCHANT_COSMETICS,
           IFF(EVENTS.MERCHANT_NAME LIKE '%토니모리%', 1, 0)                  AS MERCHANT_TONYMOLY,
           CASE
               WHEN MERCHANT_NAME LIKE ANY ('%와인타임%', '%나라셀라%', '%와인앤모어%', '%가자주류%', '%가나주류%', '%가나세계주류%') THEN '와인샵'
               WHEN MERCHANT_NAME LIKE ANY ('%타이어뱅크%', '%티스테이션%', '%더타이어샵%', '%굿타이어%', '%타이어프로%', '%한국타이어%')
                   THEN '차량 정비(타이어)'
               WHEN MERCHANT_NAME LIKE ANY ('%더풋샵%', '%더하노이풋앤바디%') THEN '건전 마사지'
               WHEN MERCHANT_THIRD_CATEGORY LIKE ANY ('미용기타', '미용원', '피부미용원') THEN '뷰티샵'
               WHEN MERCHANT_THIRD_CATEGORY LIKE ANY ('실내장식', '일반가구점', '일반잡화판매점', '주방 및 가정용품점', '철재가구점') THEN '홈퍼니싱'
               ELSE MERCHANT_THIRD_CATEGORY
               END
                                                                          AS CONV_CATEGORY,
           CASE
               WHEN MERCHANT_NAME LIKE '%와인타임%' THEN '와인타임'
               WHEN MERCHANT_NAME LIKE '%나라셀라%' THEN '나라셀라'
               WHEN MERCHANT_NAME LIKE '%와인앤모어%' THEN '와인앤모어'
               WHEN MERCHANT_NAME LIKE '%가자주류%' THEN '가자주류'
               WHEN MERCHANT_NAME LIKE '%가나주류%' THEN '가나주류'
               WHEN MERCHANT_NAME LIKE '%가나세계주류%' THEN '가나세계주류'
               WHEN MERCHANT_NAME LIKE '%타이어뱅크%' THEN '타이어뱅크'
               WHEN MERCHANT_NAME LIKE '%티스테이션%' THEN '티스테이션'
               WHEN MERCHANT_NAME LIKE '%더타이어샵%' THEN '더타이어샵'
               WHEN MERCHANT_NAME LIKE '%굿타이어%' THEN '굿타이어'
               WHEN MERCHANT_NAME LIKE '%타이어프로%' THEN '타이어프로'
               WHEN MERCHANT_NAME LIKE '%한국타이어%' THEN '한국타이어'
               WHEN MERCHANT_NAME LIKE '%더풋샵%' THEN '더풋샵'
               WHEN MERCHANT_NAME LIKE '%더하노이풋앤바디%' THEN '더하노이풋앤바디'
               ELSE MERCHANT_NAME
               END
                                                                          AS CONV_DETAIL,
           EVENTS.RECV_DATE,
           EVENTS.EVENT_TIMESTAMP,
           DATE_PART(HOUR, EVENTS.EVENT_TIMESTAMP)                        AS EVENT_TIMESTAMP_HOUR,
           USERS.ADID,
           USERS.BIRTH,
           DATEDIFF(YEAR, USERS.BIRTH, CURRENT_DATE())                    AS AGE,
           FLOOR(AGE / 10) * 10                                           AS AGE_GROUP,
           USERS.GENDER,
           IFF(USERS.GENDER = 'male', 1, 0)                               AS IS_MALE,
           DAYNAME(EVENTS.EVENT_TIMESTAMP)                                AS EVENT_TIMESTAMP_DAYNAME,
           USERS.ADDRESS_CITY,
           USERS.ADDRESS_DISTRICT,
           USERS.ADDRESS_TOWN,
           USERS.ADDRESS_LATITUDE,
           USERS.ADDRESS_LONGITUDE,
           EVENTS.CARD_TYPE,
           USERS.IS_CONSENTED,
           ROUND(HAVERSINE(USERS.ADDRESS_LATITUDE, USERS.ADDRESS_LONGITUDE, EVENTS.MERCHANT_LATITUDE,
                           EVENTS.MERCHANT_LONGITUDE), 2)                 AS DISTANCE
    FROM AIRBLOC.PUBLIC.KBCARD_EVENTS EVENTS
             INNER JOIN AIRBLOC.PUBLIC.USERS USERS ON EVENTS.KBPIN = USERS.KBPIN),
     aggregate AS (
         SELECT main.MERCHANT_ADDRESS_CITY     AS CITY,
                main.MERCHANT_ADDRESS_DISTRICT AS DISTRICT,
                main.MERCHANT_LATITUDE,
                main.MERCHANT_LONGITUDE,
                main.CONV_CATEGORY,
                main.EVENT_TIMESTAMP,
                main.GENDER,
                SUM(main.VALUE)                AS VALUE
         FROM main
         GROUP BY main.MERCHANT_ADDRESS_CITY,
                  main.MERCHANT_ADDRESS_DISTRICT,
                  main.MERCHANT_LATITUDE,
                  main.MERCHANT_LONGITUDE,
                  main.CONV_CATEGORY,
                  main.EVENT_TIMESTAMP,
                  main.GENDER
     ),
     population AS (
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
     ),
     estimated AS (
         SELECT aggregate.CITY,
                aggregate.DISTRICT,
                aggregate.CONV_CATEGORY,
                aggregate.MERCHANT_LATITUDE,
                aggregate.MERCHANT_LONGITUDE,
                aggregate.EVENT_TIMESTAMP,
                aggregate.GENDER,
                aggregate.VALUE,
                gender_population.WEIGHT,
                aggregate.VALUE * gender_population.WEIGHT AS WEIGHED_VALUE
         FROM aggregate
                  LEFT JOIN gender_population ON gender_population.CITY = aggregate.CITY
             AND gender_population.DISTRICT = aggregate.DISTRICT
             AND gender_population.GENDER = aggregate.GENDER
     )

SELECT *
FROM estimated;

SELECT CITY,
       DISTRICT,
       GENDER,
       SUM(VALUE),
       SUM(WEIGHT),
       SUM(WEIGHED_VALUE)
FROM estimated
GROUP BY CITY,
         DISTRICT,
         GENDER;


