--нужно найти актуальные / текущие оклады сотрудников

select emp_id, salary
from employee_salary 
where (emp_id, effective_from) in (
	select emp_id, max(effective_from)
	from employee_salary 
	group by 1)
	
--нужно в виде строки вывести зарплатные грейды в которые попадают текущие оклады сотрудников.
	
select emp_id, salary, string_agg(gs.grade::text, ', ')
from employee_salary es
left join grade_salary gs on es.salary between gs.min_salary and gs.max_salary
where (emp_id, effective_from) in (
	select emp_id, max(effective_from)
	from employee_salary 
	group by 1)
group by 1, 2
	
	
--нужно найти проекты на которых задействовано более 11 сотрудников

select project_id, "name", count(distinct unnest)
from (
	select project_id, "name", unnest(array_append(employees_id, assigned_id))
	from projects) 
group by 1, 2
having count(distinct unnest) > 11


--нужно вывести количество вакантных должностей

explain analyze
select count(*)
from position p 
where p.pos_id not in (select pos_id from employee e)

explain analyze
select count(*)
from position p 
left join employee e on p.pos_id = e.pos_id 
where e.emp_id is null

--количество сотрудников, которые старше 65 лет.

select count(*)
from person p
where date_part('year', age(dob)) > 65



---нужно найти актуальные / текущие оклады сотрудников

select 
emp_id,
salary,
string_agg(gs.grade::text, ', ')
from (select 
emp_id,
salary  
from
(select  
emp_id,
salary, 
row_number() over (partition by emp_id order by es.effective_from desc)
 from hr.employee_salary es)
where row_number =1) t
left join hr.grade_salary gs on t.salary between min_salary and max_salary
group by emp_id, salary


--нужно найти проекты на которых задействовано более 12 сотрудников

select 
project_id,
employees_id 
from hr.projects p 
where case when employees_id && array [assigned_id] then array_length(employees_id,1)
else (array_length(employees_id,1)+1)
end >11

select 
count(distinct unnest) ,
project_id
from
(select 
project_id,
employees_id,
unnest(array_append(employees_id, assigned_id)) 
from hr.projects p ) t
group by project_id
having count(distinct unnest) >11

--нужно вывести количество вакантных должностей

select 
count(*) 
from hr.position p
left join hr.employee e on e.pos_id = p.pos_id 
where e.emp_id is null


select 
count(*) 
from hr.position p
where p.pos_id  not in
(select e.pos_id
from hr.employee e)