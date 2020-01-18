const SerialPort = require('serialport')
const Readline = require('@serialport/parser-readline')
const fs = require('fs')
const EventEmitter = require('events')
class MyEmitter extends EventEmitter {}

// Constants for events
const START = 'start'
const CHUNK_SUCCESS = 'chunkSuccess'
const CHUNK_FAILURE = 'chunkFailure'
const EOF = 'eof'

// Constants for serial port communication
const SERIAL_ERROR = 'error'
const SERIAL_DATA = 'data'

// Protocol constants
const PROTOCOL_OK = 'k'
const PROTOCOL_FAILURE = 'f'

// JSON config file for all connection related details
const CONFIG_FILE_NAME = '.sender_config.json'

// Application timeout values
const startTimeout = 2000
const byteTimeout = 0 // not needed, data transfer is stable w/o positive values
const chunkTimeout = 0 // not needed, since we wait for Arduino ack after every chunk anyways

// get a serial connection with default params
const connectSerial = (config, tty) => {
  const connection = new SerialPort(tty || config.tty, {
      baudRate: config.baudrate,
      databits: config.databits,
      parity: config.parity,
      stopbits: config.stopbits
  })
  
  // Open errors will be emitted as an error event
  connection.on(SERIAL_ERROR, (err) => {
    console.log('Error on read: ', err.message)
  })
  
  return connection
}

// establish a parser for data read from Arduino
const establishParser = (connection, emitter) => {
    const parser = new Readline()
    connection.pipe(parser)

    parser.on(SERIAL_DATA, (data) => {
      const response = data.toString().trim()
      if (response == PROTOCOL_OK) {
        emitter.emit(CHUNK_SUCCESS)
      } else if (response == PROTOCOL_FAILURE) {
        emitter.emit(CHUNK_FAILURE)
      } else {
        console.log('Arduino Response: ', response)
      }
    })
}

// write a single byte to the serial connection
const sendByte = (connection, char) => {
  connection.write(char, (err) => {
    if (err) {
      return console.log('Error on write: ', err.message)
    }
  })
}

// write a chunk of bytes to the serial connection including checksum
const sendChunk = (connection, data) => {
  let idx = 0

  // both methods are destructive
  data = appendPadding(data)
  data = appendChecksum(data)

  base64 = data.toString('base64')
  
  // let decimals = data.join('-')
  // console.log('Data: ', decimals)
  // console.log('Base64: ', base64)

  return new Promise((res) => {
    setTimeout(() => {
      const interval = setInterval(() => {
        if (idx == base64.length) { 
          clearInterval(interval)
          res()
        } else {
          sendByte(connection, base64[idx])
          idx += 1
        }
      }, byteTimeout)
    }, chunkTimeout)
  })
}

// simple 1-byte checksum algorithm
const checkSum = (data) => {
  let cs = 0
  data.forEach((element) => {
    bin = element.toString(2)
    cs = (cs << 1) + parseInt(bin[bin.length - 1])
  })

  return cs
}

// appends checksum to given buffer
const appendChecksum = (buf) => {
  return Buffer.concat([buf, Buffer.alloc(1, [checkSum(buf)])], 9)
}

// add 0x00 padding bytes to buffer of different length than 8 (potentially only the last)
// necessary, because otherwise the checksum will not be in the right place and
// the chunk will be requested forever
const appendPadding = (buf) => {
  if (buf.length == 8) {
    return buf
  } else {
    return Buffer.concat([buf, Buffer.alloc((8 - buf.length), 0)], 8)
  }
}

// reads a file from filesystem and async returns it as a buffer
const readFile = (fileName) => {
  return new Promise((res, rej) => {
    fs.readFile(fileName, (err, data) => {
      if (err) { rej('Error while reading file: ' + fileName) }
      res(data)
    })
  })
}

// cut the given array / buffer into chunks of given size
const inGroupsOf = (ary, size) => {
  let result = []
  for (let i = 0; i < ary.length; i += size) {
    let chunk = ary.slice(i, i + size)
    result.push(chunk)
  }

  return result
}

// simple index constructor function
const Index = (m) => {
  let idx = 0
  const max = m - 1

  const get = () => {
    return idx
  }

  const increase = () => {
    if (idx >= max) {
      return null
    } else {
      idx += 1

      return idx
    }
  }

  return {
    get,
    increase
  }
}

// registering all event handler functions
const establishEventHandlers = (connection, index, chunks) => {
  const myEmitter = new MyEmitter()

  myEmitter.on(START, (connection, chunk) => {
    sendFirstChunk(connection, chunk)
  })

  myEmitter.on(CHUNK_SUCCESS, () => {
    sendNextChunk(connection, index, chunks, myEmitter)
  })

  myEmitter.on(CHUNK_FAILURE, () => {
    repeatChunk(connection, index, chunks, myEmitter)
  })

  myEmitter.on(EOF, () => {
    quit(connection)
  })

  return myEmitter
}

// sends the very first chunk
const sendFirstChunk = (connection, chunk) => {
  console.log('Sending chunk: 0')
  sendChunk(connection, chunk)
}

// increases index and sends next chunk
// emits EOF event, when no chunk is left
const sendNextChunk = (connection, index, chunks, emitter) => {
  const idx = index.increase()

  if (idx) {
    console.log('Sending chunk: ', idx)
    sendChunk(connection, chunks[idx])
  } else {
    console.log('No chunk left!')
    emitter.emit(EOF)
  }
}

// gets current index and repeats the chunk sent before
const repeatChunk = (connection, index, chunks, emitter) => {
  const idx = index.get()

  if (idx) {
    console.log('Repeating chunk: ', idx)
    sendChunk(connection, chunks[idx])
  } else {
    emitter.emit(EOF)
  }
}

// gracefully quits the program
const quit = (connection) => {
  console.log('Data transferred successfully! Quitting.')

  connection.close()
  process.exit(0)
}

// main
(async () => {
  const inFileName = process.argv[2]
  const tty = process.argv[3]

  if (!inFileName) {
    console.log('No input file given!')
    process.exit(1)
  }

  try {
    console.log('Reading input file: ', inFileName)
    const inFile = await readFile(inFileName)
    console.log('Done.')
    const chunks = inGroupsOf(inFile, 8)
    
    console.log('Loading config file...')
    const config = JSON.parse(fs.readFileSync(CONFIG_FILE_NAME))

    console.log('Establishing connection...')
    const connection = connectSerial(config, tty)

    const index = Index(chunks.length)

    console.log('Establishing event handlers...')
    emitter = establishEventHandlers(connection, index, chunks)
    console.log('Done.')
  
    setTimeout(() => {
      console.log('Connected.')
      console.log('Establishing parser...')
      establishParser(connection, emitter)
      console.log('Ready to send data.')
      
      emitter.emit(START, connection, chunks[0])
    }, startTimeout)
  } catch(e) {
    console.log(e)
    process.exit(1)
  }
})()