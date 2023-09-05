"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = exports.port = void 0;
var winston_1 = require("winston");
var combine = winston_1.format.combine, timestamp = winston_1.format.timestamp, printf = winston_1.format.printf;
exports.port = "9996";
exports.logger = (0, winston_1.createLogger)({
    level: 'info',
    format: combine(winston_1.format.splat(), timestamp(), printf(function (_a) {
        var level = _a.level, message = _a.message, timestamp = _a.timestamp;
        return "".concat(timestamp, " [").concat(level, "] ").concat(message);
    })),
    transports: [new winston_1.transports.Console()],
});
