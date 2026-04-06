package config

import (
	"encoding/json"
	"log"
	"os"
)

type Config struct {
	SatelliteName string   `json:"SatelliteName"`
	PortNo        int      `json:"PortNo"`
	DBPath        string   `json:"DBPath"`
	TMServer      TMConfig `json:"TMServer"`
}

type TMConfig struct {
	IP      string `json:"IP"`
	PortNo  int    `json:"PortNo"`
	Path    string `json:"Path"`
	Timeout int    `json:"Timeout"`
}

func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	log.Printf("[CONFIG] Successfully loaded settings for %s", cfg.SatelliteName)
	return &cfg, nil
}
