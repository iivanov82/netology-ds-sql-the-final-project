-- 1. Выведите название самолетов, которые имеют менее 50 посадочных мест?

select a.aircraft_code, a.model, count(s.seat_no)
from aircrafts a
join seats s on a.aircraft_code = s.aircraft_code 
group by a.aircraft_code
having count(s.seat_no) < 50


-- 2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

-- 8	1572450600,00	
-- 9	13128856900,00	-734,93%
-- 10	6065673400,00	53,80%

select date_part('month', book_date), sum(total_amount),
	   round((sum(total_amount) - lag(sum(total_amount)) over (order by 1)) / (lag(sum(total_amount)) over (order by 1)) * 100, 2)
from bookings b 
group by 1 
order by 1 


-- 3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.

select a.model, array_agg(s.fare_conditions) 
from aircrafts a 
join seats s on a.aircraft_code = s.aircraft_code
group by 1
having array_position(array_agg(s.fare_conditions), 'Business') is null 


-- 4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день,
-- учитывая только те самолеты, которые летали пустыми и только те дни, где из одного аэропорта таких самолетов вылетало более одного.
-- В результате должны быть код аэропорта, дата, количество пустых мест в самолете и накопительный итог.

--select каждый аэропорт, каждый день, кол-во пустых мест в самолете, накопительный итог

select t.departure_airport, t.actual_departure, t.count, t.sum
from(
	select t.departure_airport, t.actual_departure, t.aircraft_code, s.count,
		   count(t.aircraft_code) over (partition by t.departure_airport, t.actual_departure) count_of_routs,
		   sum(s.count) over (partition by t.departure_airport order by t.actual_departure rows between unbounded preceding and current row)
	from (
		select f.departure_airport, f.actual_departure::date, f.aircraft_code
		from flights f
		left join boarding_passes bp on bp.flight_id = f.flight_id
		group by f.departure_airport, f.actual_departure, f.aircraft_code, bp.boarding_no
		having f.actual_departure is not null and bp.boarding_no is null
		) t
	join (select aircraft_code, count(seat_no)
			   from seats s 
			   group by aircraft_code
			   ) s on s.aircraft_code = t.aircraft_code		
	order by departure_airport, actual_departure) t 
where count_of_routs > 1


-- 5. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
-- Выведите в результат названия аэропортов и процентное отношение.
-- Решение должно быть через оконную функцию.

select f.departure_airport, f.arrival_airport,
	   round((count(f.flight_no) over (partition by f.departure_airport, arrival_airport) * 100. / count(f.flight_no)), 2)
from flights f
group by f.flight_no, f.departure_airport, f.arrival_airport 

	
-- 6. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7

select substring((contact_data ->> 'phone'::text), 3, 3) as "код_оператора", count(passenger_id) as "количество_пассажиров"
from tickets t 
group by 1


-- 7. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
-- До 50 млн - low
-- От 50 млн включительно до 150 млн - middle
-- От 150 млн включительно - high
-- Выведите в результат количество маршрутов в каждом полученном классе

select some_case, count(some_case) 
from (
	select
		case 
			when t.sum < 50000000 then 'low'
			when t.sum >= 50000000 and t.sum < 150000000 then 'middle'
			else 'high'
		end some_case
	from (
		select f.departure_airport, f.arrival_airport, sum(tf.amount)
		from flights f 
		join ticket_flights tf on tf.flight_id = f.flight_id
		group by f.departure_airport, f.arrival_airport) t
		where t.sum is not null)
group by some_case


-- 8. Вычислите медиану стоимости перелетов, медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов, округленной до сотых

select t.tickets_median,
	   lead (t.tickets_median) over () as "bookings_median",
	   round ((lead (t.tickets_median) over () / t.tickets_median)::dec, 2)
from (
	select percentile_cont(0.5) within group (order by amount) as "tickets_median"
	from ticket_flights tf 
	union
	select percentile_cont(0.5) within group (order by total_amount)
	from bookings b) t
	limit 1	
	

	-- 9. Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат
-- Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
-- Для работы модуля earthdistance необходимо предварительно установить модуль cube.
-- Установка модулей происходит через команду: create extension название_модуля.
	
create extension cube

create extension earthdistance

with cte1 as(
	select f.flight_id, f.departure_airport, a1.latitude, a1.longitude, f.arrival_airport, a2.latitude, a2.longitude,
	   	   round(earth_distance (ll_to_earth (a1.latitude, a1.longitude), ll_to_earth (a2.latitude, a2.longitude))::dec / 1000, 2) as distance
	from flights f
	join airports a1 on a1.airport_code = f.departure_airport
	join airports a2 on a2.airport_code = f.arrival_airport
	group by f.flight_id, a1.latitude, a1.longitude, a2.latitude, a2.longitude)
select c1.flight_id, c1.departure_airport, c1.arrival_airport, c1.distance, tf.amount, round(tf.amount / c1.distance, 2) as minimum_cost_km
from ticket_flights tf 
join cte1 c1 on c1.flight_id = tf.flight_id
group by c1.flight_id, c1.distance, tf.amount, c1.departure_airport, c1.arrival_airport
order by 6
limit 1