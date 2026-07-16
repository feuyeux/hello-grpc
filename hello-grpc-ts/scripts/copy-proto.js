const fs = require('fs')
const path = require('path')

const sourceDir = path.resolve(__dirname, '../src/proto')
const outputDir = path.resolve(__dirname, '../dist/proto')

fs.mkdirSync(outputDir, { recursive: true })
for (const name of fs.readdirSync(sourceDir)) {
    if (name.endsWith('.js')) {
        fs.copyFileSync(path.join(sourceDir, name), path.join(outputDir, name))
    }
}
