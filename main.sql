USE SCHEMA INFORMATION_SCHEMA;

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
         SELECT main.MERCHANT_NAME,
                main.CONV_CATEGORY,
                main.EVENT_TIMESTAMP,
                main.EVENT_TIMESTAMP_HOUR,
                main.GENDER,
                main.AGE_GROUP,
                main.EVENT_TIMESTAMP_DAYNAME,
                main.DISTANCE,
                main.VALUE
         FROM main
     )
SELECT *
FROM aggregate
