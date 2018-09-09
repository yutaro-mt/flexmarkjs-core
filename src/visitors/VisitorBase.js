class VisitorBase {
  constructor(renderer) {
    this.renderer = renderer
  }
  visitRoot() {}
  // Leaf blocks
  visitThematicBreak({ node }) {
    node.renderer = this.renderer.thematicBreak
    return node
  }
  visitAtxHeading({ node }) {
    node.renderer = this.renderer.atxHeading
    return node
  }
  visitSetextHeading({ node }) {
    node.renderer = this.renderer.setextHeading
    return node
  }
  visitIndentedCodeBlock({ node }) {
    node.renderer = this.renderer.indentedCodeBlock
    return node
  }
  visitFencedCodeBlock({ node }) {
    node.renderer = this.renderer.fencedCodeBlock
    return node
  }
  visitHTMLBlock({ node }) {
    node.renderer = this.renderer.htmlBlock
    return node
  }
  visitLinkReferenceDefinition({ node }) {
    node.renderer = this.renderer.linkReferenceDefinition
    return node
  }
  visitParagraph({ node }) {
    node.renderer = this.renderer.paragraph
    return node
  }
  visitBlankLine({ node }) {
    node.renderer = this.renderer.blankLine
    return node
  }
  //container blocks
  visitBlockQuote({ node }) {
    node.children.map(x => {
      x.parent = node
    })
    node.renderer = this.renderer.blockQuote
    return node
  }
  visitListItem({ node }) {
    node.children.map(x => {
      x.parent = node
    })
    node.renderer = this.renderer.listItem
    return node
  }
  visitList({ node }) {
    node.children.map(x => {
      x.parent = node
    })
    node.renderer = this.renderer.list
    return node
  }

  //inlines
  visitInlines(node) {
    node.renderer = this.renderer.inlines
    return node
  }
  visitBackslashEscape(node) {
    node.renderer = this.renderer.backslashEscape
    return node
  }
  visitEntityReference(node) {
    node.renderer = this.renderer.entityReference
    return node
  }
  visitNumericReference(node) {
    node.renderer = this.renderer.numericReference
    return node
  }
  visitCodeSpan(node) {
    node.renderer = this.renderer.codeSpan
    return node
  }
  visitEmphasis(node) {
    node.renderer = this.renderer.emphasis
    return node
  }
  visitStrongEmphasis(node) {
    node.renderer = this.renderer.strongEmphasis
    return node
  }
  visitInlineLink(node) {
    node.renderer = this.renderer.link
    return node
  }
  visitReferenceLink(node) {
    node.renderer = this.renderer.link
    return node
  }
  visitInlineImage(node) {
    node.renderer = this.renderer.image
    return node
  }
  visitReferenceImage(node) {
    node.renderer = this.renderer.image
    return node
  }
  visitAutolink(node) {
    node.renderer = this.renderer.autolink
    return node
  }
  visitRawHTML(node) {
    node.renderer = this.renderer.rawHTML
    return node
  }
  visitHardLineBreak(node) {
    node.renderer = this.renderer.hardLineBreak
    return node
  }
  visitSoftLineBreak(node) {
    node.renderer = this.renderer.softLineBreak
    return node
  }
  visitTextualContent(node) {
    node.renderer = this.renderer.textualContent
    return node
  }
}

module.exports = VisitorBase
