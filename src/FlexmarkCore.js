const parser = require('../gen/parser')
const ConstructionalVisitor = require('./visitors/ConstructionalVisitor')
const States = require('./states/States')

class FlexmarkCore {
  constructor(options) {
    options = options || {}
    this.renderer = options.renderer ? options.renderer : null
    this.visitor = options.visitor ? options.visitor : new ConstructionalVisitor(this.renderer)
    this.states = options.states ? options.states : new States()
    this.mode = options.mode ? options.mode : 'gfm'
  }
  parse(text) {
    return parser.parse(text, {
      startRule: 'Root',
      visitor: this.visitor,
      states: this.states,
      mode: this.mode,
    })
  }
}

module.exports = FlexmarkCore
