CREATE TABLE agency (
    agency_id varchar NOT NULL PRIMARY KEY,
    agency_name varchar,
    agency_url varchar,
    agency_timezone varchar,
    agency_lang varchar,
    agency_phone varchar
);

CREATE TABLE calendar_base (
    monday boolean,
    tuesday boolean,
    wednesday boolean,
    thursday boolean,
    friday boolean,
    saturday boolean,
    sunday boolean,
    start_date varchar,
    end_date varchar
);

CREATE TABLE calendar (
    service_id varchar NOT NULL PRIMARY KEY
) INHERITS (calendar_base);

CREATE TABLE routes (
    route_id varchar NOT NULL PRIMARY KEY,
    agency_id varchar,
    route_short_name varchar,
    route_long_name varchar,
    route_desc varchar,
    route_type integer,
    route_url varchar,
    route_color varchar(6),
    route_text_color varchar(6),
    CONSTRAINT routes_agency FOREIGN KEY (agency_id) REFERENCES agency (agency_id) ON DELETE CASCADE
);

CREATE TABLE trips (
    trip_id varchar NOT NULL PRIMARY KEY,
    route_id varchar NOT NULL,
    service_id varchar NOT NULL,
    shape_id varchar NOT NULL,
    trip_headsign varchar,
    trip_short_name varchar,
    direction_id integer,
    block_id integer,
    wheelchair_accessible varchar,
    route_direction varchar,
    trip_note varchar,
    bikes_allowed varchar,
    vehicle_category_id varchar,
    CONSTRAINT trips_calendar FOREIGN KEY (service_id) REFERENCES calendar (service_id) ON DELETE CASCADE,
    CONSTRAINT trips_routes FOREIGN KEY (route_id) REFERENCES routes (route_id) ON DELETE CASCADE
);

CREATE TABLE stops (
    stop_id varchar NOT NULL PRIMARY KEY,
    stop_code varchar NOT NULL,
    stop_name varchar NOT NULL,
    stop_desc varchar,
    stop_lat float NOT NULL,
    stop_lon float NOT NULL,
    zone_id varchar,
    stop_url varchar,
    location_type varchar,
    parent_station varchar,
    stop_timezone varchar,
    wheelchair_boarding integer,
    CONSTRAINT stops_parent_stops FOREIGN KEY (parent_station) REFERENCES stops(stop_id) ON DELETE CASCADE
);

CREATE TABLE stop_times (
    trip_id varchar NOT NULL,
    stop_id varchar NOT NULL,
    stop_sequence integer NOT NULL,
    arrival_time varchar NOT NULL,
    departure_time varchar NOT NULL,
    stop_headsign varchar,
    pickup_type boolean,
    drop_off_type boolean,
    shape_dist_traveled varchar,
    PRIMARY KEY (trip_id, stop_sequence),
    CONSTRAINT stop_times_trips FOREIGN KEY (trip_id) REFERENCES trips (trip_id) ON DELETE CASCADE,
    CONSTRAINT stop_times_stops FOREIGN KEY (stop_id) REFERENCES stops (stop_id) ON DELETE CASCADE
);

-- CREATE TABLE occupancies (
--     trip_id varchar NOT NULL,
--     stop_sequence varchar NOT NULL,
--     occupancy_status integer,
--     exception integer,
--     PRIMARY KEY (trip_id, stop_sequence, occupancy_status, exception)
--     CONSTRAINT occupancies_trips FOREIGN KEY (trip_id) REFERENCES trips (trip_id) ON DELETE CASCADE
-- ) INHERITS (calendar_base);

CREATE TABLE shapes (
    shape_id varchar NOT NULL,
    shape_pt_lat float NOT NULL,
    shape_pt_lon float NOT NULL,
    shape_pt_sequence integer NOT NULL,
    shape_dist_traveled varchar,
    PRIMARY KEY (shape_id, shape_pt_sequence)
);

-- CREATE TABLE vehicle_categories (
--     vehicle_category_id varchar PRIMARY KEY,
--     vehicle_category_name varchar
-- );

-- CREATE TABLE vehicle_boardings (
--     vehicle_category_id varchar,
--     child_sequence integer,
--     grandchild_sequence varchar,
--     boarding_area_id varchar,
--     PRIMARY KEY (vehicle_category_id, child_sequence, grandchild_sequence, boarding_area_id)
--     CONSTRAINT vehicle_boardings_vehicle_categories FOREIGN KEY (vehicle_category_id) REFERENCES vehicle_categories (vehicle_category_id)
-- );

-- CREATE TABLE vehicle_couplings (
--     parent_id varchar,
--     child_id varchar,
--     child_sequence integer,
--     child_label varchar,
--     PRIMARY KEY (parent_id, child_id, child_sequence, child_label)
--     CONSTRAINT vehicle_couplings_parent_vehicle_categories FOREIGN KEY (parent_id) REFERENCES vehicle_categories (vehicle_category_id),
--     CONSTRAINT vehicle_couplings_child_vehicle_categories FOREIGN KEY (child_id) REFERENCES vehicle_categories (vehicle_category_id)
-- );

CREATE OR REPLACE FUNCTION parent(stops) RETURNS SETOF stops ROWS 1 AS $$
    SELECT *
    FROM stops
    WHERE ($1.parent_station IS NOT NULL AND stop_id = $1.parent_station)
        OR ($1.parent_station IS NULL AND stop_id = $1.stop_id)
$$ STABLE LANGUAGE SQL;

CREATE OR REPLACE FUNCTION children(stops) RETURNS SETOF stops AS $$
    SELECT *
    FROM stops
    WHERE (stops.parent_station IS NOT NULL AND stops.parent_station = $1.stop_id)
$$ STABLE LANGUAGE SQL;

CREATE OR REPLACE FUNCTION following_stop_times(stop_times) RETURNS SETOF stop_times AS $$
    SELECT *
    FROM stop_times
    WHERE (trip_id = $1.trip_id)
	 	AND (stop_sequence > $1.stop_sequence)
$$ STABLE LANGUAGE SQL;