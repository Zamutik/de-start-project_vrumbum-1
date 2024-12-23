-- Этап 1. Создание и заполнение БД

CREATE SCHEMA IF NOT EXISTS raw_data;
CREATE TABLE IF NOT EXISTS raw_data.sales (
	id SMALLINT NOT NULL,
	auto varchar,
	gasoline_consumption varchar,
	price NUMERIC(7,2),
	date date,
	person_name varchar,
	phone varchar,
	discount NUMERIC(2),
	brand_origin varchar
);

copy raw_data.sales(id,auto,gasoline_consumption,price,date,person_name,phone,discount,brand_origin) FROM '/home/zamut/Рабочий стол/YANDEX-DATA/Data Enginere/projict_1/cars.csv' CSV HEADER; 

-- Этап 2. Создание выборок

CREATE SCHEMA IF NOT EXISTS car_shop;

CREATE TABLE IF NOT EXISTS car_shop.sales(
	brend TEXT,
	model TEXT,
	color TEXT,
	gasoline_consumption NUMERIC,
	price NUMERIC(7,2),
	date date,
	person_name varchar,
	phone varchar,
	discount NUMERIC(2),
	country varchar
);

INSERT INTO car_shop.sales(brend, model, color, gasoline_consumption, price, date, person_name, phone, discount, country)
SELECT TRIM(split_part(auto, ' ', 1)) AS brend,
	   TRIM(RTRIM(RTRIM(LTRIM(auto, split_part(auto, ' ', 1)), split_part(auto, ',', 2)), ',')) AS model,
	   TRIM(split_part(auto, ',', 2)) AS color,
	   CASE WHEN gasoline_consumption != 'null' THEN gasoline_consumption::numeric ELSE NULL END,
	   price,
	   date,
	   person_name,
	   phone,
	   discount,
	   CASE WHEN brand_origin != 'null' THEN brand_origin ELSE NULL END
FROM raw_data.sales;

----

CREATE TABLE IF NOT EXISTS car_shop.country(
	id serial PRIMARY KEY,
	country_name text
);

INSERT INTO car_shop.country(country_name)
SELECT DISTINCT country
FROM car_shop.sales;

----

CREATE TABLE IF NOT EXISTS car_shop.brend(
	id serial PRIMARY KEY,
	name_car TEXT,
	country_id integer REFERENCES car_shop.country
);

INSERT INTO car_shop.brend(name_car, country_id)
SELECT DISTINCT brend, c.id 
FROM car_shop.sales s 
LEFT JOIN car_shop.country c ON c.country_name = s.country
;

----

CREATE TABLE IF NOT EXISTS car_shop.model(
	id serial PRIMARY KEY,
	model_car text
);

INSERT INTO car_shop.model(model_car)
SELECT DISTINCT model
FROM car_shop.sales;

----

CREATE TABLE IF NOT EXISTS car_shop.gas(
	id serial PRIMARY KEY,
	gas_litr numeric(3,1)
);

INSERT INTO car_shop.gas(gas_litr)
SELECT DISTINCT gasoline_consumption
FROM car_shop.sales; 

----

CREATE TABLE IF NOT EXISTS car_shop.car(
	id serial PRIMARY KEY,
	brend_id integer REFERENCES car_shop.brend,
	model_id integer REFERENCES car_shop.model,
	gas_id integer REFERENCES car_shop.gas
);

INSERT INTO car_shop.car(brend_id, model_id, gas_id)
SELECT DISTINCT b.id, m.id, g.id 
FROM car_shop.sales s
RIGHT JOIN car_shop.brend b ON b.name_car = s.brend
RIGHT JOIN car_shop.model m ON m.model_car = s.model 
left JOIN car_shop.gas g ON g.gas_litr = s.gasoline_consumption  
;

----

CREATE TABLE IF NOT EXISTS car_shop.color(
	id serial PRIMARY KEY,
	color_name text
);

INSERT INTO car_shop.color (color_name)
SELECT DISTINCT color
FROM car_shop.sales s 
;

----

CREATE TABLE If NOT EXISTS car_shop.discount(
	id serial PRIMARY KEY,
	discount_num int
);

INSERT INTO car_shop.discount(discount_num)
SELECT DISTINCT discount 
FROM car_shop.sales s; 

----

CREATE TABLE IF NOT EXISTS car_shop.client_name(
	id serial PRIMARY KEY,
	name text
);

INSERT INTO car_shop.client_name(name)
SELECT DISTINCT person_name 
FROM car_shop.sales; 

----

CREATE TABLE IF NOT EXISTS car_shop.client_phone(
	id serial PRIMARY KEY,
	phone varchar
);

INSERT INTO car_shop.client_phone(phone)
SELECT DISTINCT phone 
FROM car_shop.sales;

----

CREATE TABLE IF NOT EXISTS car_shop.client_info(
	id serial PRIMARY KEY,
	client_name_id int4 REFERENCES car_shop.client_name,
	client_phone_id int4 REFERENCES car_shop.client_phone
);

INSERT INTO car_shop.client_info(client_name_id, client_phone_id)
SELECT DISTINCT cn.id, cp.id
FROM car_shop.sales s 
LEFT JOIN car_shop.client_name cn ON cn.name = s.person_name
LEFT JOIN car_shop.client_phone cp ON cp.phone = s.phone;

----

CREATE TABLE IF NOT EXISTS car_shop.invoice(
	id serial,
	car_id int4 REFERENCES car_shop.car,
	color_id int4 REFERENCES car_shop.color,
	price numeric(7,2),
	client_info_id int4 REFERENCES car_shop.client_info,
	discount_id int4 REFERENCES car_shop.discount,
	date date
);

INSERT INTO car_shop.invoice(car_id, color_id, price, client_info_id, discount_id, date)
SELECT c.id, c2.id, s.price, ci.id, d.id, s.date
FROM car_shop.sales s
LEFT JOIN car_shop.brend b ON s.brend = b.name_car
LEFT JOIN car_shop.model m ON s.model = m.model_car
LEFT JOIN car_shop.car c ON b.id = c.brend_id AND m.id = c.model_id 
LEFT JOIN car_shop.color c2  ON s.color = c2.color_name
LEFT JOIN car_shop.client_name cn ON cn.name = s.person_name 
LEFT JOIN car_shop.client_phone cp ON cp.phone = s.phone 
LEFT JOIN car_shop.client_info ci ON ci.client_name_id = cn.id AND ci.client_phone_id = cp.id 
LEFT JOIN car_shop.discount d ON d.discount_num = s.discount ;

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

SELECT (count(*) - count(gasoline_consumption))/count(*)::NUMERIC * 100.0 AS nulls_percentage_gasoline_consumption
FROM car_shop.sales s ;

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

SELECT s.brend AS brand_name, EXTRACT(YEAR from s.date)::int AS year, AVG(s.price)::numeric(7,2) AS price_avg 
FROM car_shop.sales s 
GROUP BY EXTRACT(YEAR from s.date), s.brend 
ORDER BY brand_name, year
;

---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT MONTH, EXTRACT(YEAR from s.date), AVG(s.price)::numeric(7,2)
FROM generate_series(1,12,1) AS MONTH
LEFT JOIN car_shop.sales s ON MONTH = EXTRACT(month from s.date)::int 
WHERE EXTRACT(YEAR from s.date)::int = 2022
GROUP BY MONTH, EXTRACT(YEAR from s.date)
;

---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

SELECT cn.name AS person, string_agg(concat_ws(' ', b.name_car, m.model_car), ', ') AS cars
FROM car_shop.car c
JOIN car_shop.invoice i ON c.id = i.car_id 
JOIN car_shop.brend b ON c.brend_id = b.id 
JOIN car_shop.model m ON c.model_id = m.id 
JOIN car_shop.client_info ci ON i.client_info_id = ci.id 
JOIN car_shop.client_name cn ON cn.id = ci.client_name_id 
GROUP BY cn.name
;

---- Задание 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.

SELECT s.country AS brand_origin, max((s.price * 100)/(100 - s.discount))::NUMERIC(7,2) AS price_max, min((s.price * 100)/(100 - s.discount))::NUMERIC(7,2) AS price_min
FROM car_shop.sales s 
WHERE s.country IS NOT NULL 
GROUP BY s.country 
ORDER BY s.country
;

---- Задание 6. Напишите запрос, который покажет количество всех пользователей из США.

SELECT DISTINCT count(phone) AS persons_from_usa_count
FROM car_shop.sales s 
WHERE phone LIKE '%+1%'
;



