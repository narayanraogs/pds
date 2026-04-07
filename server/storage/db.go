package storage

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"pds/config"

	_ "github.com/mattn/go-sqlite3"
)

type Page struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Grid string `json:"grid_json"` // JSON encoded grid list of lists
}

type DerivedParameter struct {
	ID         string `json:"id"`
	Mnemonic   string `json:"mnemonic"`
	Unit       string `json:"unit"`
	Expression string `json:"expression"`
}

var DB *sql.DB

func InitializeDB(dbPath string) error {
	// 1. Expand paths
	dbPath = config.ExpandPath(dbPath)

	// 2. Ensure directory exists
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create db directory: %v", err)
	}

	// 3. Open Connection
	var err error
	DB, err = sql.Open("sqlite3", dbPath)
	if err != nil {
		return err
	}

	// 4. Create Tables
	query := `
	CREATE TABLE IF NOT EXISTS pages (
		id TEXT PRIMARY KEY,
		name TEXT,
		grid_json TEXT
	);`

	if _, err := DB.Exec(query); err != nil {
		return err
	}

	queryDerived := `
	CREATE TABLE IF NOT EXISTS derived_parameters (
		id TEXT PRIMARY KEY,
		mnemonic TEXT UNIQUE,
		unit TEXT,
		expression TEXT
	);`

	if _, err := DB.Exec(queryDerived); err != nil {
		return err
	}

	log.Printf("[STORAGE] Database initialized at %s", dbPath)
	return nil
}

func GetAllPages() ([]Page, error) {
	rows, err := DB.Query("SELECT id, name, grid_json FROM pages")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var pgs []Page
	for rows.Next() {
		var p Page
		if err := rows.Scan(&p.ID, &p.Name, &p.Grid); err != nil {
			continue
		}
		pgs = append(pgs, p)
	}
	return pgs, nil
}

func SavePage(p Page) error {
	query := `INSERT INTO pages (id, name, grid_json) 
	          VALUES (?, ?, ?) 
	          ON CONFLICT(id) DO UPDATE SET name=excluded.name, grid_json=excluded.grid_json`

	_, err := DB.Exec(query, p.ID, p.Name, p.Grid)
	return err
}

func DeletePage(id string) error {
	_, err := DB.Exec("DELETE FROM pages WHERE id = ?", id)
	return err
}

func GetAllDerivedParameters() ([]DerivedParameter, error) {
	rows, err := DB.Query("SELECT id, mnemonic, unit, expression FROM derived_parameters")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var dps []DerivedParameter
	for rows.Next() {
		var dp DerivedParameter
		if err := rows.Scan(&dp.ID, &dp.Mnemonic, &dp.Unit, &dp.Expression); err != nil {
			continue
		}
		dps = append(dps, dp)
	}
	return dps, nil
}

func SaveDerivedParameter(dp DerivedParameter) error {
	query := `INSERT INTO derived_parameters (id, mnemonic, unit, expression) 
	          VALUES (?, ?, ?, ?) 
	          ON CONFLICT(id) DO UPDATE SET mnemonic=excluded.mnemonic, unit=excluded.unit, expression=excluded.expression`

	_, err := DB.Exec(query, dp.ID, dp.Mnemonic, dp.Unit, dp.Expression)
	return err
}

func DeleteDerivedParameter(id string) error {
	_, err := DB.Exec("DELETE FROM derived_parameters WHERE id = ?", id)
	return err
}
