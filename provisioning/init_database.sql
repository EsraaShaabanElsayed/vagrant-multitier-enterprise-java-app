-- Complete database initialization
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS user_role;
DROP TABLE IF EXISTS user;
DROP TABLE IF EXISTS role;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE user (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    dateOfBirth DATE NULL,
    fatherName VARCHAR(255) NULL,
    gender VARCHAR(50) NULL,
    language VARCHAR(100) NULL,
    maritalStatus VARCHAR(50) NULL,
    motherName VARCHAR(255) NULL,
    nationality VARCHAR(100) NULL,
    password VARCHAR(255) NOT NULL,
    permanentAddress TEXT NULL,
    phoneNumber VARCHAR(20) NULL,
    primaryOccupation VARCHAR(255) NULL,
    profileImg VARCHAR(255) NULL,
    profileImgPath VARCHAR(500) NULL,
    secondaryOccupation VARCHAR(255) NULL,
    secondaryPhoneNumber VARCHAR(20) NULL,
    skills TEXT NULL,
    tempAddress TEXT NULL,
    userEmail VARCHAR(255) NULL,
    username VARCHAR(255) NOT NULL UNIQUE,
    workingExperience TEXT NULL,
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE role (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_role (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES role(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO role (name) VALUES ('ROLE_USER'), ('ROLE_ADMIN');