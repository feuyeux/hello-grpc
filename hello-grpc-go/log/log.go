package log

import (
	"fmt"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"
)

// DInfo dev info
func DInfo(msg string) string {
	id := uuid.New().String()
	filename, line, funcName, funcName1, funcName2 := buildLogParams()
	log.Infof("[%s] %s[%d]:%s<-%s<-%s: %s\n", id, filename, line, funcName, funcName1, funcName2, msg)
	return id
}

// TInfo dev tracing info
func TInfo(id, msg string) {
	filename, line, funcName, funcName1, funcName2 := buildLogParams()
	log.Infof("[%s] %s[%d]:%s<-%s<-%s: %s\n", id, filename, line, funcName, funcName1, funcName2, msg)
}

func DInfof(format string, args ...interface{}) {
	filename, line, funcName, funcName1, funcName2 := buildLogParams()
	log.Infof("%s[%d]:%s<-%s<-%s: %s\n", filename, line, funcName, funcName1, funcName2, fmt.Sprintf(format, args...))
}

func buildLogParams() (string, int, string, string, string) {
	return buildLogParams0(3)
}

func buildLogParams0(skip int) (string, int, string, string, string) {
	funcName, funcName1, funcName2, line, filename := "???", "???", "???", 0, "???"
	pc, filename, line, ok := runtime.Caller(skip)
	if ok {
		funcName = runtime.FuncForPC(pc).Name()
		funcName = filepath.Ext(funcName)
		funcName = strings.TrimPrefix(funcName, ".")
		filename = filepath.Base(filename)
	}
	pc1, _, _, ok := runtime.Caller(skip + 1)
	if ok {
		funcName1 = runtime.FuncForPC(pc1).Name()
		funcName1 = filepath.Ext(funcName1)
		funcName1 = strings.TrimPrefix(funcName1, ".")
	}
	pc2, _, _, ok := runtime.Caller(skip + 2)
	if ok {
		funcName2 = runtime.FuncForPC(pc2).Name()
		funcName2 = filepath.Ext(funcName2)
		funcName2 = strings.TrimPrefix(funcName2, ".")
	}
	return filename, line, funcName, funcName1, funcName2
}
