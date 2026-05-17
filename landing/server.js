import express from 'express'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __dirname = dirname(fileURLToPath(import.meta.url))
const app = express()
const PORT = process.env.PORT || 3001

app.use(express.static(join(__dirname, 'dist')))
app.use('/downloads', express.static(join(__dirname, 'downloads')))
app.get('*', (_, res) => res.sendFile(join(__dirname, 'dist', 'index.html')))

app.listen(PORT, () => console.log(`Landing page running on port ${PORT}`))
