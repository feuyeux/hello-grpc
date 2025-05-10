package log

import (
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/google/uuid"
	log "github.com/sirupsen/logrus"
)

func init() {
	// Set log format
	log.SetFormatter(&log.TextFormatter{
		TimestampFormat: "15:04:05.000",
		ForceColors:     true,
		FullTimestamp:   true,
		DisableQuote:    true,
		ForceQuote:      false,
	})

	// Set log level
	log.SetLevel(log.InfoLevel)

	// Ensure log directory exists
	os.MkdirAll("log", os.ModePerm)

	// Set file output
	file, err := os.OpenFile("log/hello-grpc.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err == nil {
		log.SetOutput(io.MultiWriter(os.Stdout, file))
	}
}

// DInfo dev info
func DInfo(msg string) string {
	id := uuid.New().String()
	log.Infof("%s", msg)
	return id
}

// TInfo dev tracing info
func TInfo(id, msg string) {
	log.Infof("%s", msg)
}

func DInfof(format string, args ...interface{}) {
	log.Infof(format, args...)
}

// Info standard log method
func Info(msg string) {
	log.Info(msg)
}

// Infof standard formatted log method
func Infof(format string, args ...interface{}) {
	log.Infof(format, args...)
}

// Error standard error log method
func Error(msg string) {
	log.Error(msg)
}

// Errorf standard formatted error log method
func Errorf(format string, args ...interface{}) {
	log.Errorf(format, args...)
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
