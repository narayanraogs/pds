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

type Diagram struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	DataJson  string `json:"data_json"` // JSON encoded blocks, ports, and connections
}

type CriticalParameter struct {
	ID                 string  `json:"id"`
	Mnemonic           string  `json:"mnemonic"`
	LowerLimit         float64 `json:"lower_limit"`
	UpperLimit         float64 `json:"upper_limit"`
	MaxChangeThreshold float64 `json:"max_change_threshold"`
	IsActive           bool    `json:"is_active"`
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

	queryDiagrams := `
	CREATE TABLE IF NOT EXISTS diagrams (
		id TEXT PRIMARY KEY,
		name TEXT,
		data_json TEXT
	);`

	if _, err := DB.Exec(queryDiagrams); err != nil {
		return err
	}

	queryCritical := `
	CREATE TABLE IF NOT EXISTS critical_parameters (
		id TEXT PRIMARY KEY,
		mnemonic TEXT UNIQUE,
		lower_limit REAL,
		upper_limit REAL,
		max_change_threshold REAL DEFAULT 0.0,
		is_active INTEGER DEFAULT 1
	);`

	if _, err := DB.Exec(queryCritical); err != nil {
		return err
	}

	// Schema migration for existing DB files
	DB.Exec("ALTER TABLE critical_parameters ADD COLUMN is_active INTEGER DEFAULT 1;")
	DB.Exec("ALTER TABLE critical_parameters ADD COLUMN max_change_threshold REAL DEFAULT 0.0;")

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

func GetAllDiagrams() ([]Diagram, error) {
	rows, err := DB.Query("SELECT id, name, data_json FROM diagrams")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var dgs []Diagram
	for rows.Next() {
		var d Diagram
		if err := rows.Scan(&d.ID, &d.Name, &d.DataJson); err != nil {
			continue
		}
		dgs = append(dgs, d)
	}
	return dgs, nil
}

func SaveDiagram(d Diagram) error {
	query := `INSERT INTO diagrams (id, name, data_json) 
	          VALUES (?, ?, ?) 
	          ON CONFLICT(id) DO UPDATE SET name=excluded.name, data_json=excluded.data_json`

	_, err := DB.Exec(query, d.ID, d.Name, d.DataJson)
	return err
}

func DeleteDiagram(id string) error {
	_, err := DB.Exec("DELETE FROM diagrams WHERE id = ?", id)
	return err
}

func GetAllCriticalParameters() ([]CriticalParameter, error) {
	rows, err := DB.Query("SELECT id, mnemonic, lower_limit, upper_limit, COALESCE(max_change_threshold, 0.0), COALESCE(is_active, 1) FROM critical_parameters")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cps []CriticalParameter
	for rows.Next() {
		var cp CriticalParameter
		var activeInt int
		if err := rows.Scan(&cp.ID, &cp.Mnemonic, &cp.LowerLimit, &cp.UpperLimit, &cp.MaxChangeThreshold, &activeInt); err != nil {
			continue
		}
		cp.IsActive = (activeInt != 0)
		cps = append(cps, cp)
	}
	return cps, nil
}

func SaveCriticalParameter(cp CriticalParameter) error {
	activeInt := 0
	if cp.IsActive {
		activeInt = 1
	}
	query := `INSERT INTO critical_parameters (id, mnemonic, lower_limit, upper_limit, max_change_threshold, is_active) 
	          VALUES (?, ?, ?, ?, ?, ?) 
	          ON CONFLICT(id) DO UPDATE SET mnemonic=excluded.mnemonic, lower_limit=excluded.lower_limit, upper_limit=excluded.upper_limit, max_change_threshold=excluded.max_change_threshold, is_active=excluded.is_active`

	_, err := DB.Exec(query, cp.ID, cp.Mnemonic, cp.LowerLimit, cp.UpperLimit, cp.MaxChangeThreshold, activeInt)
	return err
}

func DeleteCriticalParameter(id string) error {
	_, err := DB.Exec("DELETE FROM critical_parameters WHERE id = ?", id)
	return err
}
