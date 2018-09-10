const chokidar = require('chokidar')
const child_process = require('child_process')

var watcher = chokidar.watch(['src\\parser.pegjs'], {
  ignored: /(^|[/\\])\../,
  persistent: true
})

watcher.on('change', () => {
  child_process.exec('yarn run peg', error=>{
    if (error) {
      console.log('---------- error ----------')
      console.error(`exec error: ${error}`)
      console.log('---------------------------')
      return;
    }
    console.log('success '+ new Date().toISOString())
  })
})
