import http from 'http'
import fs from 'fs'
import { fileURLToPath } from 'url'
import path from 'path'

const port = 3099
const rootDir = path.dirname(fileURLToPath(import.meta.url))

const server = http.createServer((req, res) => {
  if (!req.url?.startsWith('/read')) {
    res.statusCode = 404
    res.end('not found')
    return
  }
  const url = new URL(req.url, `http://127.0.0.1:${port}`)
  const fileParam = url.searchParams.get('file')
  if (!fileParam) {
    res.statusCode = 400
    res.end('missing file')
    return
  }
  const target = path.join(rootDir, fileParam)
  fs.readFile(target, 'utf8', (err, data) => {
    if (err) {
      res.statusCode = 404
      res.end('not found')
      return
    }
    res.end(data)
  })
})

server.listen(port)
