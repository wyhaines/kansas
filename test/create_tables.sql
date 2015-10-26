drop table Students;
drop table Courses;
drop table Courses_Taken;

create table Students (
	student_number int not null primary key auto_increment,
	first_name varchar(40),
	last_name varchar(40),
	address varchar(40),
	city varchar(40),
	state varchar(40),
	zip varchar(11)
);

create table Courses (
	name char(30) not null,
	primary key (name)
);

create table Courses_Taken (
	name char(30) not null,
	student_number int not null,
	primary key (name, student_number)
);

insert into Students (student_number, first_name) values(100, 'Dave');
insert into Students (student_number, first_name) values(101, 'Sandy');
insert into Students (student_number, first_name) values(102, 'Pete');
insert into Students (student_number, first_name) values(103, 'Pippa');
insert into Students (student_number, first_name) values(104, 'Charlie');
insert into Students (student_number, first_name) values(105, 'Wilma');

insert into Courses values('CSC301');
insert into Courses values('LAW101');
insert into Courses values('LAW102');
insert into Courses values('PHL312');
insert into Courses values('XZY987');

insert into Courses_Taken values('CSC301', 100);
insert into Courses_Taken values('PHL312', 100);
insert into Courses_Taken values('XZY987', 100);

insert into Courses_Taken values('LAW102', 101);
insert into Courses_Taken values('PHL312', 101);
insert into Courses_Taken values('XZY987', 101);

insert into Courses_Taken values('CSC301', 102);
insert into Courses_Taken values('LAW101', 102);

insert into Courses_Taken values('PHL312', 103);
insert into Courses_Taken values('XZY987', 103);
insert into Courses_Taken values('LAW101', 103);

insert into Courses_Taken values('LAW101', 104);
insert into Courses_Taken values('XZY987', 104);

insert into Courses_Taken values('LAW101', 105);
insert into Courses_Taken values('PHL312', 105);
insert into Courses_Taken values('CSC301', 105);
insert into Courses_Taken values('XZY987', 105);