-- ---------------------------------------------------------
-- SQL Script for DILONA Civil Registry System
-- ---------------------------------------------------------

-- 1. Create the Database (Optional if using Aiven's defaultdb)
CREATE DATABASE IF NOT EXISTS dilona_db;
USE dilona_db;

-- 2. Create Birth Registrations Table
CREATE TABLE IF NOT EXISTS birth_registrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    father_fname VARCHAR(255),
    father_lname VARCHAR(255),
    father_dob VARCHAR(20),
    father_cin VARCHAR(50),
    mother_fname VARCHAR(255),
    mother_lname VARCHAR(255),
    mother_dob VARCHAR(20),
    mother_cin VARCHAR(50),
    mother_address VARCHAR(500),
    newborn_fname VARCHAR(255),
    gender VARCHAR(10),
    newborn_dob VARCHAR(20),
    newborn_birthplace VARCHAR(255),
    pdf_url VARCHAR(1000),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create Death Registrations Table
CREATE TABLE IF NOT EXISTS death_registrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    dtype VARCHAR(20),
    decl_date VARCHAR(20),
    cert_number VARCHAR(50),
    deceased_fname VARCHAR(255),
    deceased_lname VARCHAR(255),
    dgender VARCHAR(10),
    death_date VARCHAR(20),
    death_place VARCHAR(255),
    father_fname VARCHAR(255),
    father_lname VARCHAR(255),
    mother_fname VARCHAR(255),
    mother_lname VARCHAR(255),
    cause_death VARCHAR(255),
    declarant_name VARCHAR(255),
    declarant_cin VARCHAR(50),
    pdf_url VARCHAR(1000),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
