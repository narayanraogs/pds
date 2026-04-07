package config

import (
	"encoding/json"
	"log"
	"os"
	"os/user"
	"path/filepath"
	"strings"
)

type Config struct {
	SatelliteName     string   `json:"SatelliteName"`
	PortNo            int      `json:"PortNo"`
	DBPath            string   `json:"DBPath"`
	MnemonicCachePath string   `json:"MnemonicCachePath"`
	RibbonMnemonics   []string `json:"RibbonMnemonics"`
	TMServer          TMConfig `json:"TMServer"`
}

type TMConfig struct {
	IP      string `json:"IP"`
	PortNo  int    `json:"PortNo"`
	Path    string `json:"Path"`
	Timeout int    `json:"Timeout"`
}

func ExpandPath(path string) string {
	if strings.HasPrefix(path, "~/") {
		usr, _ := user.Current()
		return filepath.Join(usr.HomeDir, path[2:])
	}
	return path
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
