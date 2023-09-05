import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

class HelloLog {
  late Logger logger;
  File file;
  HelloLog(this.file);
  Logger buildLogger() {
    FileOutput fileOutPut = FileOutput(this.file);
    ConsoleOutput consoleOutput = ConsoleOutput();
    List<LogOutput> multiOutput = [fileOutPut, consoleOutput];
    logger = Logger(
        filter: DevelopmentFilter(),
        // Use the default LogFilter (-> only log in debug mode)
        printer: PrettyPrinter(
            methodCount: 2,
            // number of method calls to be displayed
            errorMethodCount: 8,
            // number of method calls if stacktrace is provided
            lineLength: 120,
            // width of the output
            colors: false,
            // Colorful log messages
            printEmojis: false,

            // Print an emoji for each log message
            printTime: true // Should each log print contain a timestamp
            ),
        // Use the PrettyPrinter to format and print log
        output: MultiOutput(
            multiOutput) // Use the default LogOutput (-> send everything to console)
        );
    return logger;
  }
}

class FileOutput extends LogOutput {
  File file;
  bool overrideExisting = false;
  Encoding encoding = utf8;

  FileOutput(this.file);

  late IOSink _sink;

  @override
  Future<void> init() async {
    _sink = file.openWrite(
      mode: overrideExisting ? FileMode.writeOnly : FileMode.writeOnlyAppend,
      encoding: encoding,
    );
  }

  @override
  void output(OutputEvent event) {
    _sink.writeAll(event.lines, '\n');
  }

  @override
  Future<void> destroy() async {
    await _sink.flush();
    await _sink.close();
  }
}
