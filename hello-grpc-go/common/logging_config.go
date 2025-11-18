package common

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	log "github.com/sirupsen/logrus"
)

// LogConfig holds logging configuration
type LogConfig struct {
	Level      log.Level
	Component  string
	LogDir     string
	EnableFile bool
	logFile    *os.File
}

// StandardLogFormatter implements the standard log format
// Format: [TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]
type StandardLogFormatter struct {
	Component string
}

// Format renders a single log entry
func (f *StandardLogFormatter) Format(entry *log.Entry) ([]byte, error) {
	timestamp := entry.Time.Format("2006-01-02 15:04:05.000")
	level := entry.Level.String()
	component := f.Component
	message := entry.Message

	// Build context from fields
	context := ""
	if len(entry.Data) > 0 {
		context = " ["
		first := true
		for k, v := range entry.Data {
			if !first {
				context += ", "
			}
			context += fmt.Sprintf("%s=%v", k, v)
			first = false
		}
		context += "]"
	}

	logLine := fmt.Sprintf("[%s] [%s] [%s] %s%s\n",
		timestamp, level, component, message, context)

	return []byte(logLine), nil
}

// InitializeLogging sets up logging with standard format and dual output
func InitializeLogging(config LogConfig) error {
	// Set log level
	log.SetLevel(config.Level)

	// Set formatter
	log.SetFormatter(&StandardLogFormatter{
		Component: config.Component,
	})

	// Create log directory if file logging is enabled
	if config.EnableFile {
		if err := os.MkdirAll(config.LogDir, 0755); err != nil {
			return fmt.Errorf("failed to create log directory: %w", err)
		}

		// Create log file with timestamp
		timestamp := time.Now().Format("20060102_150405")
		logFileName := filepath.Join(config.LogDir, fmt.Sprintf("%s_%s.log", config.Component, timestamp))

		logFile, err := os.OpenFile(logFileName, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			return fmt.Errorf("failed to open log file: %w", err)
		}

		config.logFile = logFile

		// Set dual output (console and file)
		multiWriter := io.MultiWriter(os.Stdout, logFile)
		log.SetOutput(multiWriter)

		log.WithField("log_file", logFileName).Info("Logging initialized")
	} else {
		// Console only
		log.SetOutput(os.Stdout)
		log.Info("Logging initialized (console only)")
	}

	return nil
}

// CloseLogging closes the log file if open
func CloseLogging(config *LogConfig) {
	if config.logFile != nil {
		config.logFile.Close()
		config.logFile = nil
	}
}

// GetDefaultLogConfig returns default logging configuration
func GetDefaultLogConfig(component string) LogConfig {
	return LogConfig{
		Level:      log.InfoLevel,
		Component:  component,
		LogDir:     "logs",
		EnableFile: true,
	}
}
