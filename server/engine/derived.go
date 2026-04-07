package engine

import (
	"fmt"
	"log"
	"pds/storage"
	"pds/tm"
	"regexp"
	"strconv"
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
}

// NewEngine initializes the evaluation engine
func NewEngine() *Engine {
	return &Engine{
		expressions:  make(map[string]DerivedParamInfo),
		latestValues: make(map[string]float64),
		deps:         make(map[string][]string),
	}
}

// Reload fetches active derived parameters and compiles them
func (e *Engine) Reload(params []storage.DerivedParameter) {
	e.mu.Lock()
	defer e.mu.Unlock()

	newMap := make(map[string]DerivedParamInfo)
	newDeps := make(map[string][]string)

	for _, p := range params {
		program, err := expr.Compile(p.Expression, expr.Env(make(map[string]interface{})))
		if err != nil {
			log.Printf("[ENGINE] Failed to compile derived param '%s': %v", p.Mnemonic, err)
			continue
		}
		
		newMap[p.Mnemonic] = DerivedParamInfo{
			Def:     p,
			Program: program,
		}
		
		// Map dependencies
		matches := identRegex.FindAllString(p.Expression, -1)
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

// Evaluate runs the active expressions given the latest parameter value update
func (e *Engine) Evaluate(param tm.ParameterValue) ([]tm.ParameterValue, error) {
	e.mu.Lock()
	
	val, err := strconv.ParseFloat(param.TM1Value, 64)
	if err != nil {
		e.mu.Unlock()
		// Not a numeric parameter, safely ignore evaluating math formulas
		return nil, nil
	}
	
	// Update telemetry cache
	e.latestValues[param.Mnemonic] = val
	
	// Quick dependency graph lookup!
	dependents, ok := e.deps[param.Mnemonic]
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

	return results, nil
}
