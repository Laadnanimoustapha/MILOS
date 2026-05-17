import mysql from "mysql2/promise";

const connectionString = process.env.AIVEN_DATABASE || "";

let pool: mysql.Pool | null = null;

export function getPool(): mysql.Pool {
  if (!pool) {
    pool = mysql.createPool({
      uri: connectionString,
      waitForConnections: true,
      connectionLimit: 5,
      queueLimit: 0,
    });
  }
  return pool;
}

/**
 * Run the initial schema migration.
 * Safe to call multiple times -- uses IF NOT EXISTS.
 */
export async function initSchema(): Promise<void> {
  const db = getPool();

  await db.execute(`
    CREATE TABLE IF NOT EXISTS birth_registrations (
      id              INT AUTO_INCREMENT PRIMARY KEY,
      father_fname    VARCHAR(255),
      father_lname    VARCHAR(255),
      father_dob      VARCHAR(20),
      father_cin      VARCHAR(50),
      mother_fname    VARCHAR(255),
      mother_lname    VARCHAR(255),
      mother_dob      VARCHAR(20),
      mother_cin      VARCHAR(50),
      mother_address  VARCHAR(500),
      newborn_fname   VARCHAR(255),
      gender          VARCHAR(10),
      newborn_dob     VARCHAR(20),
      newborn_birthplace VARCHAR(255),
      pdf_url         VARCHAR(1000),
      created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  await db.execute(`
    CREATE TABLE IF NOT EXISTS death_registrations (
      id              INT AUTO_INCREMENT PRIMARY KEY,
      dtype           VARCHAR(20),
      decl_date       VARCHAR(20),
      cert_number     VARCHAR(50),
      deceased_fname  VARCHAR(255),
      deceased_lname  VARCHAR(255),
      dgender         VARCHAR(10),
      death_date      VARCHAR(20),
      death_place     VARCHAR(255),
      father_fname    VARCHAR(255),
      father_lname    VARCHAR(255),
      mother_fname    VARCHAR(255),
      mother_lname    VARCHAR(255),
      cause_death     VARCHAR(255),
      declarant_name  VARCHAR(255),
      declarant_cin   VARCHAR(50),
      pdf_url         VARCHAR(1000),
      created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
}
