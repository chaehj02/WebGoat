-- This statement is here the schema is always created even if we use Flyway directly like in test-cases
-- For the normal WebGoat server there is a bean which already provided the schema (and creates it see DatabaseInitialization)
CREATE SCHEMA IF NOT EXISTS CONTAINER;

create table CONTAINER.assignment
(
    id   bigint generated by default as identity (start with 1),
    name varchar(255),
    path varchar(255),
    primary key (id)
);
create table CONTAINER.assignment_progress
(
    solved        boolean not null,
    assignment_id bigint unique,
    id            bigint generated by default as identity (start with 1),
    primary key (id)
);
create table CONTAINER.lesson_progress
(
    number_of_attempts integer not null,
    version            integer,
    id                 bigint generated by default as identity (start with 1),
    lesson_name        varchar(255),
    primary key (id)
);
create table CONTAINER.lesson_progress_assignments
(
    assignments_id     bigint not null unique,
    lesson_progress_id bigint not null,
    primary key (assignments_id, lesson_progress_id)
);
create table CONTAINER.user_progress
(
    id       bigint generated by default as identity (start with 1),
    username varchar(255),
    primary key (id)
);
create table CONTAINER.user_progress_lesson_progress
(
    lesson_progress_id bigint not null unique,
    user_progress_id   bigint not null,
    primary key (lesson_progress_id, user_progress_id)
);
create table CONTAINER.web_goat_user
(
    password varchar(255),
    role     varchar(255),
    username varchar(255) not null,
    primary key (username)
);

create table CONTAINER.email
(
    id        BIGINT GENERATED BY DEFAULT AS IDENTITY (START WITH 1) NOT NULL PRIMARY KEY,
    contents  VARCHAR(1024),
    recipient VARCHAR(255),
    sender    VARCHAR(255),
    time      TIMESTAMP,
    title     VARCHAR(255)
);


alter table CONTAINER.assignment_progress
    add constraint FK7o6abukma83ku3xrge9sy0qnr foreign key (assignment_id) references CONTAINER.assignment;
alter table CONTAINER.lesson_progress_assignments
    add constraint FKrw89vmnela8kj0nbg1xdws5bt foreign key (assignments_id) references CONTAINER.assignment_progress;
alter table CONTAINER.lesson_progress_assignments
    add constraint FKl8vg2qfqhmsnt18qqcyydq7iu foreign key (lesson_progress_id) references CONTAINER.lesson_progress;
alter table CONTAINER.user_progress_lesson_progress
    add constraint FKkk5vk79v4q48xb5apeq0g5t2q foreign key (lesson_progress_id) references CONTAINER.lesson_progress;
alter table CONTAINER.user_progress_lesson_progress
    add constraint FKkw1rtg14shtginbfflbglbf4m foreign key (user_progress_id) references CONTAINER.user_progress;



