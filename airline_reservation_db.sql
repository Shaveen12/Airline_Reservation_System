CREATE SCHEMA airline_reservation_db_5;

USE airline_reservation_db_5;

CREATE TABLE passenger_details (
    passenger_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(30),
    gender ENUM('Male', 'Female'),
	D_O_B DATE,
    passport_number VARCHAR(10),
    mobile_num VARCHAR(10),
    flight_count INT DEFAULT 0,
    tier ENUM('Frequent', 'Gold','Guest') DEFAULT 'Frequent'
);

create table user(
	passenger_id INT ,
    first_name VARCHAR(20),
    last_name VARCHAR(20),
    email VARCHAR(30) PRIMARY KEY,
    password VARCHAR(15),
    role enum('admin','passenger'),
    FOREIGN KEY (passenger_id) REFERENCES passenger_details(passenger_id)
);

CREATE TABLE location (
    location_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(20),
    parent_id INT,
	foreign key (parent_id) references location(location_id)
);

CREATE TABLE airport_code (
    airport_code VARCHAR(5) PRIMARY KEY ,
    location_id INT,
    FOREIGN KEY (location_id) REFERENCES location(location_id)
);

CREATE TABLE route (
    route_id INT PRIMARY KEY AUTO_INCREMENT,
    source_code VARCHAR(5),
    destination_code VARCHAR(5),
    duration TIME,
    FOREIGN KEY (source_code) REFERENCES airport_code(airport_code),
    FOREIGN KEY (destination_code) REFERENCES airport_code(airport_code)
);

CREATE TABLE model_seat (
    model VARCHAR(10)  ,
    seat_no VARCHAR(5) ,
    PRIMARY KEY(model,seat_no),
    seat_type ENUM('Business','Economy','Platinum')
);

CREATE TABLE aircraft (
    aircraft_id INT PRIMARY KEY AUTO_INCREMENT,
    brand VARCHAR(10),
    model VARCHAR(10),
    last_service_date DATE,
    purchase_date DATE,
    manufactured_date DATE,
    foreign key (model) references model_seat(model)
);

CREATE TABLE maintainance_Log (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    aircraft_id INT,
    details VARCHAR(100),
    FOREIGN KEY (aircraft_id) REFERENCES aircraft(aircraft_id)
);

CREATE TABLE schedule (
    schedule_id INT PRIMARY KEY AUTO_INCREMENT,
    route_id INT,
    aircraft_id INT,
    departure_time DATETIME,
    arrival_time DATETIME,
    status ENUM('On-time', 'Delayed', 'Cancelled'),
    economy_price INT,
    business_price INT,
    platinum_price INT,
    flight_number Varchar(5),
    FOREIGN KEY (route_id) REFERENCES route(route_id),
    FOREIGN KEY (aircraft_id) REFERENCES aircraft(aircraft_id)
);

CREATE TABLE reservation (
    reservation_id INT PRIMARY KEY AUTO_INCREMENT,
    schedule_id INT,
    seat_no VARCHAR(5),
    timestamp TIMESTAMP,
    status ENUM('Pending', 'Confirmed', 'Cancelled'),
    FOREIGN KEY (schedule_id) REFERENCES schedule(schedule_id)
);

CREATE TABLE seat (
		schedule_id INT ,
        seat_no VARCHAR(5),
        seat_type ENUM ('Platinum','Business','Economy'),
        seat_status ENUM ('Available','Occupied','Pending'),
        PRIMARY KEY (schedule_id,seat_no),
        FOREIGN KEY (schedule_id) REFERENCES schedule(schedule_id)
);

CREATE TABLE booking (
    booking_id INT PRIMARY KEY AUTO_INCREMENT,
    schedule_id INT,
    passenger_id INT,
    seat_no VARCHAR(5),
    ticket_price INT,
    booking_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (passenger_id) REFERENCES passenger_details(passenger_id),
    FOREIGN KEY (schedule_id,seat_no) REFERENCES seat(schedule_id,seat_no)
    
);

-- ---------------------------------------------------------------------------------------------------------------------------

-- aircraft

DELIMITER //
CREATE PROCEDURE add_aircraft(
    IN p_brand VARCHAR(10), 
    IN p_model VARCHAR(10), 
    IN p_last_service_date DATE, 
    IN p_purchase_date DATE, 
    IN p_manufactured_date DATE
)
BEGIN
    INSERT INTO aircraft (brand, model, last_service_date, purchase_date, manufactured_date)
    VALUES (p_brand, p_model, p_last_service_date, p_purchase_date, p_manufactured_date);
END //
DELIMITER ;

-- get brand count 

DELIMITER //
CREATE FUNCTION get_brand_count(p_brand VARCHAR(10))
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE brand_count INT;
	SELECT COUNT(aircraft_id) INTO brand_count
    FROM aircraft
    WHERE brand = p_brand;
    
    RETURN brand_count;
END //
DELIMITER ;

-- get model count 

DELIMITER //
CREATE FUNCTION get_model_count(p_model VARCHAR(10))
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE model_count INT;
	SELECT COUNT(aircraft_id) INTO model_count
    FROM aircraft
    WHERE model = p_model;
    RETURN model_count;
END //
DELIMITER ;

-- ------------------------------------------------------------------------------------------------------------------------------------

-- maintainance log 

RENAME TABLE maintainance_Log TO maintenance_log;

-- get maintainance details 

DELIMITER //
CREATE FUNCTION get_maintenance_details(p_aircraft_id INT)
RETURNS VARCHAR(200)
DETERMINISTIC
BEGIN
    DECLARE maintenance_details TEXT DEFAULT '';
    SELECT GROUP_CONCAT(details SEPARATOR '; ') INTO maintenance_details
    FROM maintenance_log
    WHERE aircraft_id = p_aircraft_id;
    RETURN maintenance_details;
END //
DELIMITER ;

-- -----------------------------------------------------------------------------------------------------------------------------------

-- location 

-- location hierarachy 

DELIMITER //
CREATE FUNCTION get_location_hierarchy(loc_id INT) 
	RETURNS varchar(255) CHARSET utf8mb4
    DETERMINISTIC
BEGIN
    DECLARE loc_name VARCHAR(255);
    DECLARE parent_loc_id INT;
    DECLARE hierarchy_name VARCHAR(255) DEFAULT '';
    
    WHILE loc_id IS NOT NULL DO
        SELECT name, parent_id INTO loc_name, parent_loc_id
        FROM location
        WHERE location_id = loc_id;
        
        -- Build the hierarchy by concatenating the current location name
        IF hierarchy_name = '' THEN
            SET hierarchy_name = loc_name;
        ELSE
            SET hierarchy_name = CONCAT(loc_name, ' > ', hierarchy_name);
        END IF;
        
        SET loc_id = parent_loc_id;
    END WHILE;

    RETURN hierarchy_name;
END//
DELIMITER ;

-- ----------------------------------------------------------------------------------------------------------------------------

-- schedule
DELIMITER //

CREATE TRIGGER add_seats_after_schedule_insert
AFTER INSERT ON schedule
FOR EACH ROW
BEGIN
    INSERT INTO seat (schedule_id, seat_no, seat_type, seat_status)
    SELECT 
        NEW.schedule_id,         
        ms.seat_no,              
        ms.seat_type,            
        'Available'              
    FROM 
        aircraft a               
    JOIN 
        model_seat ms            
    ON 
        a.model = ms.model       
    WHERE 
        a.aircraft_id = NEW.aircraft_id;  
END//

DELIMITER ;

DELIMITER //

CREATE PROCEDURE get_future_schedule_by_route_and_date_range(
    IN p_StartDate DATE,
    IN p_EndDate DATE,
    IN p_SourceAirportCode VARCHAR(10),
    IN p_DestinationAirportCode VARCHAR(10)
)
BEGIN
    SELECT
        s.schedule_id,
        s.flight_number,
        r.source_code AS source_airport_code,
        r.destination_code AS destination_airport_code,
        s.aircraft_id,
        s.departure_time,
        s.arrival_time
    FROM
        schedule s
    JOIN
        route r ON s.route_id = r.route_id
    WHERE
        s.departure_time BETWEEN p_StartDate AND p_EndDate
        AND r.source_code = p_SourceAirportCode
        AND r.destination_code = p_DestinationAirportCode
    ORDER BY
        s.departure_time;
END //

DELIMITER ;

-- ---------------------------------------------------------------------------------------------------------------------

-- seat

DELIMITER //
CREATE  PROCEDURE get_available_seats(
    IN p_Schedule_id INT,
    IN p_Seat_Class ENUM('Economy', 'Business', 'Platinum')
)
BEGIN
    SELECT seat_no
    FROM seat
    WHERE schedule_id = p_Schedule_id
    AND seat_type = p_Seat_Class
    AND seat_status = 'Available';
END //

DELITMITER ;

-- ---------------------------------------------------------------------------------------------------------------------

-- passenger details 

-- get registered user's details using passenger id

DELIMITER //
CREATE PROCEDURE get_registered_user_info(
    IN p_passenger_id INT
)
BEGIN
    SELECT *
    FROM passenger_details
    WHERE passenger_id = p_passenger_id;
END//
DELIMITER ;

-- get guesst's info using passport number

DELIMITER //
CREATE PROCEDURE get_guest_info(
    IN p_passport_number VARCHAR(10)
)
BEGIN
    SELECT *
    FROM passenger_details
    WHERE passport_number = p_passport_number
      AND tier = 'Guest';
END//
DELIMITER ;

-- get passenger's age 

DELIMITER //
CREATE FUNCTION get_passenger_age(passenger_id INT) RETURNS INT
    DETERMINISTIC
BEGIN
    DECLARE age INT;
    
    SELECT 
        YEAR('2025-01-01') - YEAR(D_O_B) - 
        (DATE_FORMAT('2025-01-01', '%m%d') < DATE_FORMAT(D_O_B, '%m%d'))
    INTO age
    FROM passenger_details
    WHERE passenger_details.passenger_id = passenger_id;

    RETURN age;
END //
DELIMITER ;

-- get flight count and tier 

CREATE VIEW passenger_summary AS
SELECT passenger_id, flight_count, tier
FROM passenger_details;

DELIMITER //
CREATE PROCEDURE get_passenger_details(IN p_passenger_id INT)
BEGIN
    SELECT flight_count, tier
    FROM passenger_details
    WHERE passenger_id = p_passenger_id;
END //
DELIMITER ;


-- --------------------------------------------------------------------------------------------------------------------------------

-- user

DELIMITER $$
CREATE PROCEDURE add_admin(
    IN p_first_name VARCHAR(20),
    IN p_last_name VARCHAR(20),
    IN p_email VARCHAR(30),
    IN p_password VARCHAR(15)
)
BEGIN
    INSERT INTO user (passenger_id, first_name, last_name, email, password, role)
    VALUES (NULL, p_first_name, p_last_name, p_email, p_password, 'Admin');
END$$
DELIMITER ;

-- get admin count 

DELIMITER //
CREATE FUNCTION get_admin_count()
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE admin_count INT;
    SELECT COUNT(DISTINCT email) INTO admin_count
    FROM user
    WHERE role = 'Admin';
    RETURN admin_count;
END //
DELIMITER ;

-- get admin info

DELIMITER //
CREATE PROCEDURE get_admin_details(IN p_email VARCHAR(30))
BEGIN
    SELECT first_name, last_name, email
    FROM user
    WHERE email = p_email AND role = 'Admin';
END //
DELIMITER ;

-- procedure register_user ( add passenger user )

DELIMITER //
CREATE PROCEDURE register_user(
    IN p_full_name VARCHAR(30),
    IN p_gender VARCHAR(6),
    IN p_DOB DATE,
    IN p_passport_number VARCHAR(10),
    IN p_mobile_num VARCHAR(10),
    IN p_first_name VARCHAR(20),
    IN p_last_name VARCHAR(20),
    IN p_email VARCHAR(30),
    IN p_password VARCHAR(15)
)
BEGIN
    DECLARE last_passenger_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction failed and rolled back';
    END;

    START TRANSACTION;

    IF p_gender NOT IN ('Male', 'Female') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid gender value';
    END IF;

    INSERT INTO passenger_details (full_name, gender, D_O_B, passport_number, mobile_num, tier)
    VALUES (p_full_name, p_gender, p_DOB, p_passport_number, p_mobile_num, 'Frequent');

    SET last_passenger_id = LAST_INSERT_ID();

    INSERT INTO user (passenger_id, first_name, last_name, email, password, role)
    VALUES (last_passenger_id, p_first_name, p_last_name, p_email, p_password, 'Passenger');

    COMMIT;

END //

DELIMITER ;

-- ------------------------------------------------------------------------------------------------------------------------

-- reservation

DELIMITER //

CREATE PROCEDURE add_reservation(
    IN p_Schedule_id INT,
    IN p_Seat_No VARCHAR(5)
)
BEGIN
    DECLARE v_Seat_Exists BOOLEAN;

    SELECT COUNT(*) INTO v_Seat_Exists
    FROM seat
    WHERE schedule_id = p_Schedule_id AND seat_no = p_Seat_No AND seat_status = 'Available';

    IF v_Seat_Exists > 0 THEN
        UPDATE seat
        SET seat_status = 'Pending'
        WHERE schedule_id = p_Schedule_id AND seat_no = p_Seat_No;

        INSERT INTO reservation (schedule_id, seat_no, timestamp, status)
        VALUES (p_Schedule_id, p_Seat_No, NOW(), 'Pending');

    ELSE
        -- Handle the case where the seat is not available
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seat not available or already reserved';
    END IF;

END //

DELIMITER ;

DELIMITER //

CREATE EVENT expire_reservations
ON SCHEDULE EVERY 1 MINUTE
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    -- Update expired reservations directly without using a cursor
    UPDATE seat
    JOIN reservation ON seat.schedule_id = reservation.schedule_id AND seat.seat_no = reservation.seat_no
    SET seat.seat_status = 'Available', reservation.status = 'Cancelled'
    WHERE reservation.status = 'Pending'
    AND reservation.timestamp < (NOW() - INTERVAL 15 MINUTE);
END //

DELIMITER ;

-- ------------------------------------------------------------------------------------------------------------------------

-- booking
-- registered user booking
DELIMITER //
CREATE PROCEDURE add_registered_booking(
    IN p_email VARCHAR(30),
    IN p_schedule_id INT,
    IN p_seat_no VARCHAR(5)
)
BEGIN
    DECLARE current_tier ENUM('Frequent', 'Gold', 'Guest');
    DECLARE current_flight_count INT;
    DECLARE v_passenger_id INT;
    DECLARE reservation_status ENUM('Pending', 'Confirmed', 'Cancelled');
    DECLARE base_price INT;
    DECLARE final_price INT;
    DECLARE s_type ENUM('Platinum', 'Business', 'Economy');

    SELECT status INTO reservation_status
    FROM reservation
    WHERE schedule_id = p_schedule_id
    AND seat_no = p_seat_no 
    AND status = 'Pending' 
    LIMIT 1;

    IF reservation_status = 'Pending' THEN

        SELECT passenger_id INTO v_passenger_id
        FROM user
        WHERE email = p_email
        LIMIT 1;  -- Ensure only one user is selected
        
		IF v_passenger_id IS NULL THEN
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Passenger does not exist with the provided email.';
        END IF;
        
        -- Determine the base price based on the seat type
        SELECT seat_type INTO s_type
        FROM seat
        WHERE schedule_id = p_schedule_id
        AND seat_no = p_seat_no
        LIMIT 1;
        
        IF s_type = 'Platinum' THEN
            SELECT platinum_price INTO base_price
            FROM schedule
            WHERE schedule_id = p_schedule_id;
        ELSEIF s_type = 'Business' THEN
            SELECT business_price INTO base_price
            FROM schedule
            WHERE schedule_id = p_schedule_id;
        ELSE
            SELECT economy_price INTO base_price
            FROM schedule
            WHERE schedule_id = p_schedule_id;
        END IF;
        
        -- Get the current tier of the passenger
        SELECT tier INTO current_tier
        FROM passenger_details
        WHERE passenger_details.passenger_id = v_passenger_id
        LIMIT 1;
        
        -- Apply discounts based on the tier of the passenger
        IF current_tier = 'Frequent' THEN
            SET final_price = base_price * 0.95;  -- 5% discount
        ELSEIF current_tier = 'Gold' THEN
            SET final_price = base_price * 0.91;  -- 9% discount
        ELSE
            SET final_price = base_price;  -- No discount for 'Guest'
        END IF;

        -- Insert the booking for the passenger
        INSERT INTO booking (passenger_id, schedule_id, seat_no, ticket_price)
        VALUES (v_passenger_id, p_schedule_id, p_seat_no, final_price);

        -- Update the flight count for the passenger
        UPDATE passenger_details
        SET flight_count = flight_count + 1
        WHERE passenger_details.passenger_id = v_passenger_id;

        -- Get the updated flight count for the passenger
        SELECT flight_count INTO current_flight_count
        FROM passenger_details
        WHERE passenger_details.passenger_id = v_passenger_id
        LIMIT 1;

        -- If the flight count is greater than 5 and the current tier is 'Frequent', upgrade to 'Gold'
        IF current_flight_count > 5 THEN
            IF current_tier = 'Frequent' THEN
                UPDATE passenger_details
                SET tier = 'Gold'
                WHERE passenger_id = v_passenger_id;
            END IF;
        END IF;
        
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Seat is not available for booking.';
    END IF;
END //
DELIMITER ;

-- guest booking

DELIMITER //
CREATE PROCEDURE add_guest_booking(
    IN p_full_name VARCHAR(30),
    IN p_gender ENUM('Male', 'Female'),
    IN p_D_O_B DATE,
    IN p_passport_number VARCHAR(10),
    IN p_mobile_num VARCHAR(10),
    IN p_schedule_id INT,
    IN p_seat_no VARCHAR(5)
)
BEGIN
    DECLARE v_passenger_id INT;
    DECLARE reservation_status ENUM('Pending', 'Confirmed', 'Cancelled');
	DECLARE s_type ENUM('Platinum', 'Business', 'Economy');
    DECLARE final_price INT;

    SELECT status INTO reservation_status
    FROM reservation
    WHERE schedule_id = p_schedule_id
    AND seat_no = p_seat_no 
    AND status = 'Pending'  
    LIMIT 1;

    IF reservation_status = 'Pending' THEN
        -- Check if the passenger exists using passport number
        IF EXISTS (SELECT 1 FROM passenger_details WHERE passport_number = p_passport_number) THEN
            -- Retrieve the passenger_id if the passenger exists
            SELECT passenger_id INTO v_passenger_id
            FROM passenger_details
            WHERE passport_number = p_passport_number;

            -- Update the passenger's details if needed
            UPDATE passenger_details
            SET full_name = IF(full_name <> p_full_name, p_full_name, full_name),
                gender = IF(gender <> p_gender, p_gender, gender),
                D_O_B = IF(D_O_B <> p_D_O_B, p_D_O_B, D_O_B),
                mobile_num = IF(mobile_num <> p_mobile_num, p_mobile_num, mobile_num)
            WHERE passport_number = p_passport_number;
        ELSE
            -- Insert a new passenger if they don't exist
            INSERT INTO passenger_details (full_name, gender, D_O_B, passport_number, mobile_num, tier)
            VALUES (p_full_name, p_gender, p_D_O_B, p_passport_number, p_mobile_num, 'Guest');

            -- Get the new passenger_id of the inserted passenger
            SET v_passenger_id = LAST_INSERT_ID();
        END IF;
        
        -- Get the seat type for the selected seat
        SELECT seat_type INTO s_type
        FROM seat
        WHERE schedule_id = p_schedule_id
        AND seat_no = p_seat_no
        LIMIT 1;
        
        IF s_type = 'Platinum' THEN
            SELECT platinum_price INTO final_price
            FROM schedule
            WHERE schedule_id = p_schedule_id;
        ELSEIF s_type = 'Business' THEN
            SELECT business_price INTO final_price
            FROM schedule
            WHERE schedule_id = p_schedule_id;
        ELSE
            SELECT economy_price INTO final_price
            FROM schedule
            WHERE schedule_id = p_schedule_id;
        END IF;

        -- Add the booking for the passenger
        INSERT INTO booking (passenger_id, schedule_id, seat_no, ticket_price)
        VALUES (v_passenger_id, p_schedule_id, p_seat_no, final_price);

    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Seat is not available for booking. Reservation status is not pending.';
    END IF;

END //
DELIMITER ;

-- change seat status when an entry added to the booking

DELIMITER //
 
CREATE TRIGGER after_booking_insert
AFTER INSERT ON booking
FOR EACH ROW
BEGIN
   
    UPDATE seat s
    SET s.seat_status = 'Occupied'
    WHERE s.schedule_id = NEW.schedule_id
    AND s.seat_no = NEW.seat_no;

    
    UPDATE reservation r
    JOIN (
        SELECT MAX(reservation_id) AS latest_reservation_id
        FROM reservation
        WHERE schedule_id = NEW.schedule_id
        AND seat_no = NEW.seat_no
    ) AS latest_reservation
    ON r.reservation_id = latest_reservation.latest_reservation_id
    SET r.status = 'Confirmed';
END//

DELIMITER ;

-- ---------------------------------------------------------------------------------------------------------------------------------------
-- model seat 

CREATE VIEW seat_count AS
SELECT 
    model, 
    seat_type, 
    COUNT(seat_no) AS number_of_seats
FROM 
    model_seat
GROUP BY 
    model, 
    seat_type;

-- 737

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_737()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 160 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('737', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_737()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 20 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('737', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_737()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 10 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('737', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- 757

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_757()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 180 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('757', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_757()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 20 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('757', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_757()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 15 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('757', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;


-- A380

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_A380()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 400 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A380', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_A380()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 50 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A380', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_A380()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 20 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A380', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- 747

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_747()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 400 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('747', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_747()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 40 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('747', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_747()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 20 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('747', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- A320

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_A320()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 150 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A320', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_A320()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 20 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A320', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_A320()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 10 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A320', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- 787

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_787()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 240 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('787', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_787()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 30 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('787', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_787()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 15 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('787', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- 777

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_777()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 350 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('777', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_777()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 40 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('777', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_777()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 25 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('777', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- A350

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_A350()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 300 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A350', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_A350()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 30 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A350', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_A350()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 20 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A350', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- E190

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_E190()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 100 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('E190', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_E190()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 10 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('E190', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_E190()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 5 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('E190', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- CRJ900

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_CRJ900()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 90 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('CRJ900', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_CRJ900()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 10 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('CRJ900', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_CRJ900()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 5 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('CRJ900', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- 767

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_767()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 200 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('767', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_767()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 30 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('767', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_767()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 15 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('767', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- A330

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_A330()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 250 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A330', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_A330()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 40 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A330', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_A330()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 20 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('A330', CONCAT('P',i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- 737MAX

DELIMITER $$

CREATE PROCEDURE insert_economy_seats_737MAX()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 175 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('737MAX', CONCAT('E',i), 'Economy');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_business_seats_737MAX()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 20 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('737MAX', CONCAT('B',i), 'Business');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE insert_platinum_seats_737MAX()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 10 DO
        INSERT INTO model_seat (model, seat_no, seat_type)
        VALUES ('737MAX', CONCAT('P', i), 'Platinum');
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;
-- ---------------------------------------------------------------------------------------------------------------------------------------

-- insert data

-- model seat

START TRANSACTION;

		CALL insert_economy_seats_737;
        CALL insert_business_seats_737;
        CALL insert_platinum_seats_737;
	
		CALL insert_economy_seats_A380;
        CALL insert_business_seats_A380;
        CALL insert_platinum_seats_A380;
 
		CALL insert_economy_seats_757;
        CALL insert_business_seats_757;
        CALL insert_platinum_seats_757;
        
		CALL insert_economy_seats_747;
        CALL insert_business_seats_747;
        CALL insert_platinum_seats_747;

		CALL insert_economy_seats_A320;
        CALL insert_business_seats_A320;
        CALL insert_platinum_seats_A320;
	
		CALL insert_economy_seats_787;
        CALL insert_business_seats_787;
        CALL insert_platinum_seats_787;

		CALL insert_economy_seats_777;
        CALL insert_business_seats_777;
        CALL insert_platinum_seats_777;

		CALL insert_economy_seats_A350;
        CALL insert_business_seats_A350;
        CALL insert_platinum_seats_A350;
	
		CALL insert_economy_seats_E190;
        CALL insert_business_seats_E190;
        CALL insert_platinum_seats_E190;
	 
		CALL insert_economy_seats_CRJ900;
        CALL insert_business_seats_CRJ900;
        CALL insert_platinum_seats_CRJ900;
	
		CALL insert_economy_seats_767;
        CALL insert_business_seats_767;
        CALL insert_platinum_seats_767;
	
		CALL insert_economy_seats_A330;
        CALL insert_business_seats_A330;
        CALL insert_platinum_seats_A330;
 
		CALL insert_economy_seats_737MAX;
        CALL insert_business_seats_737MAX;
        CALL insert_platinum_seats_737MAX;
        
COMMIT;

-- aircraft 

-- Insert 3 Boeing 737 aircrafts
INSERT INTO aircraft (aircraft_id, brand, model, last_service_date, purchase_date, manufactured_date)
VALUES 
(1, 'Boeing', '737', '2024-01-10', '2020-03-15', '2019-08-01'),
(2, 'Boeing', '737', '2023-12-20', '2021-07-12', '2020-04-18'),
(3, 'Boeing', '737', '2024-02-05', '2022-01-20', '2021-05-30');

-- Insert 4 Boeing 757 aircrafts
INSERT INTO aircraft (aircraft_id, brand, model, last_service_date, purchase_date, manufactured_date)
VALUES 
(4, 'Boeing', '757', '2024-03-01', '2019-05-10', '2018-09-15'),
(5, 'Boeing', '757', '2024-04-12', '2020-08-23', '2019-11-05'),
(6, 'Boeing', '757', '2023-11-28', '2021-02-14', '2020-07-07'),
(7, 'Boeing', '757', '2024-05-22', '2021-09-30', '2020-12-22');

-- Insert 1 Airbus A380 aircraft
INSERT INTO aircraft (aircraft_id, brand, model, last_service_date, purchase_date, manufactured_date)
VALUES 
(8, 'Airbus', 'A380', '2024-06-10', '2023-01-05', '2022-03-11');

-- Inserting already existing aircrafts
-- Insert additional aircraft records
INSERT INTO aircraft (aircraft_id, brand, model, last_service_date, purchase_date, manufactured_date)
VALUES 
(9, 'Boeing', '747', '2024-07-15', '2018-10-10', '2017-01-01'),  -- Boeing 747
(10, 'Airbus', 'A320', '2024-08-20', '2020-05-15', '2019-03-20'),  -- Airbus A320
(11, 'Boeing', '787', '2024-09-05', '2021-02-10', '2020-11-30'),  -- Boeing 787 Dreamliner
(12, 'Boeing', '777', '2024-08-25', '2019-06-22', '2018-12-05'),  -- Boeing 777
(13, 'Airbus', 'A350', '2024-09-15', '2020-04-10', '2019-06-18'),  -- Airbus A350
(14, 'Embraer', 'E190', '2024-06-30', '2022-08-12', '2021-01-25'), -- Embraer E190
(15, 'Bombardier', 'CRJ900', '2024-07-05', '2021-11-15', '2020-02-22'), -- Bombardier CRJ900
(16, 'Boeing', '767', '2024-05-20', '2019-12-30', '2018-04-01'),  -- Boeing 767
(17, 'Airbus', 'A330', '2024-06-10', '2020-09-05', '2019-05-15'), -- Airbus A330
(18, 'Boeing', '737MAX', '2024-08-15', '2021-03-28', '2020-02-11');  -- Boeing 737 MAX

-- -----------------------------------------------------------------------------------------------------------------------------

-- insert into maintenance_log

INSERT INTO maintenance_log (log_id, aircraft_id, details) 
VALUES 
(1, 9, 'Routine check and oil change performed on 2024-07-15.'),
(2, 10, 'Replaced two tires and checked hydraulic systems on 2024-08-20.'),
(3, 11, 'Full service including engine check and system diagnostics on 2024-09-05.'),
(4, 12, 'Checked avionics and performed routine inspections on 2024-08-25.'),
(5, 13, 'Carried out cabin pressure test and engine service on 2024-09-15.'),
(6, 14, 'General maintenance and seat configuration adjustments on 2024-06-30.'),
(7, 15, 'Checked fuel system and replaced filters on 2024-07-05.'),
(8, 16, 'Routine maintenance, including inspections of wings and fuselage on 2024-05-20.'),
(9, 17, 'Performed avionics updates and safety checks on 2024-06-10.'),
(10, 18, 'Engine overhaul and replacement of critical components on 2024-08-15.');

-- -------------------------------------------------------------------------------------------------------------------------------

-- insert into location 

-- insert countries 
INSERT INTO location (Location_id, name, parent_id) VALUES 
       (1, 'Indonesia', null),
       (2, 'Sri Lanka', null),
       (3, 'India', null),
       (4, 'Singapore', null),
       (5, 'Thailand', null);

-- insert states 

-- Insert states in Indonesia
INSERT INTO location (Location_id, name, parent_id) VALUES
       (6, 'Jakarta.S.C.R', 1),  -- State for CGK
       (7, 'Bali', 1),                           -- State for DPS
       (8, 'East Java', 1),                      -- State for SUB
       (9, 'North Sumatra', 1),                  -- State for KNO
       (10, 'Special.R.o.Y', 1),   -- State for JOG
       (11, 'South Sulawesi', 1),                 -- State for UPG
       (12, 'East Kalimantan', 1);                -- State for BPN
       
-- Insert states for other countries
INSERT INTO location (Location_id, name, parent_id) VALUES
       (13, 'Delhi NCR', 3),          -- State for DEL (India)
       (14, 'Maharashtra', 3),        -- State for BOM (India)
       (15, 'Tamil Nadu', 3),         -- State for MAA (India)
       (16, 'Central Singapore', 4),  -- State for SIN (Singapore)
       (17, 'Bangkok.M.R', 5); -- State for BKK and DMK (Thailand)


-- insert airports 

-- insert airports in indonesia 
INSERT INTO location (Location_id, name, parent_id) VALUES
       (18, 'Jakarta', 6),   -- CGK
       (19, 'Denpasar', 7),  -- DPS
       (20, 'Surabaya', 8),  -- SUB
       (21, 'Medan', 9),     -- KNO
       (22, 'Yogyakarta', 10),-- JOG
       (23, 'Makassar', 11),  -- UPG
       (24, 'Balikpapan', 12);-- BPN

-- insert other airports 
INSERT INTO location (Location_id, name, parent_id) VALUES
       (27, 'Colombo', 2),   -- BIA
       (28, 'Hambantota', 2),-- HRI
       (29, 'Delhi', 13),     -- DEL
       (30, 'Mumbai', 14),    -- BOM 
       (31, 'Chennai', 15),   -- MAA
       (32, 'Singapore', 16), -- SIN
       (33, 'Bangkok', 17),   -- BKK
       (34, 'Don Mueang', 17);-- DMK
       
-- ----------------------------------------------------------------------------------------------------------------------------

-- insert into airport code

-- Insert airport codes for Indonesia
INSERT INTO airport_code (airport_code, location_id) VALUES
       ('CGK', 18),   -- Jakarta
       ('DPS', 19),   -- Denpasar
       ('SUB', 20),   -- Surabaya
       ('KNO', 21),   -- Medan
       ('JOG', 22),   -- Yogyakarta
       ('UPG', 23),   -- Makassar
       ('BPN', 24);   -- Balikpapan

-- Insert airport codes for other locations
INSERT INTO airport_code (Airport_code, location_id) VALUES
       ('BIA', 27),   -- Colombo
       ('HRI', 28),   -- Hambantota
       ('DEL', 29),   -- Delhi
       ('BOM', 30),   -- Mumbai
       ('MAA', 31),   -- Chennai
       ('SIN', 32),   -- Singapore
       ('BKK', 33),   -- Bangkok
       ('DMK', 34);   -- Don Mueang

-- ----------------------------------------------------------------------------------------------------------------------------------

-- insert into route 

-- Insert routes within Indonesia
INSERT INTO route (route_id, source_code, destination_code, duration) VALUES
       (1, 'CGK', 'DPS', '01:30:00'),  -- Jakarta to Denpasar
       (2, 'DPS', 'SUB', '01:20:00'),  -- Denpasar to Surabaya
       (3, 'SUB', 'JOG', '00:45:00'),  -- Surabaya to Yogyakarta
       (4, 'JOG', 'KNO', '01:10:00'),  -- Yogyakarta to Medan
       (5, 'KNO', 'UPG', '01:50:00'),  -- Medan to Makassar
       (6, 'UPG', 'BPN', '01:30:00'),  -- Makassar to Balikpapan
       (7, 'BPN', 'CGK', '02:00:00');  -- Balikpapan to Jakarta

-- Insert routes connecting Indonesia to other countries
INSERT INTO route (route_id, source_code, destination_code, duration) VALUES
       (8, 'CGK', 'BIA', '03:30:00'),  -- Jakarta to Colombo
       (9, 'DPS', 'HRI', '03:00:00'),  -- Denpasar to Hambantota
       (10, 'CGK', 'DEL', '05:00:00'), -- Jakarta to Delhi
       (11, 'DPS', 'BOM', '06:00:00'), -- Denpasar to Mumbai
       (12, 'DPS', 'MAA', '05:30:00'), -- Denpasar to Chennai
       (13, 'DPS', 'BKK', '03:00:00'), -- Denpasar to Bangkok
       (14, 'CGK', 'DMK', '03:15:00'), -- Jakarta to Don Mueang
       (15, 'CGK', 'SIN', '03:45:00');  -- Jakarta to Singapore
       
       
-- ---------------------------------------------------------------------------------------------------------------------

-- insert into schedule

INSERT INTO schedule (route_id, aircraft_id, departure_time, arrival_time, status, economy_price, business_price, platinum_price, flight_number) VALUES
(1, 1, '2024-11-01 08:00:00', '2024-11-01 09:30:00', 'On-time', 300, 750, 1100, 'FL001'), -- CGK to DPS
(2, 1, '2024-11-01 10:30:00', '2024-11-01 11:50:00', 'On-time', 280, 730, 1050, 'FL002'), -- DPS to SUB
(3, 2, '2024-11-01 13:00:00', '2024-11-01 13:45:00', 'On-time', 270, 720, 1030, 'FL003'), -- SUB to JOG
(4, 2, '2024-11-01 15:00:00', '2024-11-01 16:10:00', 'On-time', 290, 740, 1080, 'FL004'), -- JOG to KNO
(5, 3, '2024-11-01 18:00:00', '2024-11-01 19:50:00', 'On-time', 310, 760, 1120, 'FL005'), -- KNO to UPG
(6, 3, '2024-11-02 07:00:00', '2024-11-02 08:30:00', 'On-time', 330, 770, 1150, 'FL006'), -- UPG to BPN
(7, 4, '2024-11-02 10:00:00', '2024-11-02 12:00:00', 'On-time', 320, 780, 1180, 'FL007'), -- BPN to CGK
(8, 5, '2024-11-02 13:30:00', '2024-11-02 17:00:00', 'On-time', 400, 900, 1300, 'FL008'), -- CGK to BIA
(9, 6, '2024-11-02 08:00:00', '2024-11-02 11:00:00', 'On-time', 380, 880, 1250, 'FL009'), -- DPS to HRI
(10, 7, '2024-11-02 15:00:00', '2024-11-02 20:00:00', 'On-time', 460, 940, 1360, 'FL010'), -- DEL to CGK
(11, 8, '2024-11-03 09:00:00', '2024-11-03 15:00:00', 'On-time', 450, 980, 1400, 'FL011'), -- BOM to DPS
(12, 5, '2024-11-03 15:00:00', '2024-11-03 20:30:00', 'On-time', 530, 1060, 1590, 'FL012'), -- DPS to MAA
(13, 6, '2024-11-03 10:30:00', '2024-11-03 13:30:00', 'On-time', 410, 950, 1350, 'FL013'), -- BKK to DPS
(14, 7, '2024-11-03 14:15:00', '2024-11-03 17:30:00', 'On-time', 430, 970, 1380, 'FL014'), -- DMK to CGK
(15, 8, '2024-11-04 09:00:00', '2024-11-04 12:45:00', 'On-time', 420, 990, 1410, 'FL015'), -- SIN to BIA
(2, 9, '2024-11-04 07:30:00', '2024-11-04 08:50:00', 'On-time', 300, 750, 1130, 'FL016'), -- DPS to SUB
(4, 10, '2024-11-04 11:00:00', '2024-11-04 12:10:00', 'On-time', 270, 730, 1080, 'FL017'), -- JOG to KNO
(5, 11, '2024-11-04 14:00:00', '2024-11-04 15:50:00', 'On-time', 290, 760, 1150, 'FL018'), -- KNO to UPG
(6, 12, '2024-11-04 16:30:00', '2024-11-04 18:00:00', 'On-time', 350, 810, 1200, 'FL019'), -- UPG to BPN
(7, 13, '2024-11-05 05:00:00', '2024-11-05 07:00:00', 'On-time', 370, 830, 1250, 'FL020'); -- BPN to CGK

-- flights at the same route at different time
INSERT INTO schedule (route_id, aircraft_id, departure_time, arrival_time, status, economy_price, business_price, platinum_price, flight_number) VALUES
(10, 7, '2024-11-05 17:00:00', '2024-11-05 22:00:00', 'On-time', 460, 940, 1360, 'FL021'), -- DEL to CGKscheduleschedule
(11, 8, '2024-11-06 11:00:00', '2024-11-06 17:00:00', 'On-time', 450, 980, 1400, 'FL022'), -- BOM to DPS
(12, 5, '2024-11-06 17:00:00', '2024-11-06 22:30:00', 'On-time', 530, 1060, 1590, 'FL023'), -- DPS to MAA
(13, 6, '2024-11-07 12:30:00', '2024-11-07 15:30:00', 'On-time', 410, 950, 1350, 'FL024'), -- BKK to DPS
(14, 7, '2024-11-07 16:15:00', '2024-11-07 19:30:00', 'On-time', 430, 970, 1380, 'FL025'), -- DMK to CGK
(15, 8, '2024-11-07 11:00:00', '2024-11-07 14:45:00', 'On-time', 420, 990, 1410, 'FL026'); -- SIN to BIA

INSERT INTO schedule (route_id, aircraft_id, departure_time, arrival_time, status, economy_price, business_price, platinum_price, flight_number) VALUES
(3, 2, '2024-10-25 14:00:00', '2024-10-25 14:45:00', 'On-time', 270, 720, 1000, 'FL027'), -- SUB to JOG
(4, 2, '2024-10-26 07:30:00', '2024-10-26 08:40:00', 'Delayed', 320, 780, 1150, 'FL028'), -- JOG to KNO 
(5, 3, '2024-10-27 16:00:00', '2024-10-27 17:50:00', 'On-time', 290, 740, 1100, 'FL029'), -- KNO to UPG
(3, 3, '2024-10-28 11:45:00', '2024-10-28 13:15:00', 'On-time', 270, 720, 1000, 'FL030'), -- UPG to BPN
(4, 1, '2024-10-29 09:00:00', '2024-10-29 11:00:00', 'On-time', 320, 780, 1150, 'FL031'), -- BPN to CGK
(3, 2, '2024-10-30 10:00:00', '2024-10-30 13:30:00', 'On-time', 270, 720, 1000, 'FL032'), -- CGK to BIA
(9, 2, '2024-10-31 12:00:00', '2024-10-31 15:00:00', 'Cancelled', 320, 790, 1150, 'FL033'), -- DPS to HRI
(10, 3, '2024-11-01 13:00:00', '2024-11-01 18:00:00', 'On-time', 350, 850, 1250, 'FL034'), -- DEL to CGK
(11, 3, '2024-10-26 22:00:00', '2024-10-27 04:00:00', 'On-time', 360, 880, 1300, 'FL035'), -- BOM to DPS 
(12, 1, '2024-10-27 17:30:00', '2024-10-27 23:00:00', 'On-time', 345, 840, 1225, 'FL036'); -- MAA to DPS


-- --------------------------------------------------------------------------------------------------------------------------

-- insert into user 

CALL register_user('Ella Hill', 'Female', '1981-04-14', 'ID1234587', '0712345698', 'Ella', 'Hill', 'ellahill@example.com', 'Ab7!Mz3#Kf8r');
CALL register_user('Benjamin Hall', 'Male', '1990-09-06', 'ID1234588', '0712345699', 'Benjamin', 'Hall', 'benjaminhall@example.com', 'Wy6$Rn2@Hp5j');
CALL register_user('Avery Adams', 'Female', '1986-12-20', 'ID1234589', '0712345700', 'Avery', 'Adams', 'averyadams@example.com', 'Le8#Tz1!Vx9k');
CALL register_user('Logan Phillips', 'Male', '1978-05-18', 'ID1234590', '0712345701', 'Logan', 'Phillips', 'loganphillips@example.com', 'Qp3%Xs7@Bj4n');
CALL register_user('Grace Allen', 'Female', '1995-03-02', 'ID1234591', '0712345702', 'Grace', 'Allen', 'graceallen@example.com', 'Vd9@Kl6#Cp2y');
CALL register_user('Jackson Wright', 'Male', '1982-07-15', 'ID1234592', '0712345703', 'Jackson', 'Wright', 'jacksonwright@example.com', 'Mz4^Tr8@Qx5b');
CALL register_user('Scarlett Mitchell', 'Female', '1989-11-26', 'ID1234593', '0712345704', 'Scarlett', 'Mitchell', 'scarlettmitchell@example.com', 'Rn5!Vp3$Lz7x');
CALL register_user('Henry Carter', 'Male', '1983-01-09', 'ID1234594', '0712345705', 'Henry', 'Carter', 'henrycarter@example.com', 'Cb1$Mz9#Tq4x');
CALL register_user('Evelyn Perez', 'Female', '1993-08-14', 'ID1234595', '0712345706', 'Evelyn', 'Perez', 'evelynperez@example.com', 'Xp6!Vr2%Jb3l');
CALL register_user('Alexander Roberts', 'Male', '1987-04-03', 'ID1234596', '0712345707', 'Alexander', 'Roberts', 'alexanderroberts@example.com', 'Fk4@Ys9^Pq7v');
CALL register_user('Isabella Green', 'Female', '1988-10-12', 'ID1234597', '0712345708', 'Isabella', 'Green', 'isabellagreen@example.com', 'Wd8#Lj5!Rb2y');
CALL register_user('Sebastian King', 'Male', '1991-06-28', 'ID1234598', '0712345709', 'Sebastian', 'King', 'sebastianking@example.com', 'Yr3!Vx9@Bl6m');
CALL register_user('Sofia Hernandez', 'Female', '1985-02-25', 'ID1234599', '0712345710', 'Sofia', 'Hernandez', 'sofiahernandez@example.com', 'Pk7$Qr4#Vy8w');
CALL register_user('James Lee', 'Male', '1992-05-14', 'ID1234600', '0712345711', 'James', 'Lee', 'jameslee@example.com', 'Np1%Tr5@Yk9j');
CALL register_user('Harper Walker', 'Female', '1994-07-22', 'ID1234601', '0712345712', 'Harper', 'Walker', 'harperwalker@example.com', 'Gj8@Lp6#Vz4c');
CALL register_user('Owen Young', 'Male', '1983-09-30', 'ID1234602', '0712345713', 'Owen', 'Young', 'owenyoung@example.com', 'Mx3!Wr9@Tl7k');
CALL register_user('Amelia Scott', 'Female', '1989-03-19', 'ID1234603', '0712345714', 'Amelia', 'Scott', 'ameliascott@example.com', 'Ql9@Nx6!Cb1z');
CALL register_user('Elijah Harris', 'Male', '1979-11-03', 'ID1234604', '0712345715', 'Elijah', 'Harris', 'elijahharris@example.com', 'Cp2#Jx4$Tn9y');
CALL register_user('Aubrey Lewis', 'Female', '1996-01-17', 'ID1234605', '0712345716', 'Aubrey', 'Lewis', 'aubreylewis@example.com', 'Vz6!Yr8@Pk5b');
CALL register_user('William Thomas', 'Male', '1984-02-27', 'ID1234606', '0712345717', 'William', 'Thomas', 'williamthomas@example.com', 'Nl4@Vp7%Rx2m');
CALL register_user('Zoey Nelson', 'Female', '1987-12-08', 'ID1234607', '0712345718', 'Zoey', 'Nelson', 'zoeynelson@example.com', 'Lx1$Tz3!Rq9v');
CALL register_user('Daniel Moore', 'Male', '1993-04-21', 'ID1234608', '0712345719', 'Daniel', 'Moore', 'danielmoore@example.com', 'Yr7#Fx5@Lp8q');
CALL register_user('Lily Jackson', 'Female', '1986-08-30', 'ID1234609', '0712345720', 'Lily', 'Jackson', 'lilyjackson@example.com', 'Tk3%Vz4@Ly9b');
CALL register_user('Mason Martin', 'Male', '1981-10-07', 'ID1234610', '0712345721', 'Mason', 'Martin', 'masonmartin@example.com', 'Cb9@Wr5!Px2k');
CALL register_user('Chloe White', 'Female', '1990-06-13', 'ID1234611', '0712345722', 'Chloe', 'White', 'chloewhite@example.com', 'Gx2$Lj8@Ry4p');
CALL register_user('Lucas Thompson', 'Male', '1994-09-18', 'ID1234612', '0712345723', 'Lucas', 'Thompson', 'lucasthompson@example.com', 'Pk4!Mt7#Qx6c');
CALL register_user('Layla Anderson', 'Female', '1988-11-29', 'ID1234613', '0712345724', 'Layla', 'Anderson', 'laylaanderson@example.com', 'Nr6$Lp2@Vz8w');
CALL register_user('David Martinez', 'Male', '1977-12-15', 'ID1234614', '0712345725', 'David', 'Martinez', 'davidmartinez@example.com', 'Bx1@Yp9%Kl3t');
CALL register_user('Luna Robinson', 'Female', '1985-05-24', 'ID1234615', '0712345726', 'Luna', 'Robinson', 'lunarobinson@example.com', 'Vz5#Ql8@Pk1c');
CALL register_user('Carter Perez', 'Male', '1983-03-01', 'ID1234616', '0712345727', 'Carter', 'Perez', 'carterperez@example.com', 'Jk7%Mx2@Vp4l');
CALL register_user('Hannah Evans', 'Female', '1992-07-04', 'ID1234617', '0712345728', 'Hannah', 'Evans', 'hannahevans@example.com', 'Xp9@Ty5$Wr3c');
CALL register_user('Jack Rodriguez', 'Male', '1986-10-16', 'ID1234618', '0712345729', 'Jack', 'Rodriguez', 'jackrodriguez@example.com', 'Qr3%Vz8#Lp1k');
CALL register_user('Aria Garcia', 'Female', '1989-01-31', 'ID1234619', '0712345730', 'Aria', 'Garcia', 'ariagarcia@example.com', 'Jt5!Ly4@Vz9c');
CALL register_user('Leo Lopez', 'Male', '1995-08-09', 'ID1234620', '0712345731', 'Leo', 'Lopez', 'leolopez@example.com', 'Yk8@Qr6%Nx3v');
CALL register_user('Dylan Clark', 'Male', '1978-02-23', 'ID1234620', '0712345731', 'Dylan', 'Clark', 'dylanclark@example.com', 'Xr8@Nd6!Jk3w');
CALL register_user('Zoe Lewis', 'Female', '1995-04-12', 'ID1234621', '0712345732', 'Zoe', 'Lewis', 'zoelewis@example.com', 'Fy3%Gm9!Zx4p');
CALL register_user('Nathan Allen', 'Male', '1981-06-19', 'ID1234622', '0712345733', 'Nathan', 'Allen', 'nathanallen@example.com', 'Qk5^Vx2!Pw7z');
CALL register_user('Ava Wright', 'Female', '1988-08-30', 'ID1234623', '0712345734', 'Ava', 'Wright', 'avawright@example.com', 'Hr6!Mx1#Lp8v');
CALL register_user('Gabriel King', 'Male', '1991-10-14', 'ID1234624', '0712345735', 'Gabriel', 'King', 'gabrielking@example.com', 'Xp3$Nt7@Ry4k');
CALL register_user('Madison Scott', 'Female', '1984-12-29', 'ID1234625', '0712345736', 'Madison', 'Scott', 'madisonscott@example.com', 'Jm9#Qz5!Tp2x');
CALL register_user('Matthew Harris', 'Male', '1986-04-20', 'ID1234626', '0712345737', 'Matthew', 'Harris', 'matthewharris@example.com', 'Vs7@Lk4#Qy6c');
CALL register_user('Ella Thompson', 'Female', '1990-07-11', 'ID1234627', '0712345738', 'Ella', 'Thompson', 'ellathompson@example.com', 'Gr2$Xn8!Jz1k');
CALL register_user('Isaac Martinez', 'Male', '1993-03-09', 'ID1234628', '0712345739', 'Isaac', 'Martinez', 'isaacmartinez@example.com', 'Pw6#Vz4@Xj3m');
CALL register_user('Emily Anderson', 'Female', '1985-05-05', 'ID1234629', '0712345740', 'Emily', 'Anderson', 'emilyanderson@example.com', 'Mq5@Ln2!Xv9y');
CALL register_user('Wyatt Garcia', 'Male', '1983-09-27', 'ID1234630', '0712345741', 'Wyatt', 'Garcia', 'wyattgarcia@example.com', 'Vn8#Jx6!Tp3y');
CALL register_user('Victoria Lewis', 'Female', '1991-01-03', 'ID1234631', '0712345742', 'Victoria', 'Lewis', 'victorialewis@example.com', 'Lp1@Vz9#Kr6x');
CALL register_user('Ethan White', 'Male', '1989-07-15', 'ID1234632', '0712345743', 'Ethan', 'White', 'ethanwhite@example.com', 'Qr8%Ty5!Wz3l');
CALL register_user('Penelope Walker', 'Female', '1992-11-09', 'ID1234633', '0712345744', 'Penelope', 'Walker', 'penelopewalker@example.com', 'Gs3!Kp7@Lx9m');
CALL register_user('Lucas Rodriguez', 'Male', '1980-12-24', 'ID1234634', '0712345745', 'Lucas', 'Rodriguez', 'lucasrodriguez@example.com', 'Wk4@Nl6#Vz8x');
CALL register_user('Lillian Hall', 'Female', '1994-03-17', 'ID1234635', '0712345746', 'Lillian', 'Hall', 'lillianhall@example.com', 'Fk3$Jz5@Qy9v');
CALL register_user('Caleb Scott', 'Male', '1987-06-23', 'ID1234636', '0712345747', 'Caleb', 'Scott', 'calebscott@example.com', 'Lp6!Gx7@Vt1m');
CALL register_user('Grace Harris', 'Female', '1982-04-05', 'ID1234637', '0712345748', 'Grace', 'Harris', 'graceharris@example.com', 'Nr9#Xk2!Qy8j');
CALL register_user('Julian Turner', 'Male', '1990-09-12', 'ID1234638', '0712345749', 'Julian', 'Turner', 'julianturner@example.com', 'Ws8@Pl3%Mx7c');
CALL register_user('Aria Young', 'Female', '1986-11-02', 'ID1234639', '0712345750', 'Aria', 'Young', 'ariayoung@example.com', 'Gk1#Wr9@Lx5z');
CALL register_user('Gabriel Walker', 'Male', '1988-03-30', 'ID1234640', '0712345751', 'Gabriel', 'Walker', 'gabrielwalker@example.com', 'Jp5@Qy8!Xk6r');
CALL register_user('Samantha Allen', 'Female', '1993-06-17', 'ID1234641', '0712345752', 'Samantha', 'Allen', 'samanthaallen@example.com', 'Tp2$Xj9@Lk4v');
CALL register_user('Jacob Martinez', 'Male', '1979-02-14', 'ID1234642', '0712345753', 'Jacob', 'Martinez', 'jacobmartinez@example.com', 'Vl7@Nq5#Mx1y');
CALL register_user('Avery Wright', 'Female', '1984-12-04', 'ID1234643', '0712345754', 'Avery', 'Wright', 'averywright@example.com', 'Rq9#Vl3@Np6x');
CALL register_user('Michael Harris', 'Male', '1985-06-30', 'ID1234644', '0712345755', 'Michael', 'Harris', 'michaelharris@example.com', 'Mx5@Tp8!Qr2k');
CALL register_user('Isla Robinson', 'Female', '1988-10-23', 'ID1234645', '0712345756', 'Isla', 'Robinson', 'islarobinson@example.com', 'Jx4!Vz1#Qy9k');
CALL register_user('Christopher Thomas', 'Male', '1991-08-11', 'ID1234646', '0712345757', 'Christopher', 'Thomas', 'christopherthomas@example.com', 'Xy2$Kp9@Ml3c');
CALL register_user('Natalie King', 'Female', '1990-02-18', 'ID1234647', '0712345758', 'Natalie', 'King', 'natalieking@example.com', 'Ls1@Nz8#Vr6k');
CALL register_user('Luke Walker', 'Male', '1995-09-22', 'ID1234648', '0712345759', 'Luke', 'Walker', 'lukewalker@example.com', 'Gp6@Ml5!Jx3v');


CALL add_admin('Ahmad', 'Pratama', 'ahmad.pratama@office.com', 'Qm7#xB9!vR2f');
CALL add_admin('Siti', 'Nurhaliza', 'siti.nurhaliza@office.com', 'Lc8$Np4^Zt6Q');
CALL add_admin('Rizki', 'Santoso', 'rizki.santoso@office.com', 'Wd2!Mk7#Yo9z');
CALL add_admin('Ayu', 'Lestari', 'ayu.lestari@office.com', 'Ba5^Tx8@Rf3w');
CALL add_admin('Budi', 'Gunawan', 'budi.gunawan@office.com', 'Pg6$Hy9!Qz1j');
CALL add_admin('Dewi', 'Puspita', 'dewi.puspita@office.com', 'Kx9@Rm5#Zv2n');
CALL add_admin('Hendra', 'Wijaya', 'hendra.wijaya@office.com', 'Fd7%Lj3!Xq8p');
CALL add_admin('Indah', 'Permata', 'indah.permata@office.com', 'Ha2^Zo4@Tr5m');
CALL add_admin('Joko', 'Suyono', 'joko.suyono@office.com', 'Ny1#Jq6!Ub8v');
CALL add_admin('Lia', 'Wulandari', 'lia.wulandari@office.com', 'Xo3!Cr7^Vk9z');
CALL add_admin('Fajar', 'Rahman', 'fajar.rahman@office.com', 'Rw6%Ha9!Xp2q');
CALL add_admin('Maya', 'Dewi', 'maya.dewi@office.com', 'Dz5$Kq3!Lp7j');
CALL add_admin('Yusuf', 'Hakim', 'yusuf.hakim@office.com', 'Qs7@Ln2#Fp9v');
CALL add_admin('Rina', 'Sari', 'rina.sari@office.com', 'Mn3^Jx8!Uw5t');
CALL add_admin('Hadi', 'Putra', 'hadi.putra@office.com', 'Bc1#To7!Qs6z');
CALL add_admin('Dian', 'Safitri', 'dian.safitri@office.com', 'Gr4!Xy8@Nz5q');
CALL add_admin('Arianto', 'Jaya', 'arianto.jaya@office.com', 'Vz9$Ja2!Kp3m');
CALL add_admin('Yuniarti', 'Kusuma', 'yuniarti.kusuma@office.com', 'Ld6^Qx3!Za8t');


-- -------------------------------------------------------------------------------------------------------------------------

-- insert into reservation

-- schedule 1
CALL add_reservation(1, 'B1');
CALL add_reservation(1, 'B2');
CALL add_reservation(1, 'B3');
CALL add_reservation(1, 'E1');
CALL add_reservation(1, 'E2');
CALL add_reservation(1, 'E3');
CALL add_reservation(1, 'E4');
CALL add_reservation(1, 'E5');
CALL add_reservation(1, 'E6');
CALL add_reservation(1, 'E7');
CALL add_reservation(1, 'P1');
CALL add_reservation(1, 'P2');
CALL add_reservation(1, 'P3');
CALL add_reservation(1, 'P4');
CALL add_reservation(1, 'P5');
CALL add_reservation(1, 'P6');
CALL add_reservation(1, 'P7');
CALL add_reservation(1, 'B12');
CALL add_reservation(1, 'B13');
CALL add_reservation(1, 'B14');

-- schedule 2
CALL add_reservation(2, 'B1');
CALL add_reservation(2, 'B2');
CALL add_reservation(2, 'B3');
CALL add_reservation(2, 'E1');
CALL add_reservation(2, 'E2');
CALL add_reservation(2, 'E3');
CALL add_reservation(2, 'E4');
CALL add_reservation(2, 'E5');
CALL add_reservation(2, 'E6');
CALL add_reservation(2, 'E7');
CALL add_reservation(2, 'P1');
CALL add_reservation(2, 'P2');
CALL add_reservation(2, 'P3');
CALL add_reservation(2, 'P4');
CALL add_reservation(2, 'P5');
CALL add_reservation(2, 'P6');
CALL add_reservation(2, 'P7');
CALL add_reservation(2, 'B12');
CALL add_reservation(2, 'B13');
CALL add_reservation(2, 'B14');

-- schedule 3
CALL add_reservation(3, 'B1');
CALL add_reservation(3, 'B2');
CALL add_reservation(3, 'B3');
CALL add_reservation(3, 'E1');
CALL add_reservation(3, 'E2');
CALL add_reservation(3, 'E3');
CALL add_reservation(3, 'E4');
CALL add_reservation(3, 'E5');
CALL add_reservation(3, 'E6');
CALL add_reservation(3, 'E7');
CALL add_reservation(3, 'P1');
CALL add_reservation(3, 'P2');
CALL add_reservation(3, 'P3');
CALL add_reservation(3, 'P4');
CALL add_reservation(3, 'P5');
CALL add_reservation(3, 'P6');
CALL add_reservation(3, 'P7');
CALL add_reservation(3, 'B12');
CALL add_reservation(3, 'B13');
CALL add_reservation(3, 'B14');

-- schedule 4
CALL add_reservation(4, 'B1');
CALL add_reservation(4, 'B2');
CALL add_reservation(4, 'B3');
CALL add_reservation(4, 'E1');
CALL add_reservation(4, 'E2');
CALL add_reservation(4, 'E3');
CALL add_reservation(4, 'E4');
CALL add_reservation(4, 'E5');
CALL add_reservation(4, 'E6');
CALL add_reservation(4, 'E7');
CALL add_reservation(4, 'P1');
CALL add_reservation(4, 'P2');
CALL add_reservation(4, 'P3');
CALL add_reservation(4, 'P4');
CALL add_reservation(4, 'P5');
CALL add_reservation(4, 'P6');
CALL add_reservation(4, 'P7');
CALL add_reservation(4, 'B12');
CALL add_reservation(4, 'B13');
CALL add_reservation(4, 'B14');

-- schedule 5
CALL add_reservation(5, 'B1');
CALL add_reservation(5, 'B2');
CALL add_reservation(5, 'B3');
CALL add_reservation(5, 'E1');
CALL add_reservation(5, 'E2');
CALL add_reservation(5, 'E3');
CALL add_reservation(5, 'E4');
CALL add_reservation(5, 'E5');
CALL add_reservation(5, 'E6');
CALL add_reservation(5, 'E7');
CALL add_reservation(5, 'P1');
CALL add_reservation(5, 'P2');
CALL add_reservation(5, 'P3');
CALL add_reservation(5, 'P4');
CALL add_reservation(5, 'P5');
CALL add_reservation(5, 'P6');
CALL add_reservation(5, 'P7');
CALL add_reservation(5, 'B12');
CALL add_reservation(5, 'B13');
CALL add_reservation(5, 'B14');

-- schedule 6
CALL add_reservation(6, 'B1');
CALL add_reservation(6, 'B2');
CALL add_reservation(6, 'B3');
CALL add_reservation(6, 'E1');
CALL add_reservation(6, 'E2');
CALL add_reservation(6, 'E3');
CALL add_reservation(6, 'E4');
CALL add_reservation(6, 'E5');
CALL add_reservation(6, 'E6');
CALL add_reservation(6, 'E7');
CALL add_reservation(6, 'P1');
CALL add_reservation(6, 'P2');
CALL add_reservation(6, 'P3');
CALL add_reservation(6, 'P4');
CALL add_reservation(6, 'P5');
CALL add_reservation(6, 'P6');
CALL add_reservation(6, 'P7');
CALL add_reservation(6, 'B12');
CALL add_reservation(6, 'B13');
CALL add_reservation(6, 'B14');

-- schedule 7
CALL add_reservation(7, 'B1');
CALL add_reservation(7, 'B2');
CALL add_reservation(7, 'B3');
CALL add_reservation(7, 'E1');
CALL add_reservation(7, 'E2');
CALL add_reservation(7, 'E3');
CALL add_reservation(7, 'E4');
CALL add_reservation(7, 'E5');
CALL add_reservation(7, 'E6');
CALL add_reservation(7, 'E7');
CALL add_reservation(7, 'P1');
CALL add_reservation(7, 'P2');
CALL add_reservation(7, 'P3');
CALL add_reservation(7, 'P4');
CALL add_reservation(7, 'P5');
CALL add_reservation(7, 'P6');
CALL add_reservation(7, 'P7');
CALL add_reservation(7, 'B12');
CALL add_reservation(7, 'B13');
CALL add_reservation(7, 'B14');

-- schedule 8
CALL add_reservation(8, 'B1');
CALL add_reservation(8, 'B2');
CALL add_reservation(8, 'B3');
CALL add_reservation(8, 'E1');
CALL add_reservation(8, 'E2');
CALL add_reservation(8, 'E3');
CALL add_reservation(8, 'E4');
CALL add_reservation(8, 'E5');
CALL add_reservation(8, 'E6');
CALL add_reservation(8, 'E7');
CALL add_reservation(8, 'P1');
CALL add_reservation(8, 'P2');
CALL add_reservation(8, 'P3');
CALL add_reservation(8, 'P4');
CALL add_reservation(8, 'P5');
CALL add_reservation(8, 'P6');
CALL add_reservation(8, 'P7');
CALL add_reservation(8, 'B12');
CALL add_reservation(8, 'B13');
CALL add_reservation(8, 'B14');

-- schedule 9
CALL add_reservation(9, 'B1');
CALL add_reservation(9, 'B2');
CALL add_reservation(9, 'B3');
CALL add_reservation(9, 'E1');
CALL add_reservation(9, 'E2');
CALL add_reservation(9, 'E3');
CALL add_reservation(9, 'E4');
CALL add_reservation(9, 'E5');
CALL add_reservation(9, 'E6');
CALL add_reservation(9, 'E7');
CALL add_reservation(9, 'P1');
CALL add_reservation(9, 'P2');
CALL add_reservation(9, 'P3');
CALL add_reservation(9, 'P4');
CALL add_reservation(9, 'P5');
CALL add_reservation(9, 'P6');
CALL add_reservation(9, 'P7');
CALL add_reservation(9, 'B12');
CALL add_reservation(9, 'B13');
CALL add_reservation(9, 'B14');

-- schedule 10
CALL add_reservation(10, 'B1');
CALL add_reservation(10, 'B2');
CALL add_reservation(10, 'B3');
CALL add_reservation(10, 'E1');
CALL add_reservation(10, 'E2');
CALL add_reservation(10, 'E3');
CALL add_reservation(10, 'E4');
CALL add_reservation(10, 'E5');
CALL add_reservation(10, 'E6');
CALL add_reservation(10, 'E7');
CALL add_reservation(10, 'P1');
CALL add_reservation(10, 'P2');
CALL add_reservation(10, 'P3');
CALL add_reservation(10, 'P4');
CALL add_reservation(10, 'P5');
CALL add_reservation(10, 'P6');
CALL add_reservation(10, 'P7');
CALL add_reservation(10, 'B12');
CALL add_reservation(10, 'B13');
CALL add_reservation(10, 'B14');

-- schedule 11
CALL add_reservation(11, 'B1');
CALL add_reservation(11, 'B2');
CALL add_reservation(11, 'B3');
CALL add_reservation(11, 'E1');
CALL add_reservation(11, 'E2');
CALL add_reservation(11, 'E3');
CALL add_reservation(11, 'E4');
CALL add_reservation(11, 'E5');
CALL add_reservation(11, 'E6');
CALL add_reservation(11, 'E7');
CALL add_reservation(11, 'P1');
CALL add_reservation(11, 'P2');
CALL add_reservation(11, 'P3');
CALL add_reservation(11, 'P4');
CALL add_reservation(11, 'P5');
CALL add_reservation(11, 'P6');
CALL add_reservation(11, 'P7');
CALL add_reservation(11, 'B12');
CALL add_reservation(11, 'B13');
CALL add_reservation(11, 'B14');

-- schedule 12
CALL add_reservation(12, 'B1');
CALL add_reservation(12, 'B2');
CALL add_reservation(12, 'B3');
CALL add_reservation(12, 'E1');
CALL add_reservation(12, 'E2');
CALL add_reservation(12, 'E3');
CALL add_reservation(12, 'E4');
CALL add_reservation(12, 'E5');
CALL add_reservation(12, 'E6');
CALL add_reservation(12, 'E7');
CALL add_reservation(12, 'P1');
CALL add_reservation(12, 'P2');
CALL add_reservation(12, 'P3');
CALL add_reservation(12, 'P4');
CALL add_reservation(12, 'P5');
CALL add_reservation(12, 'P6');
CALL add_reservation(12, 'P7');
CALL add_reservation(12, 'B12');
CALL add_reservation(12, 'B13');
CALL add_reservation(12, 'B14');

-- schedule 13
CALL add_reservation(13, 'B1');
CALL add_reservation(13, 'B2');
CALL add_reservation(13, 'B3');
CALL add_reservation(13, 'E1');
CALL add_reservation(13, 'E2');
CALL add_reservation(13, 'E3');
CALL add_reservation(13, 'E4');
CALL add_reservation(13, 'E5');
CALL add_reservation(13, 'E6');
CALL add_reservation(13, 'E7');
CALL add_reservation(13, 'P1');
CALL add_reservation(13, 'P2');
CALL add_reservation(13, 'P3');
CALL add_reservation(13, 'P4');
CALL add_reservation(13, 'P5');
CALL add_reservation(13, 'P6');
CALL add_reservation(13, 'P7');
CALL add_reservation(13, 'B12');
CALL add_reservation(13, 'B13');
CALL add_reservation(13, 'B14');

-- schedule 14
CALL add_reservation(14, 'E1');  -- Economy
CALL add_reservation(14, 'E2');  -- Economy
CALL add_reservation(14, 'B1');  -- Business
CALL add_reservation(14, 'B2');  -- Business
CALL add_reservation(14, 'E3');  -- Economy
CALL add_reservation(14, 'E4');  -- Economy
CALL add_reservation(14, 'E5');  -- Economy
CALL add_reservation(14, 'E6');  -- Economy
CALL add_reservation(14, 'P1');  -- Platinum
CALL add_reservation(14, 'E21');   -- Economy
CALL add_reservation(14, 'E8');   -- Economy
CALL add_reservation(14, 'E9');    -- Economy
CALL add_reservation(14, 'E10'); -- Economy
CALL add_reservation(14, 'E31');   -- Economy
CALL add_reservation(14, 'E32'); -- Economy
CALL add_reservation(14, 'E33');    -- Economy
CALL add_reservation(14, 'E14');    -- Economy
CALL add_reservation(14, 'E15');   -- Economy
CALL add_reservation(14, 'E41');    -- Economy
CALL add_reservation(14, 'E42');   -- Economy

-- schedule 15
CALL add_reservation(15, 'P1');  -- Platinum
CALL add_reservation(15, 'B1');  -- Business
CALL add_reservation(15, 'B2');  -- Business
CALL add_reservation(15, 'B3');  -- Business
CALL add_reservation(15, 'E1');  -- Economy
CALL add_reservation(15, 'E2');  -- Economy
CALL add_reservation(15, 'E3');  -- Economy
CALL add_reservation(15, 'E4');  -- Economy
CALL add_reservation(15, 'E5');  -- Economy
CALL add_reservation(15, 'E20'); -- Economy 
CALL add_reservation(15, 'B4');  -- Business
CALL add_reservation(15, 'P3');  -- Platinum
CALL add_reservation(15, 'E6');   -- Economy
CALL add_reservation(15, 'E7');   -- Economy
CALL add_reservation(15, 'E8');   -- Economy
CALL add_reservation(15, 'E9');   -- Economy
CALL add_reservation(15, 'E10');  -- Economy
CALL add_reservation(15, 'E11');  -- Economy
CALL add_reservation(15, 'E21');  -- Economy
CALL add_reservation(15, 'E22');  -- Economy

-- schedule 16
CALL add_reservation(16, 'P1');
CALL add_reservation(16, 'P2');
CALL add_reservation(16, 'P3');
CALL add_reservation(16, 'E4');
CALL add_reservation(16, 'E5');
CALL add_reservation(16, 'E6');
CALL add_reservation(16, 'P7');
CALL add_reservation(16, 'B12');
CALL add_reservation(16, 'B13');
CALL add_reservation(16, 'B14');
CALL add_reservation(16, 'E1');
CALL add_reservation(16, 'E2');
CALL add_reservation(16, 'B1');
CALL add_reservation(16, 'E3');
CALL add_reservation(16, 'B2');
CALL add_reservation(16, 'E14');
CALL add_reservation(16, 'E15');
CALL add_reservation(16, 'E16');
CALL add_reservation(16, 'E7');
CALL add_reservation(16, 'E8');

-- schedule 17
CALL add_reservation(17, 'E1');
CALL add_reservation(17, 'E2');
CALL add_reservation(17, 'E3');
CALL add_reservation(17, 'E4');
CALL add_reservation(17, 'E5');
CALL add_reservation(17, 'E6');
CALL add_reservation(17, 'E7');
CALL add_reservation(17, 'B12');
CALL add_reservation(17, 'B13');
CALL add_reservation(17, 'B14');
CALL add_reservation(17, 'E11');
CALL add_reservation(17, 'E12');
CALL add_reservation(17, 'B1');
CALL add_reservation(17, 'E13');
CALL add_reservation(17, 'E14');
CALL add_reservation(17, 'E15');
CALL add_reservation(17, 'E16');
CALL add_reservation(17, 'E17');
CALL add_reservation(17, 'E18');
CALL add_reservation(17, 'E19');
CALL add_reservation(17, 'E20');

-- schedule 18
CALL add_reservation(18, 'P1');
CALL add_reservation(18, 'P2');
CALL add_reservation(18, 'P3');
CALL add_reservation(18, 'P4');
CALL add_reservation(18, 'P5');
CALL add_reservation(18, 'P6');
CALL add_reservation(18, 'P7');
CALL add_reservation(18, 'B12');
CALL add_reservation(18, 'E13');
CALL add_reservation(18, 'E14');
CALL add_reservation(18, 'B1');
CALL add_reservation(18, 'B2');
CALL add_reservation(18, 'B3');
CALL add_reservation(18, 'B4');
CALL add_reservation(18, 'B5');
CALL add_reservation(18, 'E11');
CALL add_reservation(18, 'E12');
CALL add_reservation(18, 'E23');
CALL add_reservation(18, 'E24');
CALL add_reservation(18, 'E15');

-- schedule 19
CALL add_reservation(19, 'E1');
CALL add_reservation(19, 'E2');
CALL add_reservation(19, 'P3');
CALL add_reservation(19, 'P4');
CALL add_reservation(19, 'P5');
CALL add_reservation(19, 'P6');
CALL add_reservation(19, 'B1');
CALL add_reservation(19, 'B2');
CALL add_reservation(19, 'B3');
CALL add_reservation(19, 'B4');
CALL add_reservation(19, 'B5');
CALL add_reservation(19, 'B6');
CALL add_reservation(19, 'B7');
CALL add_reservation(19, 'B8');
CALL add_reservation(19, 'B9');
CALL add_reservation(19, 'E16');
CALL add_reservation(19, 'E17');
CALL add_reservation(19, 'E18');
CALL add_reservation(19, 'E19');
CALL add_reservation(19, 'E20');

-- schedule 20
CALL add_reservation(20, 'P1');
CALL add_reservation(20, 'P2');
CALL add_reservation(20, 'P3');
CALL add_reservation(20, 'P4');
CALL add_reservation(20, 'P5');
CALL add_reservation(20, 'P6');
CALL add_reservation(20, 'P7');
CALL add_reservation(20, 'E12');
CALL add_reservation(20, 'E13');
CALL add_reservation(20, 'E14');
CALL add_reservation(20, 'E3');
CALL add_reservation(20, 'E15');
CALL add_reservation(20, 'E24');
CALL add_reservation(20, 'E5');
CALL add_reservation(20, 'E8');
CALL add_reservation(20, 'E10');
CALL add_reservation(20, 'E11');
CALL add_reservation(20, 'E19');
CALL add_reservation(20, 'E20');
CALL add_reservation(20, 'E21');

-- schedule 21
CALL add_reservation(21, 'E1');
CALL add_reservation(21, 'E2');
CALL add_reservation(21, 'E3');
CALL add_reservation(21, 'E4');
CALL add_reservation(21, 'E5');
CALL add_reservation(21, 'B1');
CALL add_reservation(21, 'B2');
CALL add_reservation(21, 'B12');
CALL add_reservation(21, 'B13');
CALL add_reservation(21, 'B14');
CALL add_reservation(21, 'B3');
CALL add_reservation(21, 'B4');
CALL add_reservation(21, 'E6');
CALL add_reservation(21, 'E7');
CALL add_reservation(21, 'E8');
CALL add_reservation(21, 'E9');
CALL add_reservation(21, 'E10');
CALL add_reservation(21, 'E11');
CALL add_reservation(21, 'E12');
CALL add_reservation(21, 'E13');

-- schedule 22
CALL add_reservation(22, 'E1');
CALL add_reservation(22, 'P2');
CALL add_reservation(22, 'E3');
CALL add_reservation(22, 'P4');
CALL add_reservation(22, 'P5');
CALL add_reservation(22, 'P6');
CALL add_reservation(22, 'P7');
CALL add_reservation(22, 'E12');
CALL add_reservation(22, 'B13');
CALL add_reservation(22, 'B14');
CALL add_reservation(22, 'E2');
CALL add_reservation(22, 'E13');
CALL add_reservation(22, 'E4');
CALL add_reservation(22, 'E25');
CALL add_reservation(22, 'E26');
CALL add_reservation(22, 'E27');
CALL add_reservation(22, 'E28');
CALL add_reservation(22, 'E9');
CALL add_reservation(22, 'E10');
CALL add_reservation(22, 'E11');

-- schedule 23
CALL add_reservation(23, 'P1');
CALL add_reservation(23, 'E12');
CALL add_reservation(23, 'E13');
CALL add_reservation(23, 'E4');
CALL add_reservation(23, 'E5');
CALL add_reservation(23, 'E6');
CALL add_reservation(23, 'P7');
CALL add_reservation(23, 'B12');
CALL add_reservation(23, 'B13');
CALL add_reservation(23, 'B14');
CALL add_reservation(23, 'E1');
CALL add_reservation(23, 'E3');
CALL add_reservation(23, 'E7');
CALL add_reservation(23, 'E8');
CALL add_reservation(23, 'E9');
CALL add_reservation(23, 'E10');
CALL add_reservation(23, 'E15');
CALL add_reservation(23, 'E16');
CALL add_reservation(23, 'E20');
CALL add_reservation(23, 'E22');

-- schedule 24
CALL add_reservation(24, 'P1');
CALL add_reservation(24, 'P2');
CALL add_reservation(24, 'P3');
CALL add_reservation(24, 'P4');
CALL add_reservation(24, 'P5');
CALL add_reservation(24, 'P6');
CALL add_reservation(24, 'P7');
CALL add_reservation(24, 'E2');
CALL add_reservation(24, 'E23');
CALL add_reservation(24, 'E24');
CALL add_reservation(24, 'B1');
CALL add_reservation(24, 'B2');
CALL add_reservation(24, 'E5');
CALL add_reservation(24, 'E6');
CALL add_reservation(24, 'E9');
CALL add_reservation(24, 'E11');
CALL add_reservation(24, 'E15');
CALL add_reservation(24, 'E17');
CALL add_reservation(24, 'E19');
CALL add_reservation(24, 'E21');

-- schedule 25
CALL add_reservation(25, 'E21');
CALL add_reservation(25, 'E22');
CALL add_reservation(25, 'E3');
CALL add_reservation(25, 'E4');
CALL add_reservation(25, 'E5');
CALL add_reservation(25, 'E6');
CALL add_reservation(25, 'E7');
CALL add_reservation(25, 'B12');
CALL add_reservation(25, 'B13');
CALL add_reservation(25, 'B14');
CALL add_reservation(25, 'B1');
CALL add_reservation(25, 'B2');
CALL add_reservation(25, 'P1');
CALL add_reservation(25, 'P2');
CALL add_reservation(25, 'E8');
CALL add_reservation(25, 'E10');
CALL add_reservation(25, 'E12');
CALL add_reservation(25, 'E14');
CALL add_reservation(25, 'E16');
CALL add_reservation(25, 'E18');

-- schedule 26
CALL add_reservation(26, 'P1');
CALL add_reservation(26, 'E2');
CALL add_reservation(26, 'E3');
CALL add_reservation(26, 'E4');
CALL add_reservation(26, 'P5');
CALL add_reservation(26, 'P6');
CALL add_reservation(26, 'P7');
CALL add_reservation(26, 'B12');
CALL add_reservation(26, 'B3');
CALL add_reservation(26, 'B4');
CALL add_reservation(26, 'B1');
CALL add_reservation(26, 'B2');
CALL add_reservation(26, 'E5');
CALL add_reservation(26, 'E8');
CALL add_reservation(26, 'E10');
CALL add_reservation(26, 'E12');
CALL add_reservation(26, 'E14');
CALL add_reservation(26, 'E16');
CALL add_reservation(26, 'E18');
CALL add_reservation(26, 'E20');

-- schedule 27
CALL add_reservation(27, 'P1');
CALL add_reservation(27, 'P2');
CALL add_reservation(27, 'P3');
CALL add_reservation(27, 'P4');
CALL add_reservation(27, 'P5');
CALL add_reservation(27, 'P6');
CALL add_reservation(27, 'P7');
CALL add_reservation(27, 'B12');
CALL add_reservation(27, 'B13');
CALL add_reservation(27, 'B14');

-- schedule 28

CALL add_reservation(28, 'P1');
CALL add_reservation(28, 'P2');
CALL add_reservation(28, 'P3');
CALL add_reservation(28, 'P4');
CALL add_reservation(28, 'P5');
CALL add_reservation(28, 'P6');
CALL add_reservation(28, 'P7');
CALL add_reservation(28, 'B12');
CALL add_reservation(28, 'B13');
CALL add_reservation(28, 'B14');

CALL add_reservation(28, 'B1');
CALL add_reservation(28, 'B2');
CALL add_reservation(28, 'B3');
CALL add_reservation(28, 'E1');
CALL add_reservation(28, 'E2');
CALL add_reservation(28, 'E3');
CALL add_reservation(28, 'E4');
CALL add_reservation(28, 'E5');
CALL add_reservation(28, 'E6');
CALL add_reservation(28, 'E7');


-- schedule 29

CALL add_reservation(29, 'P1');
CALL add_reservation(29, 'P2');
CALL add_reservation(29, 'P3');
CALL add_reservation(29, 'P4');
CALL add_reservation(29, 'P5');
CALL add_reservation(29, 'P6');
CALL add_reservation(29, 'P7');
CALL add_reservation(29, 'B12');
CALL add_reservation(29, 'B13');
CALL add_reservation(29, 'B14');

CALL add_reservation(29, 'B1');
CALL add_reservation(29, 'B2');
CALL add_reservation(29, 'B3');
CALL add_reservation(29, 'E1');
CALL add_reservation(29, 'E2');
CALL add_reservation(29, 'E3');
CALL add_reservation(29, 'E4');
CALL add_reservation(29, 'E5');
CALL add_reservation(29, 'E6');
CALL add_reservation(29, 'E7');

-- schedule 30

CALL add_reservation(30, 'B1');
CALL add_reservation(30, 'B2');
CALL add_reservation(30, 'B3');
CALL add_reservation(30, 'E1');
CALL add_reservation(30, 'E2');
CALL add_reservation(30, 'E3');
CALL add_reservation(30, 'E4');
CALL add_reservation(30, 'E5');
CALL add_reservation(30, 'E6');
CALL add_reservation(30, 'E7');
CALL add_reservation(30, 'P1');
CALL add_reservation(30, 'P2');
CALL add_reservation(30, 'P3');
CALL add_reservation(30, 'P4');
CALL add_reservation(30, 'P5');
CALL add_reservation(30, 'P6');
CALL add_reservation(30, 'P7');
CALL add_reservation(30, 'B12');
CALL add_reservation(30, 'B13');
CALL add_reservation(30, 'B14');


-- schedule 31

CALL add_reservation(31, 'B1');
CALL add_reservation(31, 'B2');
CALL add_reservation(31, 'B3');
CALL add_reservation(31, 'E1');
CALL add_reservation(31, 'E2');
CALL add_reservation(31, 'E3');
CALL add_reservation(31, 'E4');
CALL add_reservation(31, 'E5');
CALL add_reservation(31, 'E6');
CALL add_reservation(31, 'E7');
CALL add_reservation(31, 'P1');
CALL add_reservation(31, 'P2');
CALL add_reservation(31, 'P3');
CALL add_reservation(31, 'P4');
CALL add_reservation(31, 'P5');
CALL add_reservation(31, 'P6');
CALL add_reservation(31, 'P7');
CALL add_reservation(31, 'B12');
CALL add_reservation(31, 'B13');
CALL add_reservation(31, 'B14');

-- schedule 32

CALL add_reservation(32, 'B1');
CALL add_reservation(32, 'B2');
CALL add_reservation(32, 'B3');
CALL add_reservation(32, 'E1');
CALL add_reservation(32, 'E2');
CALL add_reservation(32, 'E3');
CALL add_reservation(32, 'E4');
CALL add_reservation(32, 'E5');
CALL add_reservation(32, 'E6');
CALL add_reservation(32, 'E7');
CALL add_reservation(32, 'P1');
CALL add_reservation(32, 'P2');
CALL add_reservation(32, 'P3');
CALL add_reservation(32, 'P4');
CALL add_reservation(32, 'P5');
CALL add_reservation(32, 'P6');
CALL add_reservation(32, 'P7');
CALL add_reservation(32, 'B12');
CALL add_reservation(32, 'B13');
CALL add_reservation(32, 'B14');


-- --------------------------------------------------------------------------------------------------------------------------

-- insert into booking 

-- schedule 01

CALL add_registered_booking('christopherthomas@example.com', 1, 'P1');
CALL add_registered_booking('benjaminhall@example.com', 1, 'P2');
CALL add_registered_booking('sebastianking@example.com', 1, 'P3');
CALL add_registered_booking('natalieking@example.com', 1, 'P4');
CALL add_registered_booking('nathanallen@example.com', 1, 'P5');
CALL add_registered_booking('ariayoung@example.com', 1, 'P6');
CALL add_registered_booking('evelynperez@example.com', 1, 'P7');
CALL add_registered_booking('lunarobinson@example.com', 1, 'B12');
CALL add_registered_booking('lukewalker@example.com', 1, 'B13');
CALL add_registered_booking('ameliascott@example.com', 1, 'B14');
CALL add_guest_booking('Suneth Perera', 'Female', '1982-04-22', 'BU3945209', '0771475306', 1, 'E1');
CALL add_guest_booking('Chathura Silva', 'Male', '2015-02-07', 'BU4061853', '0779021790', 1, 'E2');
CALL add_guest_booking('Amali Jayasinghe', 'Male', '2012-11-29', 'BU8774943', '0772652269', 1, 'E3');
CALL add_guest_booking('Ruwan Dissanayake', 'Female', '1999-03-06', 'BU9474997', '0772092499', 1, 'E4');
CALL add_guest_booking('Dulika Perera', 'Male', '2004-12-28', 'BU4360727', '0776592068', 1, 'B1');
CALL add_guest_booking('Bimal Karunaratne', 'Female', '1997-08-01', 'BU2994417', '0779074566', 1, 'B2');
CALL add_guest_booking('Kasuni Fernando', 'Male', '2007-03-21', 'BU1776612', '0773060655', 1, 'B3');
CALL add_guest_booking('Ajantha Perera', 'Male', '2010-07-27', 'BU9342601', '0773624916', 1, 'E5');
CALL add_guest_booking('Nuwan Wijesinghe', 'Male', '2007-09-06', 'BU9004403', '0774727801', 1, 'E6');
CALL add_guest_booking('Gayani Fernando', 'Female', '2019-06-16', 'BU6190579', '0779489681', 1, 'E7');

-- schedule 02

CALL add_registered_booking('lucasrodriguez@example.com', 2, 'P1');
CALL add_registered_booking('islarobinson@example.com', 2, 'P2');
CALL add_registered_booking('davidmartinez@example.com', 2, 'P3');
CALL add_registered_booking('elijahharris@example.com', 2, 'P4');
CALL add_registered_booking('jacksonwright@example.com', 2, 'P5');
CALL add_registered_booking('calebscott@example.com', 2, 'P6');
CALL add_registered_booking('ariayoung@example.com', 2, 'P7');
CALL add_registered_booking('ariayoung@example.com', 2, 'B12');
CALL add_registered_booking('jameslee@example.com', 2, 'B13');
CALL add_registered_booking('jameslee@example.com', 2, 'B14');
CALL add_guest_booking('Mihiri Liyanage', 'Male', '2015-08-25', 'BU3572469', '0772922857', 2, 'E1');
CALL add_guest_booking('Isuri De Zoysa', 'Male', '2011-04-27', 'BU3329634', '0777854142', 2, 'E2');
CALL add_guest_booking('Supuni Wijesinghe', 'Female', '1983-11-07', 'BU3670238', '0771685286', 2, 'E3');
CALL add_guest_booking('Mihira Peiris', 'Female', '1994-07-15', 'BU6658224', '0772406188', 2, 'E4');
CALL add_guest_booking('Ruwan Pathirana', 'Male', '2011-02-13', 'BU1891401', '0778603669', 2, 'E5');
CALL add_guest_booking('Samantha Hewage', 'Female', '1995-02-05', 'BU2129487', '0778328111', 2, 'E6');
CALL add_guest_booking('Geethika Samarasinghe', 'Female', '2009-04-19', 'BU5064983', '0775987522', 2, 'E7');
CALL add_guest_booking('Eranga Pathirana', 'Male', '1988-09-09', 'BU9216552', '0777446662', 2, 'B1');
CALL add_guest_booking('Sameera Rajapakse', 'Female', '1990-11-15', 'BU2567001', '0771262672', 2, 'B2');
CALL add_guest_booking('Thilanka Jayasuriya', 'Male', '2018-08-07', 'BU2115850', '0775078018', 2, 'B3');


-- schedule 03

CALL add_registered_booking('gabrielwalker@example.com', 3, 'P1');
CALL add_registered_booking('gabrielking@example.com', 3, 'P2');
CALL add_registered_booking('gabrielwalker@example.com', 3, 'P3');
CALL add_registered_booking('lucasthompson@example.com', 3, 'P4');
CALL add_registered_booking('sebastianking@example.com', 3, 'P5');
CALL add_registered_booking('scarlettmitchell@example.com', 3, 'P6');
CALL add_registered_booking('lukewalker@example.com', 3, 'P7');
CALL add_registered_booking('davidmartinez@example.com', 3, 'B12');
CALL add_registered_booking('averyadams@example.com', 3, 'B13');
CALL add_registered_booking('christopherthomas@example.com', 3, 'B14');
CALL add_guest_booking('Rasika Kumara', 'Male', '1995-06-24', 'BU3698994', '0778875875', 3, 'E1');
CALL add_guest_booking('Lasith Perera', 'Female', '1997-05-25', 'BU8064504', '0775231240', 3, 'E2');
CALL add_guest_booking('Charitha Wijekoon', 'Male', '2011-06-02', 'BU2242671', '0776281626', 3, 'E3');
CALL add_guest_booking('Sithara Fernando', 'Female', '1983-06-22', 'BU7293608', '0779604748', 3, 'E4');
CALL add_guest_booking('Hasini Hettiarachchi', 'Female', '1983-06-20', 'BU5750336', '0778517022', 3, 'E5');
CALL add_guest_booking('Nuwan Wijesinghe', 'Male', '2006-09-01', 'BU1120312', '0771371073', 3, 'E6');
CALL add_guest_booking('Shenal Goonetileke', 'Female', '2018-01-16', 'BU6789102', '0775771121', 3, 'E7');
CALL add_guest_booking('Dinuka Jayathilaka', 'Male', '2016-07-07', 'BU4132153', '0776654933', 3, 'B1');
CALL add_guest_booking('Kasun Silva', 'Male', '1994-12-19', 'BU8708808', '0772336497', 3, 'B2');
CALL add_guest_booking('Mihira Peiris', 'Female', '1992-05-30', 'BU6552527', '0779007733', 3, 'B3');

-- schedule 04

CALL add_registered_booking('jacksonwright@example.com', 4, 'P1');
CALL add_registered_booking('henrycarter@example.com', 4, 'P2');
CALL add_registered_booking('madisonscott@example.com', 4, 'P3');
CALL add_registered_booking('ellathompson@example.com', 4, 'P4');
CALL add_registered_booking('jacobmartinez@example.com', 4, 'P5');
CALL add_registered_booking('calebscott@example.com', 4, 'P6');
CALL add_registered_booking('williamthomas@example.com', 4, 'P7');
CALL add_registered_booking('julianturner@example.com', 4, 'B12');
CALL add_registered_booking('jameslee@example.com', 4, 'B13');
CALL add_registered_booking('davidmartinez@example.com', 4, 'B14');
CALL add_guest_booking('Upeksha Ranasinghe', 'Male', '1998-07-22', 'BU5102993', '0776598439', 4, 'E1');
CALL add_guest_booking('Sajith Karunarathna', 'Female', '2009-03-17', 'BU1593761', '0774709134', 4, 'E2');
CALL add_guest_booking('Amaya Peiris', 'Female', '1985-08-20', 'BU9388677', '0773782761', 4, 'E3');
CALL add_guest_booking('Piyumi Dissanayake', 'Male', '1991-03-21', 'BU2221029', '0775681508', 4, 'E4');
CALL add_guest_booking('Sampath Ekanayake', 'Female', '1991-11-04', 'BU2894065', '0778536431', 4, 'E5');
CALL add_guest_booking('Suneth Perera', 'Male', '2012-01-28', 'BU3070045', '0777325116', 4, 'E6');
CALL add_guest_booking('Dulika Perera', 'Female', '2018-01-26', 'BU5048175', '0771234074', 4, 'E7');
CALL add_guest_booking('Dileepa Gamage', 'Male', '2003-04-10', 'BU4955770', '0773996924', 4, 'B1');
CALL add_guest_booking('Buddhika De Silva', 'Female', '2013-03-02', 'BU2674515', '0777059750', 4, 'B2');
CALL add_guest_booking('Vindya Kumari', 'Female', '2005-03-23', 'BU3240996', '0778021789', 4, 'B3');


-- schedule 05

CALL add_registered_booking('carterperez@example.com', 5, 'P1');
CALL add_registered_booking('owenyoung@example.com', 5, 'P2');
CALL add_registered_booking('davidmartinez@example.com', 5, 'P3');
CALL add_registered_booking('owenyoung@example.com', 5, 'P4');
CALL add_registered_booking('elijahharris@example.com', 5, 'P5');
CALL add_registered_booking('jacksonwright@example.com', 5, 'P6');
CALL add_registered_booking('ariayoung@example.com', 5, 'P7');
CALL add_registered_booking('ariayoung@example.com', 5, 'B12');
CALL add_registered_booking('owenyoung@example.com', 5, 'B13');
CALL add_registered_booking('wyattgarcia@example.com', 5, 'B14');
CALL add_guest_booking('Isuru Jayawardena', 'Female', '1981-02-01', 'BU1005421', '0778271344', 5, 'E1');
CALL add_guest_booking('Samantha Hewage', 'Male', '2019-08-31', 'BU1693880', '0777655826', 5, 'E2');
CALL add_guest_booking('Suraj Karunathilake', 'Female', '1996-08-02', 'BU8484701', '0779461752', 5, 'E3');
CALL add_guest_booking('Lakshi Fernando', 'Male', '1998-01-15', 'BU1961049', '0776017508', 5, 'E4');
CALL add_guest_booking('Chathura Silva', 'Male', '2011-03-10', 'BU7497521', '0773127540', 5, 'E5');
CALL add_guest_booking('Uditha Wickramasinghe', 'Female', '2008-11-25', 'BU5685283', '0775533461', 5, 'E6');
CALL add_guest_booking('Harsha Wijeratne', 'Male', '1992-09-14', 'BU2888290', '0771797364', 5, 'E7');
CALL add_guest_booking('Amaya Peiris', 'Female', '1992-09-28', 'BU5459439', '0772444938', 5, 'B1');
CALL add_guest_booking('Thilini Rajapakse', 'Male', '2008-04-05', 'BU5233880', '0772481811', 5, 'B2');
CALL add_guest_booking('Rajith Bandara', 'Female', '2008-04-30', 'BU5252208', '0774093898', 5, 'B3');


-- schedule 06

CALL add_registered_booking('lucasrodriguez@example.com', 6, 'P1');
CALL add_registered_booking('michaelharris@example.com', 6, 'P2');
CALL add_registered_booking('lucasthompson@example.com', 6, 'P3');
CALL add_registered_booking('christopherthomas@example.com', 6, 'P4');
CALL add_registered_booking('isaacmartinez@example.com', 6, 'P5');
CALL add_registered_booking('avawright@example.com', 6, 'P6');
CALL add_registered_booking('isabellagreen@example.com', 6, 'P7');
CALL add_registered_booking('samanthaallen@example.com', 6, 'B12');
CALL add_registered_booking('zoeynelson@example.com', 6, 'B13');
CALL add_registered_booking('ariayoung@example.com', 6, 'B14');
CALL add_guest_booking('Madhawa Weerasinghe', 'Female', '1994-01-19', 'BU2311869', '0772108679', 6, 'E1');
CALL add_guest_booking('Randika De Silva', 'Male', '1998-06-01', 'BU4845826', '0779976965', 6, 'E2');
CALL add_guest_booking('Nadeeka Dias', 'Male', '2019-04-12', 'BU2689569', '0774306824', 6, 'E3');
CALL add_guest_booking('Sameera Rajapakse', 'Male', '2008-01-25', 'BU9221539', '0773137254', 6, 'E4');
CALL add_guest_booking('Thilini Rajapakse', 'Male', '2018-11-13', 'BU3592735', '0773026961', 6, 'E5');
CALL add_guest_booking('Malinda Fernando', 'Male', '1994-01-11', 'BU9391260', '0774149455', 6, 'E6');
CALL add_guest_booking('Isuri De Zoysa', 'Female', '2002-05-11', 'BU4430553', '0778951303', 6, 'E7');
CALL add_guest_booking('Hiran Karunaratne', 'Male', '1984-03-06', 'BU2211513', '0774297576', 6, 'B1');
CALL add_guest_booking('Asela Rajapaksha', 'Male', '1985-04-04', 'BU3121857', '0777888054', 6, 'B2');
CALL add_guest_booking('Dulika Perera', 'Female', '1997-07-22', 'BU4082815', '0777904231', 6, 'B3');

-- schedule 07

CALL add_registered_booking('aubreylewis@example.com', 7, 'P1');
CALL add_registered_booking('jackrodriguez@example.com', 7, 'P2');
CALL add_registered_booking('christopherthomas@example.com', 7, 'P3');
CALL add_registered_booking('jacksonwright@example.com', 7, 'P4');
CALL add_registered_booking('graceharris@example.com', 7, 'P5');
CALL add_registered_booking('lilyjackson@example.com', 7, 'P6');
CALL add_registered_booking('lukewalker@example.com', 7, 'P7');
CALL add_registered_booking('lilyjackson@example.com', 7, 'B12');
CALL add_registered_booking('averywright@example.com', 7, 'B13');
CALL add_registered_booking('aubreylewis@example.com', 7, 'B14');
CALL add_guest_booking('Harsha Wijeratne', 'Male', '1999-10-19', 'BU5393142', '0777191875', 7, 'E1');
CALL add_guest_booking('Ruwan Karunaratne', 'Female', '1983-11-22', 'BU7956237', '0779254045', 7, 'E2');
CALL add_guest_booking('Anuradha Samarasinghe', 'Female', '1998-06-01', 'BU5156082', '0775430750', 7, 'E3');
CALL add_guest_booking('Lakshi Fernando', 'Female', '2005-06-21', 'BU8368160', '0771220274', 7, 'E4');
CALL add_guest_booking('Ramesh Jayakody', 'Male', '1995-06-26', 'BU3110607', '0776845414', 7, 'E5');
CALL add_guest_booking('Kavinda Wijekoon', 'Female', '1999-09-04', 'BU4806551', '0772516761', 7, 'E6');
CALL add_guest_booking('Suraj Karunathilake', 'Male', '2016-08-30', 'BU9276919', '0779911862', 7, 'E7');
CALL add_guest_booking('Ruvini Karunaratne', 'Male', '1996-09-06', 'BU9874541', '0778236529', 7, 'B1');
CALL add_guest_booking('Rasika Kumara', 'Male', '1999-08-04', 'BU8419139', '0778904935', 7, 'B2');
CALL add_guest_booking('Geethika Samarasinghe', 'Male', '1998-03-28', 'BU7260249', '0771811489', 7, 'B3');

-- schedule 08

CALL add_registered_booking('christopherthomas@example.com', 8, 'P1');
CALL add_registered_booking('carterperez@example.com', 8, 'P2');
CALL add_registered_booking('gabrielwalker@example.com', 8, 'P3');
CALL add_registered_booking('natalieking@example.com', 8, 'P4');
CALL add_registered_booking('natalieking@example.com', 8, 'P5');
CALL add_registered_booking('ellahill@example.com', 8, 'P6');
CALL add_registered_booking('dylanclark@example.com', 8, 'P7');
CALL add_registered_booking('christopherthomas@example.com', 8, 'B12');
CALL add_registered_booking('natalieking@example.com', 8, 'B13');
CALL add_registered_booking('lillianhall@example.com', 8, 'B14');
CALL add_guest_booking('Imesha Senanayake', 'Female', '1986-04-21', 'BU3266243', '0778514630', 8, 'E1');
CALL add_guest_booking('Sanjaya Amarasinghe', 'Male', '2003-07-09', 'BU3780755', '0771273710', 8, 'E2');
CALL add_guest_booking('Sameera Rajapakse', 'Male', '1994-06-26', 'BU2939506', '0771366526', 8, 'E3');
CALL add_guest_booking('Sajith Karunarathna', 'Male', '2017-09-22', 'BU8727208', '0779434314', 8, 'E4');
CALL add_guest_booking('Shanaka Jayasena', 'Male', '2003-02-11', 'BU4941073', '0777633206', 8, 'E5');
CALL add_guest_booking('Shehan Gamage', 'Female', '1984-10-14', 'BU3536897', '0776410023', 8, 'E6');
CALL add_guest_booking('Buddhika De Silva', 'Male', '2015-07-19', 'BU8507524', '0774889266', 8, 'E7');
CALL add_guest_booking('Nadeeka Dias', 'Male', '1997-11-24', 'BU9749918', '0776549789', 8, 'B1');
CALL add_guest_booking('Dinuka Jayathilaka', 'Female', '1990-02-20', 'BU7809452', '0777351029', 8, 'B2');
CALL add_guest_booking('Piyumi Dissanayake', 'Male', '1982-09-22', 'BU4049137', '0777547618', 8, 'B3');

-- schedule 09

CALL add_registered_booking('zoeynelson@example.com', 9, 'P1');
CALL add_registered_booking('gabrielwalker@example.com', 9, 'P2');
CALL add_registered_booking('laylaanderson@example.com', 9, 'P3');
CALL add_registered_booking('islarobinson@example.com', 9, 'P4');
CALL add_registered_booking('isabellagreen@example.com', 9, 'P5');
CALL add_registered_booking('davidmartinez@example.com', 9, 'P6');
CALL add_registered_booking('ethanwhite@example.com', 9, 'P7');
CALL add_registered_booking('elijahharris@example.com', 9, 'B12');
CALL add_registered_booking('lucasrodriguez@example.com', 9, 'B13');
CALL add_registered_booking('graceharris@example.com', 9, 'B14');
CALL add_guest_booking('Tharushi Jayasekera', 'Female', '1997-01-21', 'BU6745373', '0771873757', 9, 'E1');
CALL add_guest_booking('Shalika Fernando', 'Male', '1984-11-11', 'BU1856157', '0773856066', 9, 'E2');
CALL add_guest_booking('Sampath Ekanayake', 'Female', '2013-07-03', 'BU6926601', '0771345253', 9, 'E3');
CALL add_guest_booking('Tharushi Jayasekera', 'Male', '2003-01-12', 'BU8269439', '0772695405', 9, 'E4');
CALL add_guest_booking('Lakmal Kumara', 'Female', '2018-04-02', 'BU4712052', '0775336672', 9, 'E5');
CALL add_guest_booking('Rashmi Dias', 'Female', '1980-09-05', 'BU5373302', '0776705890', 9, 'E6');
CALL add_guest_booking('Kavinda Wijekoon', 'Male', '1995-03-13', 'BU9898711', '0772897254', 9, 'E7');
CALL add_guest_booking('Udaya Rajapaksha', 'Female', '1995-02-08', 'BU3803333', '0771619388', 9, 'B1');
CALL add_guest_booking('Samantha Hewage', 'Female', '2012-12-05', 'BU2323927', '0775894408', 9, 'B2');
CALL add_guest_booking('Shanaka Jayasena', 'Female', '1989-04-05', 'BU5892414', '0776475115', 9, 'B3');

-- schedule 10

CALL add_registered_booking('zoeynelson@example.com', 10, 'P1');
CALL add_registered_booking('benjaminhall@example.com', 10, 'P2');
CALL add_registered_booking('leolopez@example.com', 10, 'P3');
CALL add_registered_booking('sofiahernandez@example.com', 10, 'P4');
CALL add_registered_booking('nathanallen@example.com', 10, 'P5');
CALL add_registered_booking('sofiahernandez@example.com', 10, 'P6');
CALL add_registered_booking('benjaminhall@example.com', 10, 'P7');
CALL add_registered_booking('dylanclark@example.com', 10, 'B12');
CALL add_registered_booking('jameslee@example.com', 10, 'B13');
CALL add_registered_booking('jackrodriguez@example.com', 10, 'B14');
CALL add_guest_booking('Nadeeka Dias', 'Male', '1988-12-12', 'BU1322099', '0773229008', 10, 'E1');
CALL add_guest_booking('Hiran Perera', 'Male', '1984-01-31', 'BU9187531', '0774293652', 10, 'E2');
CALL add_guest_booking('Roshan Weerasinghe', 'Male', '2000-07-17', 'BU3626821', '0776271573', 10, 'E3');
CALL add_guest_booking('Tharushi Jayasekera', 'Female', '1999-01-30', 'BU3993788', '0778603873', 10, 'E4');
CALL add_guest_booking('Kavinda Wijekoon', 'Female', '2013-02-08', 'BU8944262', '0776581609', 10, 'E5');
CALL add_guest_booking('Lakshitha Madushanka', 'Male', '2018-03-20', 'BU5573501', '0777081175', 10, 'E6');
CALL add_guest_booking('Tharushi Jayasekera', 'Male', '1993-11-27', 'BU4271823', '0773281523', 10, 'E7');
CALL add_guest_booking('Harsha Wijeratne', 'Female', '2005-02-07', 'BU5253606', '0779110633', 10, 'B1');
CALL add_guest_booking('Nadeeka Pathirana', 'Female', '1989-04-10', 'BU2142909', '0779361547', 10, 'B2');
CALL add_guest_booking('Harsha Wijeratne', 'Female', '2003-11-22', 'BU7917731', '0774983072', 10, 'B3');

-- schedule 11

CALL add_registered_booking('ellahill@example.com', 11, 'P1');
CALL add_registered_booking('wyattgarcia@example.com', 11, 'P2');
CALL add_registered_booking('matthewharris@example.com', 11, 'P3');
CALL add_registered_booking('ellathompson@example.com', 11, 'P4');
CALL add_registered_booking('averywright@example.com', 11, 'P5');
CALL add_registered_booking('matthewharris@example.com', 11, 'P6');
CALL add_registered_booking('williamthomas@example.com', 11, 'P7');
CALL add_registered_booking('ariayoung@example.com', 11, 'B12');
CALL add_registered_booking('avawright@example.com', 11, 'B13');
CALL add_registered_booking('lunarobinson@example.com', 11, 'B14');
CALL add_guest_booking('Ruwan Karunaratne', 'Male', '1980-03-16', 'BU3860673', '0779721546', 11, 'E1');
CALL add_guest_booking('Tharaka Ratnayake', 'Male', '1996-09-22', 'BU4609513', '0772060770', 11, 'E2');
CALL add_guest_booking('Lasith Perera', 'Male', '1985-06-08', 'BU4292992', '0775572723', 11, 'E3');
CALL add_guest_booking('Rashmi Dias', 'Male', '1987-01-06', 'BU9601725', '0776580423', 11, 'E4');
CALL add_guest_booking('Nuwan Wijesinghe', 'Male', '1981-08-19', 'BU8823637', '0775656725', 11, 'E5');
CALL add_guest_booking('Hansika Senanayake', 'Female', '2017-10-29', 'BU4945774', '0773405531', 11, 'E6');
CALL add_guest_booking('Chamara Bandara', 'Female', '1989-07-15', 'BU3179425', '0776558386', 11, 'E7');
CALL add_guest_booking('Rajiv Jayasena', 'Female', '1995-05-21', 'BU4562095', '0772303930', 11, 'B1');
CALL add_guest_booking('Rajiv Jayasena', 'Male', '2016-03-29', 'BU9833891', '0779101976', 11, 'B2');
CALL add_guest_booking('Damith Kumara', 'Male', '1991-07-06', 'BU3911632', '0774206861', 11, 'B3');

-- schedule 12

CALL add_registered_booking('jacobmartinez@example.com', 12, 'P1');
CALL add_registered_booking('owenyoung@example.com', 12, 'P2');
CALL add_registered_booking('penelopewalker@example.com', 12, 'P3');
CALL add_registered_booking('lukewalker@example.com', 12, 'P4');
CALL add_registered_booking('zoelewis@example.com', 12, 'P5');
CALL add_registered_booking('wyattgarcia@example.com', 12, 'P6');
CALL add_registered_booking('hannahevans@example.com', 12, 'P7');
CALL add_registered_booking('chloewhite@example.com', 12, 'B12');
CALL add_registered_booking('carterperez@example.com', 12, 'B13');
CALL add_registered_booking('laylaanderson@example.com', 12, 'B14');
CALL add_guest_booking('Dulani Jayasekara', 'Female', '2006-12-02', 'BU4287986', '0776135239', 12, 'E1');
CALL add_guest_booking('Dileepa Gamage', 'Male', '1991-11-19', 'BU2406075', '0775091345', 12, 'E2');
CALL add_guest_booking('Isuru Kumara', 'Female', '1981-03-05', 'BU2499701', '0772381283', 12, 'E3');
CALL add_guest_booking('Vindya Kumari', 'Male', '1980-01-05', 'BU1932493', '0771834045', 12, 'E4');
CALL add_guest_booking('Upeksha Ranasinghe', 'Female', '2000-12-12', 'BU3208273', '0777755788', 12, 'E5');
CALL add_guest_booking('Sandali Perera', 'Female', '2015-06-19', 'BU9076502', '0773922022', 12, 'E6');
CALL add_guest_booking('Suresh Wijesinghe', 'Male', '2018-04-25', 'BU9708888', '0774172326', 12, 'E7');
CALL add_guest_booking('Shalika Fernando', 'Male', '2000-07-26', 'BU1980019', '0778637483', 12, 'B1');
CALL add_guest_booking('Indika Kumara', 'Male', '2004-09-20', 'BU4042828', '0777486921', 12, 'B2');
CALL add_guest_booking('Nilakshi Jayasinghe', 'Male', '2000-02-06', 'BU4627541', '0778845765', 12, 'B3');

-- schedule 13

CALL add_registered_booking('madisonscott@example.com', 13, 'P1');
CALL add_registered_booking('evelynperez@example.com', 13, 'P2');
CALL add_registered_booking('ameliascott@example.com', 13, 'P3');
CALL add_registered_booking('isabellagreen@example.com', 13, 'P4');
CALL add_registered_booking('ariagarcia@example.com', 13, 'P5');
CALL add_registered_booking('dylanclark@example.com', 13, 'P6');
CALL add_registered_booking('jameslee@example.com', 13, 'P7');
CALL add_registered_booking('gabrielwalker@example.com', 13, 'B12');
CALL add_registered_booking('michaelharris@example.com', 13, 'B13');
CALL add_registered_booking('jacksonwright@example.com', 13, 'B14');
CALL add_guest_booking('Shehan Gamage', 'Male', '1994-12-02', 'BU3862157', '0771882731', 13, 'E1');
CALL add_guest_booking('Nadeeka Pathirana', 'Female', '1981-09-25', 'BU5136337', '0779184528', 13, 'E2');
CALL add_guest_booking('Isuru Kumara', 'Female', '1998-03-20', 'BU1497595', '0775344802', 13, 'E3');
CALL add_guest_booking('Suresh Wijesinghe', 'Male', '2018-05-23', 'BU6488450', '0771612501', 13, 'E4');
CALL add_guest_booking('Thilanka Jayasuriya', 'Male', '2003-12-30', 'BU8166780', '0777542151', 13, 'E5');
CALL add_guest_booking('Upul Bandara', 'Male', '2011-01-22', 'BU1522704', '0774069936', 13, 'E6');
CALL add_guest_booking('Ruwan Karunaratne', 'Female', '1993-04-28', 'BU7892043', '0773781956', 13, 'E7');
CALL add_guest_booking('Kanchana Perera', 'Female', '1989-09-25', 'BU6830196', '0774647044', 13, 'B1');
CALL add_guest_booking('Ramesh Jayakody', 'Male', '1994-11-15', 'BU2203115', '0778060014', 13, 'B2');
CALL add_guest_booking('Nadeeka Pathirana', 'Female', '1991-09-10', 'BU8792532', '0771337794', 13, 'B3');

-- schedule 14

-- Registered Users (Example Emails)
CALL add_registered_booking('evelynperez@example.com', 14, 'E1');  -- Economy
CALL add_registered_booking('harperwalker@example.com', 14, 'E2');  -- Economy
CALL add_registered_booking('elijahharris@example.com', 14, 'B1');  -- Business
CALL add_registered_booking('ellahill@example.com', 14, 'B2');  -- Business
CALL add_registered_booking('jacobmartinez@example.com', 14, 'E3');  -- Economy
CALL add_registered_booking('natalieking@example.com', 14, 'E4');  -- Economy
CALL add_registered_booking('victorialewis@example.com', 14, 'E5');  -- Economy
CALL add_registered_booking('isaacmartinez@example.com', 14, 'E6');  -- Economy
CALL add_registered_booking('lukewalker@example.com', 14, 'E41');  -- Economy
CALL add_registered_booking('natalieking@example.com', 14, 'E42');  -- Economy

-- Guest Users Booking
CALL add_guest_booking('Anushka Silva', 'Female', '1990-05-14', 'SLP1234567', '0771234567', 14, 'P1');  -- Platinum
CALL add_guest_booking('Rajesh Kumar', 'Male', '1985-08-21', 'IND1234567', '9812345678', 14, 'E21');   -- Economy
CALL add_guest_booking('Siti Rahma', 'Female', '1992-11-10', 'IDP1234567', '0812345678', 14, 'E8');   -- Economy
CALL add_guest_booking('Arjun Desai', 'Male', '1991-02-15', 'IND7654321', '9123456789', 14, 'E9');    -- Economy
CALL add_guest_booking('Lakshmi Perera', 'Female', '1988-04-12', 'SLP7654321', '0777654321', 14, 'E10'); -- Economy
CALL add_guest_booking('Rani Wijaya', 'Female', '1995-06-30', 'IDP7654321', '0823456789', 14, 'E31');   -- Economy
CALL add_guest_booking('Tharindu Jayasinghe', 'Male', '1987-03-08', 'SLP2345678', '0712345678', 14, 'E32'); -- Economy
CALL add_guest_booking('Sumit Singh', 'Male', '1989-09-17', 'IND2345678', '9876543210', 14, 'E33');    -- Economy
CALL add_guest_booking('Budi Santoso', 'Male', '1993-07-25', 'IDP2345678', '0856789123', 14, 'E14');    -- Economy
CALL add_guest_booking('Nimal Perera', 'Male', '1980-12-10', 'SLP3456789', '0712345679', 14, 'E15');   -- Economy

-- schedule 15

-- Registered Users Bookings
CALL add_registered_booking('ellahill@example.com', 15, 'P1');  -- Platinum
CALL add_registered_booking('owenyoung@example.com', 15, 'B1');  -- Business
CALL add_registered_booking('williamthomas@example.com', 15, 'B2');  -- Business
CALL add_registered_booking('harperwalker@example.com', 15, 'B3');  -- Business
CALL add_registered_booking('lunarobinson@example.com', 15, 'E1');  -- Economy
CALL add_registered_booking('matthewharris@example.com', 15, 'E2');  -- Economy
CALL add_registered_booking('wyattgarcia@example.com', 15, 'E3');  -- Economy
CALL add_registered_booking('penelopewalker@example.com', 15, 'E4');  -- Economy
CALL add_registered_booking('islarobinson@example.com', 15, 'E5'); -- Economy
CALL add_registered_booking('christopherthomas@example.com', 15, 'E20'); -- Economy

-- Guest Users Bookings
SET SQL_SAFE_UPDATES = 0;

CALL add_guest_booking('Devendra Patel', 'Male', '2010-03-12', 'IND2345678', '9876543210', 15, 'B4');  -- Business
CALL add_guest_booking('Samantha Fernando', 'Female', '1992-01-20', 'SLP8765432', '0771234567', 15, 'P3');  -- Platinum
CALL add_guest_booking('Rajiv Mehta', 'Male', '1985-05-30', 'IND3456789', '9812345678', 15, 'E6');   -- Economy
CALL add_guest_booking('Dewi Lestari', 'Female', '1993-04-15', 'IDP9876543', '0812345678', 15, 'E7');  -- Economy
CALL add_guest_booking('Priya Singh', 'Female', '1988-11-09', 'IND6543210', '9123456789', 15, 'E8');  -- Economy
CALL add_guest_booking('Nimal Kithsiri', 'Male', '1990-06-18', 'SLP3456789', '0712345678', 15, 'E9');  -- Economy
CALL add_guest_booking('Ika Putri', 'Female', '1995-02-25', 'IDP7654321', '0823456789', 15, 'E10');   -- Economy
CALL add_guest_booking('Manoj Kumar', 'Male', '1991-07-30', 'IND1234567', '9876543210', 15, 'E11');   -- Economy
CALL add_guest_booking('Maduni Karunarathne', 'Female', '2002-02-25', 'IDP7004321', '0800056785', 15, 'E21');   -- Economy
CALL add_guest_booking('Prathap Niroshan', 'Male', '2003-07-30', 'IND1234567', '9276512310', 15, 'E22');   -- Economy

-- schedule 16

-- registered
CALL add_registered_booking('calebscott@example.com', 16, 'P1');
CALL add_registered_booking('ariagarcia@example.com', 16, 'P2');
CALL add_registered_booking('williamthomas@example.com', 16, 'P3');
CALL add_registered_booking('ariayoung@example.com', 16, 'E4');
CALL add_registered_booking('owenyoung@example.com', 16, 'E5');
CALL add_registered_booking('julianturner@example.com', 16, 'E6');
CALL add_registered_booking('sofiahernandez@example.com', 16, 'P7');
CALL add_registered_booking('graceallen@example.com', 16, 'B12');
CALL add_registered_booking('samanthaallen@example.com', 16, 'B13');
CALL add_registered_booking('henrycarter@example.com', 16, 'B14');

-- guest
CALL add_guest_booking('Arjun Perera', 'Male', '1990-05-15', 'SLP1234567', '0712345670', 16, 'E1');  -- Economy
CALL add_guest_booking('Nirosha Fernando', 'Female', '1988-10-30', 'SLP1234568', '0712345671', 16, 'E2');  -- Economy
CALL add_guest_booking('Kanishka Silva', 'Male', '1985-08-22', 'SLP1234569', '0712345672', 16, 'B1');  -- Business
CALL add_guest_booking('Putra Santoso', 'Male', '1995-11-01', 'IDP1234567', '0823456780', 16, 'E3');  -- Economy
CALL add_guest_booking('Ayu Wulandari', 'Female', '1992-04-12', 'IDP1234568', '0823456781', 16, 'B2');  -- Business
CALL add_guest_booking('Rani Pratiwi', 'Female', '1993-03-14', 'IDP1234569', '0823456782', 16, 'E14');  -- Economy
CALL add_guest_booking('Rahul Sharma', 'Male', '1987-06-30', 'IND1234567', '9876543200', 16, 'E15');  -- Economy
CALL add_guest_booking('Priya Desai', 'Female', '1994-12-11', 'IND1234568', '9876543201', 16, 'E16');  -- Economy
CALL add_guest_booking('Deepak Mehta', 'Male', '1991-07-22', 'IND1234569', '9876543202', 16, 'E7');  -- Economy
CALL add_guest_booking('Anjali Nair', 'Female', '1989-09-18', 'IND1234570', '9876543203', 16, 'E8');  -- Economy

-- schedule 17

-- registered
CALL add_registered_booking('davidmartinez@example.com', 17, 'E1');
CALL add_registered_booking('jackrodriguez@example.com', 17, 'E2');
CALL add_registered_booking('jameslee@example.com', 17, 'E3');
CALL add_registered_booking('jameslee@example.com', 17, 'E4');
CALL add_registered_booking('lukewalker@example.com', 17, 'E5');
CALL add_registered_booking('gabrielwalker@example.com', 17, 'E6');
CALL add_registered_booking('dylanclark@example.com', 17, 'E7');
CALL add_registered_booking('lukewalker@example.com', 17, 'B12');
CALL add_registered_booking('penelopewalker@example.com', 17, 'B13');
CALL add_registered_booking('graceharris@example.com', 17, 'B14');

-- guest
CALL add_guest_booking('Niranjan Silva', 'Male', '1986-03-12', 'SLP9876543', '0719876543', 17, 'E11');  -- Economy
CALL add_guest_booking('Sanjay Perera', 'Male', '1992-11-25', 'SLP9876544', '0719876544', 17, 'E12');  -- Economy
CALL add_guest_booking('Lahiru Bandara', 'Male', '1990-01-17', 'SLP9876545', '0719876545', 17, 'B1');   -- Business
CALL add_guest_booking('Dewi Anjani', 'Female', '1993-05-21', 'IDP9876543', '0829876543', 17, 'E13');  -- Economy
CALL add_guest_booking('Rizky Setiawan', 'Male', '1989-09-04', 'IDP9876544', '0829876544', 17, 'E14');  -- Economy
CALL add_guest_booking('Siti Rahma', 'Female', '1991-04-15', 'IDP9876545', '0829876545', 17, 'E15');  -- Economy
CALL add_guest_booking('Rajesh Kumar', 'Male', '1988-07-30', 'IND9876543', '9876543204', 17, 'E16');  -- Economy
CALL add_guest_booking('Pooja Verma', 'Female', '1994-10-18', 'IND9876544', '9876543205', 17, 'E17');  -- Economy
CALL add_guest_booking('Vikram Mehta', 'Male', '1985-08-22', 'IND9876545', '9876543206', 17, 'E18');  -- Economy
CALL add_guest_booking('Anita Iyer', 'Female', '1993-06-11', 'IND9876546', '9876543207', 17, 'E19');  -- Economy


-- schedule 18

-- registered
CALL add_registered_booking('victorialewis@example.com', 18, 'P1');
CALL add_registered_booking('leolopez@example.com', 18, 'P2');
CALL add_registered_booking('evelynperez@example.com', 18, 'P3');
CALL add_registered_booking('benjaminhall@example.com', 18, 'P4');
CALL add_registered_booking('lucasthompson@example.com', 18, 'P5');
CALL add_registered_booking('nathanallen@example.com', 18, 'P6');
CALL add_registered_booking('lilyjackson@example.com', 18, 'P7');
CALL add_registered_booking('chloewhite@example.com', 18, 'B12');
CALL add_registered_booking('chloewhite@example.com', 18, 'E13');
CALL add_registered_booking('danielmoore@example.com', 18, 'E14');

-- guest
CALL add_guest_booking('Dilhan Fernando', 'Male', '1987-02-15', 'SLP1234567', '0712345670', 18, 'B1');   -- Business
CALL add_guest_booking('Suresh Kumar', 'Male', '1985-04-12', 'IND1234568', '9876543211', 18, 'B2');   -- Business
CALL add_guest_booking('Nandika Jayasuriya', 'Female', '1990-11-05', 'SLP1234569', '0712345671', 18, 'B3');  -- Business
CALL add_guest_booking('Siti Nurhaliza', 'Female', '1994-01-21', 'IDP1234567', '0823456781', 18, 'B4');   -- Business
CALL add_guest_booking('Ravi Patel', 'Male', '1988-06-10', 'IND1234569', '9876543212', 18, 'B5');    -- Business
CALL add_guest_booking('Chathura Kaluarachchi', 'Male', '1991-03-14', 'SLP1234570', '0712345672', 18, 'E11');  -- Economy
CALL add_guest_booking('Penny Amira', 'Female', '1992-05-30', 'IDP1234571', '0823456782', 18, 'E12');  -- Economy
CALL add_guest_booking('Ajay Singh', 'Male', '1989-09-07', 'IND1234572', '9876543213', 18, 'E23');   -- Economy
CALL add_guest_booking('Nisha Sharma', 'Female', '1995-08-25', 'IND1234573', '9876543214', 18, 'E24');   -- Economy
CALL add_guest_booking('Ramilah Jamil', 'Female', '1993-12-19', 'IDP1234574', '0823456783', 18, 'E15');   -- Economy


-- schedule 19

-- registered
CALL add_registered_booking('evelynperez@example.com', 19, 'E1');
CALL add_registered_booking('islarobinson@example.com', 19, 'E2');
CALL add_registered_booking('ellathompson@example.com', 19, 'P3');
CALL add_registered_booking('julianturner@example.com', 19, 'P4');
CALL add_registered_booking('lucasrodriguez@example.com', 19, 'P5');
CALL add_registered_booking('averyadams@example.com', 19, 'P6');
CALL add_registered_booking('michaelharris@example.com', 19, 'B2');
CALL add_registered_booking('penelopewalker@example.com', 19, 'B1');
CALL add_registered_booking('ariagarcia@example.com', 19, 'B3');
CALL add_registered_booking('graceallen@example.com', 19, 'B4');

-- guest
CALL add_guest_booking('Samitha Perera', 'Male', '1986-09-14', 'SLP8765432', '0719876543', 19, 'B5');   -- Business
CALL add_guest_booking('Adhitya Bagus', 'Male', '1984-12-03', 'IDP8765432', '0821987654', 19, 'B6');    -- Business
CALL add_guest_booking('Anjali Iyer', 'Female', '1993-07-20', 'IND8765432', '9876543215', 19, 'B7');    -- Business
CALL add_guest_booking('Liam Fernando', 'Male', '2011-03-05', 'SLP8765433', '0712345673', 19, 'B8');   -- Business
CALL add_guest_booking('Putri Maya', 'Female', '2014-11-17', 'IDP8765433', '0823456784', 19, 'B9');    -- Business
CALL add_guest_booking('Rashmika Mandanna', 'Female', '1995-04-05', 'IND8765433', '9876543216', 19, 'E16');   -- Economy
CALL add_guest_booking('Kumar Singh', 'Male', '1989-08-10', 'IND8765434', '9876543217', 19, 'E17');   -- Economy
CALL add_guest_booking('Jaya Indran', 'Female', '1990-06-22', 'SLP8765434', '0712345674', 19, 'E18');   -- Economy
CALL add_guest_booking('Anya Puspita', 'Female', '1992-03-18', 'IDP8765434', '0823456785', 19, 'E19');   -- Economy
CALL add_guest_booking('Sanjay Patel', 'Male', '1988-05-25', 'IND8765435', '9876543218', 19, 'E20');   -- Economy


-- schedule 20

-- registered
CALL add_registered_booking('lukewalker@example.com', 20, 'P1');
CALL add_registered_booking('hannahevans@example.com', 20, 'P2');
CALL add_registered_booking('alexanderroberts@example.com', 20, 'P3');
CALL add_registered_booking('lunarobinson@example.com', 20, 'P4');
CALL add_registered_booking('benjaminhall@example.com', 20, 'P5');
CALL add_registered_booking('chloewhite@example.com', 20, 'P6');
CALL add_registered_booking('averywright@example.com', 20, 'P7');
CALL add_registered_booking('zoeynelson@example.com', 20, 'E12');
CALL add_registered_booking('aubreylewis@example.com', 20, 'E13');
CALL add_registered_booking('lilyjackson@example.com', 20, 'E14');

-- guest
CALL add_guest_booking('Niroshan Silva', 'Male', '1985-07-21', 'SLP1234567', '0712345678', 20, 'E3');   -- Economy
CALL add_guest_booking('Dewi Anggraini', 'Female', '1990-11-11', 'IDP1234568', '0821456789', 20, 'E15');  -- Economy
CALL add_guest_booking('Rajesh Kumar', 'Male', '1992-03-30', 'IND1234569', '9876543210', 20, 'E24');    -- Economy
CALL add_guest_booking('Kamalika Jayasuriya', 'Female', '1988-09-14', 'SLP1234570', '0719876543', 20, 'E5');   -- Economy
CALL add_guest_booking('Budi Santoso', 'Male', '1991-06-01', 'IDP1234571', '0822567890', 20, 'E8');    -- Economy
CALL add_guest_booking('Deepa Menon', 'Female', '1995-02-22', 'IND1234572', '9876543211', 20, 'E10');   -- Economy
CALL add_guest_booking('Arjun Patel', 'Male', '1987-12-17', 'IND1234573', '9876543212', 20, 'E11');    -- Economy
CALL add_guest_booking('Putu Lestari', 'Female', '1994-08-28', 'IDP1234574', '0823456780', 20, 'E19');   -- Economy
CALL add_guest_booking('Kaviya Perera', 'Female', '1993-04-30', 'SLP1234575', '0712345679', 20, 'E20');   -- Economy
CALL add_guest_booking('Ravi Sharma', 'Male', '2016-10-10', 'IND1234576', '9876543213', 20, 'E21');    -- Economy


-- schedule 21

-- registered
CALL add_registered_booking('penelopewalker@example.com', 21, 'E1');
CALL add_registered_booking('ameliascott@example.com', 21, 'E2');
CALL add_registered_booking('isabellagreen@example.com', 21, 'E3');
CALL add_registered_booking('sebastianking@example.com', 21, 'E4');
CALL add_registered_booking('lucasrodriguez@example.com', 21, 'E5');
CALL add_registered_booking('ariagarcia@example.com', 21, 'B1');
CALL add_registered_booking('danielmoore@example.com', 21, 'B2');
CALL add_registered_booking('zoelewis@example.com', 21, 'B12');
CALL add_registered_booking('natalieking@example.com', 21, 'B13');
CALL add_registered_booking('laylaanderson@example.com', 21, 'B14');

-- guest
CALL add_guest_booking('Saman Weerasinghe', 'Male', '1982-04-15', 'SLP1234580', '0712233445', 21, 'B3');   -- Business
CALL add_guest_booking('Nadia Sari', 'Female', '1991-05-22', 'IDP1234581', '0822233446', 21, 'B4');    -- Business
CALL add_guest_booking('Ajith Fernando', 'Male', '1990-12-05', 'SLP1234582', '0712233447', 21, 'E6');  -- Economy
CALL add_guest_booking('Putri Handayani', 'Female', '1985-11-12', 'IDP1234583', '0822233448', 21, 'E7');  -- Economy
CALL add_guest_booking('Rahul Singh', 'Male', '1993-09-19', 'IND1234584', '9876543214', 21, 'E8');     -- Economy
CALL add_guest_booking('Chandana Rajapaksa', 'Female', '1988-02-29', 'SLP1234585', '0712233449', 21, 'E9'); -- Economy
CALL add_guest_booking('Wayan Budi', 'Male', '1994-06-16', 'IDP1234586', '0822233450', 21, 'E10');    -- Economy
CALL add_guest_booking('Sunil Kumar', 'Male', '1992-10-07', 'IND1234587', '9876543215', 21, 'E11');    -- Economy
CALL add_guest_booking('Anjali Devi', 'Female', '1995-03-04', 'IND1234588', '9876543216', 21, 'E12');   -- Economy
CALL add_guest_booking('Dewi Ratih', 'Female', '1989-08-19', 'IDP1234589', '0822233451', 21, 'E13');    -- Economy


-- schedule 22

-- registered
CALL add_registered_booking('hannahevans@example.com', 22, 'E1');
CALL add_registered_booking('dylanclark@example.com', 22, 'P2');
CALL add_registered_booking('calebscott@example.com', 22, 'E3');
CALL add_registered_booking('isaacmartinez@example.com', 22, 'P4');
CALL add_registered_booking('lukewalker@example.com', 22, 'P5');
CALL add_registered_booking('isabellagreen@example.com', 22, 'P6');
CALL add_registered_booking('jacobmartinez@example.com', 22, 'P7');
CALL add_registered_booking('emilyanderson@example.com', 22, 'E12');
CALL add_registered_booking('julianturner@example.com', 22, 'B13');
CALL add_registered_booking('madisonscott@example.com', 22, 'B14');

-- guest
CALL add_guest_booking('Priya Fernando', 'Female', '1987-01-15', 'SLP1234590', '0712233452', 22, 'E2');   -- Economy
CALL add_guest_booking('Indra Putra', 'Male', '1990-07-10', 'IDP1234591', '0822233453', 22, 'E13');     -- Economy
CALL add_guest_booking('Naveen Kumar', 'Male', '1995-03-20', 'IND1234592', '9876543217', 22, 'E4');    -- Economy
CALL add_guest_booking('Aditi Sharma', 'Female', '1992-06-12', 'IND1234593', '9876543218', 22, 'E25');   -- Economy
CALL add_guest_booking('Suhana Wickramasinghe', 'Female', '1998-09-25', 'SLP1234594', '0712233454', 22, 'E26'); -- Economy
CALL add_guest_booking('Arief Kurniawan', 'Male', '1986-12-01', 'IDP1234595', '0822233455', 22, 'E27');   -- Economy
CALL add_guest_booking('Ravi Menon', 'Male', '1994-04-18', 'IND1234596', '9876543219', 22, 'E28');        -- Economy
CALL add_guest_booking('Nina Jayawardena', 'Female', '1985-11-30', 'SLP1234597', '0712233456', 22, 'E9'); -- Economy
CALL add_guest_booking('Budi Santoso', 'Male', '1989-05-14', 'IDP1234598', '0822233456', 22, 'E10');     -- Economy
CALL add_guest_booking('Meera Kumari', 'Female', '1991-08-21', 'IND1234599', '9876543220', 22, 'E11');    -- Economy


-- schedule 23

-- registered
CALL add_registered_booking('hannahevans@example.com', 23, 'P1');
CALL add_registered_booking('sebastianking@example.com', 23, 'E12');
CALL add_registered_booking('masonmartin@example.com', 23, 'E13');
CALL add_registered_booking('aubreylewis@example.com', 23, 'E4');
CALL add_registered_booking('laylaanderson@example.com', 23, 'E5');
CALL add_registered_booking('islarobinson@example.com', 23, 'E6');
CALL add_registered_booking('sofiahernandez@example.com', 23, 'P7');
CALL add_registered_booking('jacobmartinez@example.com', 23, 'B12');
CALL add_registered_booking('williamthomas@example.com', 23, 'B13');
CALL add_registered_booking('avawright@example.com', 23, 'B14');

-- guest
CALL add_guest_booking('Sanjana Perera', 'Female', '1990-02-15', 'SLP1234600', '0712233460', 23, 'E1');  -- Economy
CALL add_guest_booking('Asep Rahman', 'Male', '1988-03-22', 'IDP1234601', '0822233461', 23, 'E3');      -- Economy
CALL add_guest_booking('Vikram Desai', 'Male', '1994-07-30', 'IND1234602', '9876543221', 23, 'E7');     -- Economy
CALL add_guest_booking('Meghna Iyer', 'Female', '1995-05-12', 'IND1234603', '9876543222', 23, 'E8');     -- Economy
CALL add_guest_booking('Diana Kumar', 'Female', '1992-01-19', 'SLP1234604', '0712233462', 23, 'E9');    -- Economy
CALL add_guest_booking('Ravi Chandran', 'Male', '1987-08-15', 'IND1234605', '9876543223', 23, 'E10');    -- Economy
CALL add_guest_booking('Puja Singh', 'Female', '1991-06-03', 'IND1234606', '9876543224', 23, 'E15');     -- Economy
CALL add_guest_booking('Iwan Santoso', 'Male', '1985-11-27', 'IDP1234607', '0822233462', 23, 'E16');     -- Economy
CALL add_guest_booking('Chathuri De Silva', 'Female', '1993-10-10', 'SLP1234608', '0712233463', 23, 'E20'); -- Economy
CALL add_guest_booking('Santi Lestari', 'Female', '1989-04-05', 'IDP1234609', '0822233463', 23, 'E22');   -- Economy


-- schedule 24

-- registered
CALL add_registered_booking('henrycarter@example.com', 24, 'P1');
CALL add_registered_booking('loganphillips@example.com', 24, 'P2');
CALL add_registered_booking('ariagarcia@example.com', 24, 'P3');
CALL add_registered_booking('ariagarcia@example.com', 24, 'P4');
CALL add_registered_booking('penelopewalker@example.com', 24, 'P5');
CALL add_registered_booking('islarobinson@example.com', 24, 'P6');
CALL add_registered_booking('natalieking@example.com', 24, 'P7');
CALL add_registered_booking('zoeynelson@example.com', 24, 'E2');
CALL add_registered_booking('gabrielwalker@example.com', 24, 'E23');
CALL add_registered_booking('graceharris@example.com', 24, 'E24');

-- guest
CALL add_guest_booking('Nisha Fernando', 'Female', '1995-01-10', 'SLP1234610', '0712233464', 24, 'B1');  -- Business
CALL add_guest_booking('Anand Sharma', 'Male', '1984-09-20', 'IND1234611', '9876543225', 24, 'B2');      -- Business
CALL add_guest_booking('Nadia Rahman', 'Female', '1992-12-11', 'IDP1234612', '0822233464', 24, 'E5');   -- Economy
CALL add_guest_booking('Rani Kumari', 'Female', '2010-03-14', 'IND1234613', '9876543226', 24, 'E6');     -- Economy
CALL add_guest_booking('Arjun Wickramasinghe', 'Male', '2012-07-03', 'SLP1234614', '0712233465', 24, 'E9');  -- Economy
CALL add_guest_booking('Ayu Sari', 'Female', '2009-04-28', 'IDP1234615', '0822233465', 24, 'E11');      -- Economy
CALL add_guest_booking('Kavi Anandan', 'Male', '1985-08-08', 'IND1234616', '9876543227', 24, 'E15');    -- Economy
CALL add_guest_booking('Siti Aisyah', 'Female', '1988-05-18', 'IDP1234617', '0822233466', 24, 'E17');    -- Economy
CALL add_guest_booking('Dinesh Perera', 'Male', '1994-02-02', 'SLP1234618', '0712233466', 24, 'E19');   -- Economy
CALL add_guest_booking('Lina Pratiwi', 'Female', '1996-06-06', 'IDP1234619', '0822233467', 24, 'E21');   -- Economy


-- schedule 25

-- registered
CALL add_registered_booking('loganphillips@example.com', 25, 'E21');
CALL add_registered_booking('ariayoung@example.com', 25, 'E22');
CALL add_registered_booking('jackrodriguez@example.com', 25, 'E3');
CALL add_registered_booking('ethanwhite@example.com', 25, 'E4');
CALL add_registered_booking('gabrielking@example.com', 25, 'E5');
CALL add_registered_booking('owenyoung@example.com', 25, 'E6');
CALL add_registered_booking('samanthaallen@example.com', 25, 'E7');
CALL add_registered_booking('henrycarter@example.com', 25, 'B12');
CALL add_registered_booking('jameslee@example.com', 25, 'B13');
CALL add_registered_booking('averyadams@example.com', 25, 'B14');

-- guest
CALL add_guest_booking('Kamalika Silva', 'Female', '1990-02-15', 'SLP1234620', '0712233470', 25, 'B1');   -- Business
CALL add_guest_booking('Rohit Gupta', 'Male', '1988-11-20', 'IND1234621', '9876543228', 25, 'B2');       -- Business
CALL add_guest_booking('Siti Lestari', 'Female', '1995-09-05', 'IDP1234622', '0822233470', 25, 'P1');    -- Platinum
CALL add_guest_booking('Ravi Perera', 'Male', '1987-03-30', 'SLP1234623', '0712233471', 25, 'P2');       -- Platinum
CALL add_guest_booking('Diana Wijaya', 'Female', '1992-06-12', 'IDP1234624', '0822233471', 25, 'E8');     -- Economy
CALL add_guest_booking('Aminath Latheefa', 'Female', '1993-07-01', 'IND1234625', '9876543229', 25, 'E10');  -- Economy
CALL add_guest_booking('Rajesh Kumar', 'Male', '1985-01-25', 'IND1234626', '9876543230', 25, 'E12');      -- Economy
CALL add_guest_booking('Nusrat Rani', 'Female', '1994-10-09', 'IDP1234627', '0822233472', 25, 'E14');     -- Economy
CALL add_guest_booking('Aruna Wickramasinghe', 'Female', '1986-08-20', 'SLP1234628', '0712233472', 25, 'E16'); -- Economy
CALL add_guest_booking('Budi Santoso', 'Male', '1991-04-18', 'IDP1234629', '0822233473', 25, 'E18');      -- Economy


-- schedule 26

-- registered
CALL add_registered_booking('jacksonwright@example.com', 26, 'P1');
CALL add_registered_booking('jameslee@example.com', 26, 'E2');
CALL add_registered_booking('lucasthompson@example.com', 26, 'E3');
CALL add_registered_booking('penelopewalker@example.com', 26, 'E4');
CALL add_registered_booking('madisonscott@example.com', 26, 'P5');
CALL add_registered_booking('graceallen@example.com', 26, 'P6');
CALL add_registered_booking('jacksonwright@example.com', 26, 'P7');
CALL add_registered_booking('carterperez@example.com', 26, 'B12');
CALL add_registered_booking('henrycarter@example.com', 26, 'B3');
CALL add_registered_booking('owenyoung@example.com', 26, 'B4');

-- guest
CALL add_guest_booking('Tharindu Kumara', 'Male', '1989-05-10', 'SLP1234630', '0712233473', 26, 'B1');   -- Business
CALL add_guest_booking('Priya Singh', 'Female', '1990-02-28', 'IND1234631', '9876543231', 26, 'B2');       -- Business
CALL add_guest_booking('Lina Sari', 'Female', '1993-07-15', 'IDP1234632', '0822233474', 26, 'E5');         -- Economy
CALL add_guest_booking('Nimal Fernando', 'Male', '1992-09-25', 'SLP1234633', '0712233474', 26, 'E8');      -- Economy
CALL add_guest_booking('Aisha Rahman', 'Female', '1994-11-30', 'IND1234634', '9876543232', 26, 'E10');     -- Economy
CALL add_guest_booking('Samuel Jaya', 'Male', '1987-01-12', 'IDP1234635', '0822233475', 26, 'E12');        -- Economy
CALL add_guest_booking('Ananya Gupta', 'Female', '1995-03-09', 'IND1234636', '9876543233', 26, 'E14');     -- Economy
CALL add_guest_booking('Arun Abeysinghe', 'Male', '1988-08-22', 'SLP1234637', '0712233475', 26, 'E16');     -- Economy
CALL add_guest_booking('Dewi Santika', 'Female', '1991-10-05', 'IDP1234638', '0822233476', 26, 'E18');      -- Economy
CALL add_guest_booking('Ramesh Iyer', 'Male', '1986-04-15', 'IND1234639', '9876543234', 26, 'E20');         -- Economy

-- schedule 27

CALL add_registered_booking('gabrielking@example.com', 27, 'P1');
CALL add_registered_booking('aubreylewis@example.com', 27, 'P2');
CALL add_registered_booking('isaacmartinez@example.com', 27, 'P3');
CALL add_registered_booking('loganphillips@example.com', 27, 'P4');
CALL add_registered_booking('evelynperez@example.com', 27, 'P5');
CALL add_registered_booking('benjaminhall@example.com', 27, 'P6');
CALL add_registered_booking('lillianhall@example.com', 27, 'P7');
CALL add_registered_booking('madisonscott@example.com', 27, 'B12');
CALL add_registered_booking('zoeynelson@example.com', 27, 'B13');
-- CALL add_registered_booking('sebastianking@example.com', 27, 'B14');

-- schedule 28

CALL add_registered_booking('wyattgarcia@example.com', 28, 'P1');
CALL add_registered_booking('williamthomas@example.com', 28, 'P2');
CALL add_registered_booking('jameslee@example.com', 28, 'P3');
CALL add_registered_booking('graceharris@example.com', 28, 'P4');
CALL add_registered_booking('isabellagreen@example.com', 28, 'P5');
CALL add_registered_booking('lilyjackson@example.com', 28, 'P6');
CALL add_registered_booking('jacksonwright@example.com', 28, 'P7');
CALL add_registered_booking('samanthaallen@example.com', 28, 'B12');
CALL add_registered_booking('carterperez@example.com', 28, 'B13');
CALL add_registered_booking('loganphillips@example.com', 28, 'B14');

-- guest

CALL add_guest_booking('Aashik Wimalasena', 'Female', '2019-10-10', 'BU5054193', '0777436151', 28, 'E1');
CALL add_guest_booking('Haritha Kumari', 'Male', '2008-04-25', 'BU6164081', '0778223512', 28, 'E2');
CALL add_guest_booking('Tharindu Fernando', 'Male', '1985-07-20', 'BU9219377', '0779051098', 28, 'E3');
CALL add_guest_booking('Chandana Fernando', 'Male', '1997-03-06', 'BU8769880', '0777076206', 28, 'E4');
CALL add_guest_booking('Tharindu Fernando', 'Female', '2005-06-14', 'BU5919396', '0778926663', 28, 'E5');
CALL add_guest_booking('Dilshan Silva', 'Female', '1990-10-28', 'BU4443725', '0778059899', 28, 'E6');
CALL add_guest_booking('Haritha Kumari', 'Female', '1997-11-12', 'BU3387177', '0779263403', 28, 'E7');
CALL add_guest_booking('Anjana Perera', 'Female', '1983-03-13', 'BU6561934', '0779659056', 28, 'B1');
CALL add_guest_booking('Priyantha Perera', 'Male', '1997-10-01', 'BU3516948', '0771860303', 28, 'B2');
CALL add_guest_booking('Aashan Dissanayake', 'Male', '1982-08-13', 'BU4143261', '0772135677', 28, 'B3');


-- schedule 29

CALL add_registered_booking('emilyanderson@example.com', 29, 'P1');
CALL add_registered_booking('jameslee@example.com', 29, 'P2');
CALL add_registered_booking('williamthomas@example.com', 29, 'P3');
CALL add_registered_booking('ethanwhite@example.com', 29, 'P4');
CALL add_registered_booking('averywright@example.com', 29, 'P5');
CALL add_registered_booking('isabellagreen@example.com', 29, 'P6');
CALL add_registered_booking('averyadams@example.com', 29, 'P7');
CALL add_registered_booking('graceallen@example.com', 29, 'B12');
CALL add_registered_booking('averywright@example.com', 29, 'B13');
CALL add_registered_booking('ariayoung@example.com', 29, 'B14');

-- guest 

CALL add_guest_booking('Aashan Dissanayake', 'Female', '1993-04-09', 'BU6581823', '0771517119', 29, 'E1');
CALL add_guest_booking('Samanthi Jayasena', 'Female', '1983-08-07', 'BU8889578', '0777593121', 29, 'E2');
CALL add_guest_booking('Tanshika Perera', 'Male', '2000-03-12', 'BU7321496', '0774507512', 29, 'E3');
CALL add_guest_booking('Harsha Rajapaksha', 'Male', '2015-08-30', 'BU7903136', '0773069968', 29, 'E4');
CALL add_guest_booking('Aashik Wimalasena', 'Male', '1984-12-01', 'BU6644405', '0774151288', 29, 'E5');
CALL add_guest_booking('Tanshika Perera', 'Female', '2001-04-11', 'BU3105774', '0776567187', 29, 'E6');
CALL add_guest_booking('Thilina Karunaratne', 'Male', '1991-08-22', 'BU9087346', '0775013324', 29, 'E7');
CALL add_guest_booking('Anura Perera', 'Male', '2014-01-21', 'BU2816497', '0775288907', 29, 'B1');
CALL add_guest_booking('Lahiru Perera', 'Male', '1996-07-24', 'BU7962027', '0771129106', 29, 'B2');
call add_guest_booking('Kanishka Weerakoon', 'Male', '1994-10-03', 'BU7219562', '0776556280', 29, 'B3');

-- schedule 30

CALL add_registered_booking('loganphillips@example.com', 30, 'P1');
CALL add_registered_booking('laylaanderson@example.com', 30, 'P2');
CALL add_registered_booking('alexanderroberts@example.com', 30, 'P3');
CALL add_registered_booking('ethanwhite@example.com', 30, 'P4');
CALL add_registered_booking('scarlettmitchell@example.com', 30, 'P5');
CALL add_registered_booking('hannahevans@example.com', 30, 'P6');
CALL add_registered_booking('ariayoung@example.com', 30, 'P7');
CALL add_registered_booking('alexanderroberts@example.com', 30, 'B12');
CALL add_registered_booking('lillianhall@example.com', 30, 'B13');
CALL add_registered_booking('ellathompson@example.com', 30, 'B14');
CALL add_guest_booking('Dulshan Fernando', 'Female', '1984-02-12', 'BU4444960', '0772704717', 30, 'E1');
CALL add_guest_booking('Priyantha Perera', 'Female', '1994-09-23', 'BU5211455', '0776233031', 30, 'E2');
CALL add_guest_booking('Lahiru Perera', 'Female', '1980-09-05', 'BU6963987', '0773201014', 30, 'E3');
CALL add_guest_booking('Kanishka Weerakoon', 'Male', '2011-02-10', 'BU9544295', '0773141684', 30, 'E4');
CALL add_guest_booking('Ramesh Silva', 'Female', '1983-09-13', 'BU4151634', '0774335077', 30, 'E5');
CALL add_guest_booking('Thilina Karunaratne', 'Male', '2003-03-04', 'BU4498749', '0772739455', 30, 'E6');
CALL add_guest_booking('Sanjay Silva', 'Male', '2013-05-28', 'BU2355212', '0774314607', 30, 'E7');
CALL add_guest_booking('Amal Kumar', 'Male', '1992-12-23', 'BU5822818', '0776803599', 30, 'B1');
CALL add_guest_booking('Tanshika Perera', 'Female', '2017-07-13', 'BU8717117', '0779151937', 30, 'B2');
CALL add_guest_booking('Vasantha Fernando', 'Male', '1980-02-28', 'BU3211093', '0771276873', 30, 'B3');


-- schedule 31

CALL add_registered_booking('calebscott@example.com', 31, 'P1');
CALL add_registered_booking('penelopewalker@example.com', 31, 'P2');
CALL add_registered_booking('michaelharris@example.com', 31, 'P3');
CALL add_registered_booking('ameliascott@example.com', 31, 'P4');
CALL add_registered_booking('dylanclark@example.com', 31, 'P5');
CALL add_registered_booking('lillianhall@example.com', 31, 'P6');
CALL add_registered_booking('owenyoung@example.com', 31, 'P7');
CALL add_registered_booking('averywright@example.com', 31, 'B12');
CALL add_registered_booking('averyadams@example.com', 31, 'B13');
CALL add_registered_booking('scarlettmitchell@example.com', 31, 'B14');
CALL add_guest_booking('Nilanjana Senanayake', 'Male', '1989-12-12', 'BU8605062', '0774441441', 31, 'E1');
CALL add_guest_booking('Thilina Karunaratne', 'Male', '2013-03-30', 'BU6325836', '0773096824', 31, 'E2');
CALL add_guest_booking('Tamara Perera', 'Male', '1980-07-26', 'BU1853159', '0778256816', 31, 'E3');
CALL add_guest_booking('Tanshika Perera', 'Male', '1982-01-12', 'BU3021715', '0775600504', 31, 'E4');
CALL add_guest_booking('Vasantha Fernando', 'Male', '2002-03-03', 'BU6765989', '0772150894', 31, 'E5');
CALL add_guest_booking('Ayesha Khan', 'Female', '1990-05-31', 'BU4128319', '0773308418', 31, 'E6');
CALL add_guest_booking('Sanjay Silva', 'Female', '1992-12-25', 'BU2618926', '0772663383', 31, 'E7');
CALL add_guest_booking('Thilina Karunaratne', 'Male', '1985-06-06', 'BU6770882', '0779872525', 31, 'B1');
CALL add_guest_booking('Sanjeewa Abeysinghe', 'Male', '1981-01-11', 'BU6160185', '0771321448', 31, 'B2');
CALL add_guest_booking('Ramesh Silva', 'Female', '1994-05-07', 'BU4282660', '0771374460', 31, 'B3');

-- schedule 32

CALL add_registered_booking('ameliascott@example.com', 32, 'P1');
CALL add_registered_booking('wyattgarcia@example.com', 32, 'P2');
CALL add_registered_booking('lucasrodriguez@example.com', 32, 'P3');
CALL add_registered_booking('hannahevans@example.com', 32, 'P4');
CALL add_registered_booking('ameliascott@example.com', 32, 'P5');
CALL add_registered_booking('sofiahernandez@example.com', 32, 'P6');
CALL add_registered_booking('harperwalker@example.com', 32, 'P7');
CALL add_registered_booking('ameliascott@example.com', 32, 'B12');
CALL add_registered_booking('jacksonwright@example.com', 32, 'B13');
CALL add_registered_booking('calebscott@example.com', 32, 'B14');
CALL add_guest_booking('Samith Kumara', 'Male', '1986-10-03', 'BU5083633', '0773448444', 32, 'E3');
CALL add_guest_booking('Dilshan Silva', 'Male', '2011-10-02', 'BU6581949', '0774591684', 32, 'E4');
CALL add_guest_booking('Samith Kumara', 'Male', '1993-11-15', 'BU3341241', '0778398885', 32, 'E5');
CALL add_guest_booking('Nirmala Perera', 'Female', '2002-11-14', 'BU3766638', '0773934801', 32, 'E7');
CALL add_guest_booking('Dilshan Silva', 'Male', '2006-06-05', 'BU1354146', '0779248838', 32, 'B1');
CALL add_guest_booking('Ramani Jayasinghe', 'Female', '2015-12-26', 'BU6505682', '0773850505', 32, 'B2');
CALL add_guest_booking('Priyantha perera', 'Male', '1981-11-21', 'BU5671491', '0774904092', 32, 'B3');

-- -------------------------------------------------------------------------------------------------------------------------

-- query 01

select passenger_details.passenger_id
from booking 
left join passenger_details on passenger_details.passenger_id = booking.passenger_id
left join schedule on schedule.schedule_id = booking.schedule_id
where schedule.flight_number='FL003' and (select get_passenger_age(passenger_details.passenger_id)>=18);

select passenger_details.passenger_id
from booking 
left join passenger_details on passenger_details.passenger_id = booking.passenger_id
left join schedule on schedule.schedule_id = booking.schedule_id
where schedule.flight_number='FL003' and (select get_passenger_age(passenger_details.passenger_id)<18);

-- query 02

SELECT COUNT(DISTINCT booking.passenger_id) AS no_of_passengers
FROM booking JOIN schedule ON booking.schedule_id = schedule.schedule_id JOIN route ON schedule.route_id = route.route_id
WHERE route.destination_code = 'CGK' AND schedule.departure_time BETWEEN '2024-10-28' AND '2024-10-31';

-- query 03 

SELECT passenger_details.tier, COUNT(booking.booking_id) AS no_of_bookings
FROM booking JOIN passenger_details ON booking.passenger_id = passenger_details.passenger_id JOIN schedule ON booking.schedule_id = schedule.schedule_id
WHERE schedule.departure_time BETWEEN '2024-10-28' AND '2024-10-31'
GROUP BY passenger_details.tier;

-- query 04

SELECT schedule.flight_number, schedule.status, COUNT(booking.passenger_id) AS passenger_count
FROM schedule 
JOIN route ON schedule.route_id = route.route_id
LEFT JOIN booking ON schedule.schedule_id = booking.schedule_id
WHERE route.source_code = 'SUB' AND route.destination_code = 'JOG' AND schedule.departure_time < CURRENT_TIMESTAMP
GROUP BY schedule.schedule_id
ORDER BY schedule.departure_time DESC;

-- query 05

SELECT aircraft.model AS aircraft_model, SUM(booking.ticket_price) AS total_revenue
FROM booking JOIN schedule ON booking.schedule_id = schedule.schedule_id
JOIN aircraft ON schedule.aircraft_id = aircraft.aircraft_id
GROUP BY aircraft.model;


