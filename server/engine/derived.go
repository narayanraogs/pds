package engine

import (
	"encoding/json"
	"fmt"
	"log"
	"pds/storage"
	"pds/tm"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"

	"github.com/expr-lang/expr"
	"github.com/expr-lang/expr/vm"
)

var identRegex = regexp.MustCompile(`[a-zA-Z_][a-zA-Z0-9_]*`)

type DerivedParamInfo struct {
	Def     storage.DerivedParameter
	Program *vm.Program
}

type Engine struct {
	mu           sync.RWMutex
	expressions  map[string]DerivedParamInfo
	latestValues map[string]float64
	
	// Dependency graph: Raw Mnemonic -> list of Derived Mnemonics
	deps map[string][]string

	// Diagram Rules: DiagramID -> ElementID -> []StyleRule
	diagramRules map[string]map[string][]StyleRuleInfo
}

type StyleRuleInfo struct {
	Expression string
	Color      string
	Program    *vm.Program
}

// PreprocessExpression safely escapes ambiguous characters (like hyphens) in expressions mathematically
func PreprocessExpression(exp string) string {
	var allMnemonics []string
	for _, v := range tm.GetAllParameterInfo() {
		if strings.Contains(v.Mnemonic, "-") || strings.Contains(v.Mnemonic, ".") {
			allMnemonics = append(allMnemonics, v.Mnemonic)
		}
	}
	
	if dps, err := storage.GetAllDerivedParameters(); err == nil {
		for _, d := range dps {
			if strings.Contains(d.Mnemonic, "-") || strings.Contains(d.Mnemonic, ".") {
				allMnemonics = append(allMnemonics, d.Mnemonic)
			}
		}
	}

	// Sort dynamically by length decscending to ensure "SSR-1-2" resolves before "SSR-1"
	sort.Slice(allMnemonics, func(i, j int) bool {
		return len(allMnemonics[i]) > len(allMnemonics[j])
	})

	for _, m := range allMnemonics {
		if strings.Contains(exp, m) {
			safeM := strings.ReplaceAll(m, "-", "_")
			safeM = strings.ReplaceAll(safeM, ".", "_")
			exp = strings.ReplaceAll(exp, m, safeM)
		}
	}
	return exp
}

// GetCompileEnv creates a robust compilation environment with all valid mnemonics pre-loaded
func GetCompileEnv() map[string]interface{} {
	env := make(map[string]interface{})
	
	for _, v := range tm.GetAllParameterInfo() {
		safeM := strings.ReplaceAll(v.Mnemonic, "-", "_")
		safeM = strings.ReplaceAll(safeM, ".", "_")
		env[safeM] = 0.0
	}
	
	if dps, err := storage.GetAllDerivedParameters(); err == nil {
		for _, d := range dps {
			safeM := strings.ReplaceAll(d.Mnemonic, "-", "_")
			safeM = strings.ReplaceAll(safeM, ".", "_")
			env[safeM] = 0.0
		}
	}
	
	return env
}

// NewEngine initializes the evaluation engine
func NewEngine() *Engine {
	return &Engine{
		expressions:  make(map[string]DerivedParamInfo),
		latestValues: make(map[string]float64),
		deps:         make(map[string][]string),
		diagramRules: make(map[string]map[string][]StyleRuleInfo),
	}
}

// Reload fetches active derived parameters and compiles them
func (e *Engine) Reload(params []storage.DerivedParameter) {
	e.mu.Lock()
	defer e.mu.Unlock()

	newMap := make(map[string]DerivedParamInfo)
	newDeps := make(map[string][]string)

	env := GetCompileEnv()

	for _, p := range params {
		safeExp := PreprocessExpression(p.Expression)
		program, err := expr.Compile(safeExp, expr.Env(env))
		if err != nil {
			log.Printf("[ENGINE] Failed to compile derived param '%s': %v", p.Mnemonic, err)
			continue
		}
		
		newMap[p.Mnemonic] = DerivedParamInfo{
			Def:     p,
			Program: program,
		}
		
		// Map dependencies against the safe string
		matches := identRegex.FindAllString(safeExp, -1)
		seen := make(map[string]bool)
		
		for _, match := range matches {
			if !seen[match] {
				newDeps[match] = append(newDeps[match], p.Mnemonic)
				seen[match] = true
			}
		}

		log.Printf("[ENGINE] Compiled Derived Param: %s (Depends on: %v)", p.Mnemonic, getKeys(seen))
	}

	e.expressions = newMap
	e.deps = newDeps
}

func getKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// DiagramJSON represents the nested data structure from storage.Diagram.DataJson
type DiagramJSON struct {
	Blocks []struct {
		ID    string `json:"id"`
		Rules []struct {
			Exp   string `json:"exp"`
			Color string `json:"color"`
		} `json:"rules"`
	} `json:"blocks"`
	Connections []struct {
		ID    string `json:"id"`
		Rules []struct {
			Exp   string `json:"exp"`
			Color string `json:"color"`
		} `json:"rules"`
	} `json:"connections"`
}

// ReloadDiagrams compiles rules from all saved diagrams
func (e *Engine) ReloadDiagrams(diagrams []storage.Diagram) {
	e.mu.Lock()
	defer e.mu.Unlock()

	env := GetCompileEnv()
	newDiagramRules := make(map[string]map[string][]StyleRuleInfo)

	for _, d := range diagrams {
		var dj DiagramJSON
		if err := json.Unmarshal([]byte(d.DataJson), &dj); err != nil {
			log.Printf("[ENGINE] Failed to parse diagram data for %s: %v", d.Name, err)
			continue
		}

		elementMap := make(map[string][]StyleRuleInfo)
		// 1. Process Blocks
		for _, b := range dj.Blocks {
			var rules []StyleRuleInfo
			for _, r := range b.Rules {
				safeExp := PreprocessExpression(r.Exp)
				program, err := expr.Compile(safeExp, expr.Env(env))
				if err != nil {
					log.Printf("[ENGINE] Regected Diagram Rule for %s/BLOCK:%s: %v", d.Name, b.ID, err)
					continue
				}
				rules = append(rules, StyleRuleInfo{
					Expression: r.Exp,
					Color:      r.Color,
					Program:    program,
				})
			}
			elementMap["BLOCK:"+b.ID] = rules
		}
		// 2. Process Connections
		for _, c := range dj.Connections {
			var rules []StyleRuleInfo
			for _, r := range c.Rules {
				safeExp := PreprocessExpression(r.Exp)
				program, err := expr.Compile(safeExp, expr.Env(env))
				if err != nil {
					log.Printf("[ENGINE] Regected Diagram Rule for %s/CONN:%s: %v", d.Name, c.ID, err)
					continue
				}
				rules = append(rules, StyleRuleInfo{
					Expression: r.Exp,
					Color:      r.Color,
					Program:    program,
				})
			}
			elementMap["CONN:"+c.ID] = rules
		}
		newDiagramRules[d.ID] = elementMap
	}
	e.diagramRules = newDiagramRules
	log.Printf("[ENGINE] Reloaded rules for %d diagrams", len(diagrams))
}

// Evaluate runs the active expressions given the latest parameter value update
func (e *Engine) Evaluate(param tm.ParameterValue) ([]tm.ParameterValue, error) {
	e.mu.Lock()
	
	val, err := strconv.ParseFloat(param.TM1Value, 64)
	if err != nil {
		e.mu.Unlock()
		// Not a numeric parameter, safely ignore evaluating math formulas
		return nil, nil
	}
	
	safeParamMnem := strings.ReplaceAll(param.Mnemonic, "-", "_")
	safeParamMnem = strings.ReplaceAll(safeParamMnem, ".", "_")
	
	// Update telemetry cache mapped to the safe variant
	e.latestValues[safeParamMnem] = val
	
	// Quick dependency graph lookup!
	dependents, ok := e.deps[safeParamMnem]
	if !ok || len(dependents) == 0 {
		e.mu.Unlock()
		// None of the derived parameters depend on this parameter! Fast exit in O(1)
		return nil, nil 
	}
	
	// Build evaluation context
	env := make(map[string]interface{}, len(e.latestValues))
	for k, v := range e.latestValues {
		env[k] = v
	}
	e.mu.Unlock()

	var results []tm.ParameterValue

	// Execute ONLY the derived parameters that depend on this updated variable
	e.mu.RLock()
	defer e.mu.RUnlock()

	for _, reqName := range dependents {
		info, exists := e.expressions[reqName]
		if !exists {
			continue 
		}
		
		output, err := expr.Run(info.Program, env)
		if err != nil {
			continue // Might be missing a secondary variable, ignore.
		}

		var resultStr string
		switch v := output.(type) {
		case float64:
			resultStr = fmt.Sprintf("%.4f", v)
		case int:
			resultStr = strconv.Itoa(v)
		case bool:
			resultStr = fmt.Sprintf("%t", v)
		default:
			resultStr = fmt.Sprintf("%v", v)
		}

		results = append(results, tm.ParameterValue{
			Mnemonic:   info.Def.Mnemonic,
			Units:      info.Def.Unit,
			TM1Value:   resultStr,
			UpperLimit: 0,
			LowerLimit: 0,
			Tolerance:  0,
		})
	}

	// ── DIAGRAM RULE EVALUATION ───────────────────────────────────────────
	e.mu.RLock()
	defer e.mu.RUnlock()

	for diagID, elements := range e.diagramRules {
		for elementKey, rules := range elements {
			for _, r := range rules {
				output, err := expr.Run(r.Program, env)
				if err == nil {
					if active, ok := output.(bool); ok && active {
						// This rule triggered!
						results = append(results, tm.ParameterValue{
							Mnemonic: fmt.Sprintf("DIAG:%s:%s:COLOR", diagID, elementKey),
							TM1Value: r.Color,
						})
						break 
					}
				}
			}
		}
	}

	return results, nil
}
