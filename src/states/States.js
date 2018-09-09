const PRECEDED_CHARACTER_TYPES = require('../consts/precededCharacterType')

class States {
  constructor() {
    // Block
    this.blockStack = []
    this.currentBlockStackPos = 0
    this.currentListItemSpacePos = 0
    this.listIndentStack = []
    this.currentListIndentPos = 0
    // Inline
    this.inlineStack = []
    this.precededCharacterType = PRECEDED_CHARACTER_TYPES.WHITESPACE_AND_LINEENDING
    this.maxCloseDelimiterRunSize = 0 // 0=unlimited
    this.tempCloseDelimiterRunSize = 0
  }
}

module.exports = States
