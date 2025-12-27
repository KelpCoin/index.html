const fs = require('fs');
const path = require('path');

class Logger {
  constructor(logFile = path.join(process.cwd(), 'logs', 'app.log')) {
    this.logFile = logFile;
    fs.mkdirSync(path.dirname(logFile), { recursive: true });
  }

  info(message) {
    this.write('INFO', message);
  }

  warn(message) {
    this.write('WARN', message);
  }

  error(message) {
    this.write('ERROR', message);
  }

  write(level, message) {
    const entry = `${new Date().toISOString()} ${level} ${message}`;
    console.log(entry);
    fs.appendFileSync(this.logFile, entry + '\n');
  }
}

module.exports = Logger;
