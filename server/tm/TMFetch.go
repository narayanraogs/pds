package tm

import (
	"pds/config"
)

var tm1ChanMap = make(chan Parameter, 1000)
var tm2ChanMap = make(chan Parameter, 1000)

func GetData(conf *config.Config, updatedParameter chan<- ParameterValue) {
	go subscribeToAllMnemonics(conf, "TM1", tm1ChanMap)
	go subscribeToAllMnemonics(conf, "TM2", tm2ChanMap)

	for {
		select {
		case p := <-tm1ChanMap:
			if param, ok := UpdateParamValue(p.Param, p.StringV, "", p.TMCount, true); ok {
				updatedParameter <- *param
			}
		case p := <-tm2ChanMap:
			if param, ok := UpdateParamValue(p.Param, "", p.StringV, p.TMCount, false); ok {
				updatedParameter <- *param
			}
		}
	}
}

func GetAllMnemonics(conf *config.Config) []string {
	_, err := getParamCache(conf)
	if err != nil {
		return nil
	}
	return parameterMnemonics
}
