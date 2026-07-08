import http from 'http'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const port = Number(process.env.PORT) || 3099
const rootDir = path.dirname(fileURLToPath(import.meta.url))
const publicDir = path.join(rootDir, 'public')

function safePublicPath(requested) {
  const normalized = path.normalize(requested).replace(/^(\.\.(\/|\\|$))+/, '')
  const full = path.join(publicDir, normalized)
  const relative = path.relative(publicDir, full)
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    return null
  }
  return full
}

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
  const target = safePublicPath(fileParam)
  if (!target) {
    res.statusCode = 400
    res.end('invalid path')
    return
  }
  fs.readFile(target, 'utf8', (err, data) => {
    if (err) {
      res.statusCode = 404
      res.end('not found')
      return
    }
    res.setHeader('Content-Type', 'text/plain; charset=utf-8')
    res.end(data)
  })
})

server.listen(port, () => {
  process.stdout.write(`listening on ${port}\n`)
})
