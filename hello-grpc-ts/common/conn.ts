import {createLogger, format, transports} from "winston";

const {combine, timestamp, printf} = format
export let port = "9996"

export const logger = createLogger({
    level: 'info',
    format: combine(
        format.splat(),
        timestamp(),
        printf(({level, message, timestamp}) => {
            return `${timestamp} [${level}] ${message}`
        })
    ),
    transports: [new transports.Console()],
})