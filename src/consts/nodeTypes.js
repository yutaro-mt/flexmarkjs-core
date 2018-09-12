const NODE_TYPES = {
  // blocks
  ThematicBreak: 1,
  ATXHeading: 2,
  SetextHeading: 3,
  IndentedCodeBlock: 4,
  FencedCodeBlock: 5,
  HTMLBlock: 6,
  LinkReferenceDefinition: 7,
  Paragraph: 8,
  BlankLine: 9,
  BlockQuote: 10,
  ListItem: 11,
  List: 12,
  // inlines
  BackslashEscape: 101,
  EntityCharacterReference: 102,
  NumericCharacterReference: 103,
  CodeSpan: 104,
  Emphasis: 105,
  StrongEmphasis: 106,
  Link: 107,
  Image: 108,
  Autolink: 109,
  RawHTML: 110,
  HardLineBreak: 111,
  SoftLineBreak: 112,
  TextualContent: 113,
  Text:114,
}

module.exports = NODE_TYPES
