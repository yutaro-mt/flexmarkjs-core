const INLINE_STACK_TYPES = require('./consts/inlineStackTypes')
const INLINE_STACK_STATES = require('./consts/inlineStackStates')

class Util {
  /* Invalid Unicode code points to \ufffd */
  static replaceUnicodeCodePoint(num) {
    return num > 0x10ffff || num == 0x00 ? 0xfffd : num
  }

  static getDelimiterType(delimiterRun) {
    return delimiterRun[0] === '_' ? INLINE_STACK_TYPES.EmUnderscore : INLINE_STACK_TYPES.EmAsterisk
  }
  static pushInlineStack(stack, type, size) {
    stack.push({
      type,
      size: size,
      currentSize: size,
      state: INLINE_STACK_STATES.OPEN,
      unprocessedCloseSize: 0,
    })
  }
  static findStackFirstElementIndex(stack, func) {
    for (let i = stack.length - 1; i >= 0; i--) {
      if (func(stack[i], i)) {
        return i
      }
    }
    return -1
  }
  static interceptLinkOrImage(stack) {
    const pos = Util.findStackFirstElementIndex(stack, val => {
      return val.type === INLINE_STACK_TYPES.Link || val.type === INLINE_STACK_TYPES.Image
    })
    if (pos !== -1) {
      for (let i = pos + 1; i < stack.length; i++) {
        stack[i].state = INLINE_STACK_STATES.INTERCEPTED
      }
      return true
    }
    return false
  }
  static interceptAnotherDelimiterRun(stack, delim) {
    const type = Util.getDelimiterType(delim)
    const pos = Util.findStackFirstElementIndex(stack, val => {
      return val.type === type
    })
    if (pos !== -1) {
      for (let i = pos + 1; i < stack.length; i++) {
        stack[i].state = INLINE_STACK_STATES.INTERCEPTED
      }
      return true
    }
    return false
  }
  static closeEmphasis(stack, delim) {
    let tempStack = []
    let tempSize = delim.length
    const closeType = Util.getDelimiterType(delim)
    const beforeCurrentSize = stack[stack.length - 1].currentSize
    Util.findStackFirstElementIndex(stack, (val, i) => {
      if (val.type === INLINE_STACK_TYPES.Link || val.type === INLINE_STACK_TYPES.Image) {
        return true
      }
      if (val.type !== closeType) {
        tempStack.push(i)
        return false
      }
      //same type
      tempStack.map(v => {
        stack[v].state = INLINE_STACK_STATES.CLOSED
      })
      tempStack = []
      if (val.currentSize - tempSize < 0) {
        tempSize -= val.currentSize
        val.state = INLINE_STACK_STATES.CLOSED
        val.currentSize = 0
        return false
      }
      val.currentSize -= tempSize
      if (val.currentSize === 0) {
        val.state = INLINE_STACK_STATES.CLOSED
      } else {
        if (i != stack.length - 1) {
          val.unprocessedCloseSize = tempSize
        }
      }
      tempSize = 0
      return true
    })
    return beforeCurrentSize - stack[stack.length - 1].currentSize
  }
  static totalCurrentOpenSize(stack, c) {
    const type = Util.getDelimiterType(c)
    return stack.reduce((acc, val) => {
      return acc + (type === val.type ? val.currentSize : 0)
    }, 0)
  }
  static canCloseEmphasis(stack, delim) {
    return (
      stack[stack.length - 1].type === Util.getDelimiterType(delim) &&
      (stack[stack.length - 1].size + delim.length) % 3 !== 0
    )
  }
  static isInterceptedCurrentStack(stack) {
    return stack[stack.length - 1].state === INLINE_STACK_STATES.INTERCEPTED
  }
  static hasUnprocessedClose(stack) {
    return stack[stack.length - 1].unprocessedCloseSize > 0
  }
  static isClosedCurrentStack(stack) {
    return stack[stack.length - 1].state === INLINE_STACK_STATES.CLOSED
  }
  static popInlineStack(stack) {
    return stack.pop()
  }

  static buildLinkText(items) {
    const arr = items.reduce((acc, val) => {
      return acc.concat(val)
    }, [])
    return 
  }
  static buildImageDesc(desc) {
    return desc.reduce((acc, val) => {
      return acc.concat(val)
    }, [])
  }
  static normalizeLinkLabel(origin) {
    return (
      origin
      //unicode case fold
      //strip leading and trailing whitespace
      .trim()
      //collapse consecutive internal whitespace to a single space.
      .replace(/(\u0020|\u0009|\u000A|\u000B|\u000C|\u000D)+/, ' ')
    )
  }

  static pushBlockStack(stack, obj) {
    stack.push(obj)
  }
  static popBlockStack(stack) {
    stack.pop()
  }

  static pushListIndentStack(stack, size) {
    stack.push(size)
  }
  static changeListIndentStack(stack, size) {
    stack[stack.length - 1] = size
  }
  static popListIndentStack(stack) {
    stack.pop()
  }

  static popLinkStack(stack) {
    const hasNestedLink = stack[stack.length - 1].state === INLINE_STACK_STATES.INTERCEPTED
    if (!hasNestedLink) {
      const firstLinkIndex = stack.findIndex(v => {
        return v.type === INLINE_STACK_TYPES.Link
      })
      if (firstLinkIndex != -1 || firstLinkIndex != stack.length - 1) {
        for (let i = firstLinkIndex; i < stack.length; i++) {
          stack[i].state = INLINE_STACK_STATES.INTERCEPTED
        }
      }
    }
    Util.popInlineStack(stack)
    return !hasNestedLink
  }
}

module.exports = Util
