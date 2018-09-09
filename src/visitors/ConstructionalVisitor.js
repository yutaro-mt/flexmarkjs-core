const parser = require('../../gen/parser')
const States = require('../states/States')
const VisitorBase = require('./VisitorBase')

class ConstructionalVisitor extends VisitorBase {
  constructor(renderer, callback = () => {}) {
    super(renderer)
    this.callback = callback

    this.def = {}
  }

  static renderChildren(node, visitor) {
    if (node.unParsedContent) {
      node.children = [
        parser.parse(node.text, {
          startRule: 'Inlines',
          visitor,
          states: new States(),
        }),
      ]
    }
    return Array.isArray(node.children) ?
      node.children.map(x => {
        const children = ConstructionalVisitor.renderChildren(x, visitor)
        return children ?
          x.renderer({
            node: x,
            children,
          }) :
          x.renderer({
            node: x,
          })
      }) :
      null
  }

  visitRoot({
    node
  }) {
    return this.renderer.root({
      node: {
        children: ConstructionalVisitor.renderChildren(node, this),
      },
    })
  }
  // Leaf blocks
  visitAtxHeading({
    node
  }) {
    super.visitAtxHeading({
      node,
    })
    node.unParsedContent = {
      text: node.text,
    }
    return node
  }
  visitSetextHeading({
    node
  }) {
    super.visitSetextHeading({
      node,
    })
    node.unParsedContent = {
      text: node.text,
    }
    return node
  }
  visitLinkReferenceDefinition({
    node
  }) {
    super.visitLinkReferenceDefinition({
      node,
    })
    if (!this.def[node.label.toLowerCase()]) {
      this.def[node.label.toLowerCase()] = {
        dest: node.dest,
        title: node.title,
      }
    }
    return node
  }
  visitParagraph({
    node
  }) {
    super.visitParagraph({
      node,
    })
    node.unParsedContent = {
      text: node.text,
    }
    return node
  }
}

module.exports = ConstructionalVisitor
