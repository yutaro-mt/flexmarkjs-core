{
  const Pc = require("../src/resources/unicode/Pc");
  const Pd = require("../src/resources/unicode/Pd");
  const Pe = require("../src/resources/unicode/Pe");
  const Pf = require("../src/resources/unicode/Pf");
  const Pi = require("../src/resources/unicode/Pi");
  const Po = require("../src/resources/unicode/Po");
  const Ps = require("../src/resources/unicode/Ps");
  const Zs = require("../src/resources/unicode/Zs");
  const entities = require("../src/resources/entities");
  const NODE_TYPES = require("../src/consts/nodeTypes");
  const LIST_TYPES = require("../src/consts/listTypes");
  const INLINE_STACK_TYPES = require("../src/consts/inlineStackTypes");
  const INLINE_STACK_STATES = require("../src/consts/inlineStackStates");
  const AUTOLINK_TYPE = require("../src/consts/autolinkTypes");
  const PRECEDED_CHARACTER_TYPES = require("../src/consts/precededCharacterType");
  const Util = require("../src/util");

  const visitor = options.visitor;
  const states = options.states;
  const mode = options.mode;
  const blockStack = (states&&states.blockStack) ? states.blockStack : [];
  const inlineStack = (states&&states.inlineStack) ? states.inlineStack : [];

  function buildEmphasis(open, blocks){
    let rem = open.length;
    const emphasis = blocks.reduce((acc, val)=>{
      let current = acc.concat(val.items);
      for(let i=val.closeSize; i>0; ){
        if(i>1){
          current = [
            visitor.visitStrongEmphasis(
              {
                type: NODE_TYPES.StrongEmphasis,
                content: '',
                text: open[0]+open[0]+current.map(x=>x.text).join('')+
                      open[0]+open[0],
                children: current,
              }
            )
          ];
          i-=2;
          rem-=2;
        }else{
          current = [
            visitor.visitEmphasis(
              {
                type: NODE_TYPES.Emphasis,
                content: '',
                text: open[0]+current.map(x=>x.text).join('')+open[0],
                children: current,
              }
            )
          ];
          i--;
          rem--;
        }
      }
      return current;
    },[]);
    let texts = [];
    for(let i=0;i<rem;i++){
      texts.push(
        visitor.visitTextualContent({
          type: NODE_TYPES.TextualContent,
          text: open[0],
        })
      );
    }
    return texts.concat(emphasis);
  }
}

// ###############################################
// Root
// ###############################################
Root
  = blocks:Block*
  {
    return visitor.visitRoot({ node: { children: blocks, } });
  }

Block
  = ThematicBreak / ATXHeading / IndentedCodeBlock / FencedCodeBlock /
    HTMLBlock / LinkReferenceDefinition / 
    List / BlockQuote / BlankLine / Paragraph

// ###############################################
// LeafBlocks
// ###############################################
// -------------------- ThematicBreak
ThematicBreak
  = OptionalThreeSpaces
    ( "-" space* "-" space* ("-" space*)+
    / "_" space* "_" space* ("_" space*)+
    / "*" space* "*" space* ("*" space*)+ )
    ( lineEnding / !. )
    { 
      return visitor.visitThematicBreak({
        node:{ type: NODE_TYPES.ThematicBreak, }
      });
    }

// -------------------- ATXHeading
ATXHeading
  = OptionalThreeSpaces
    sharps:"#"+
    &{ return sharps.length<7 }
    content:(
      space+
      str:( ("#"+ &(space* lineEnding) {return ''})
          / text:( !(( space+ "#"+ )? space* lineEnding)
                   any:.
                   {return any} )*
            ( space+ "#"+ )? {return text.join('');}
      )
      space*
      {return str;}
    )?
    ( lineEnding / !. )
    {
      return visitor.visitAtxHeading({
        node:{
          type: NODE_TYPES.ATXHeading,
          level: sharps.length,
          text: content ? content: '',
        }
      });
    }

// -------------------- IndentedCodeBlock
IndentedCodeBlock
  = first:IndentedChunk
    follow:(
      blank:(PartialPrependingMarkers bl:ICBBlankLine {return bl})+
      chank:(PrependingMarkers line:IndentedChunk {return line.join('')})
      {return blank.join('')+chank}
    )*
    {
      return visitor.visitIndentedCodeBlock({
        node:{
          type: NODE_TYPES.IndentedCodeBlock,
          text: first.join('')+follow.join('') }
      });
    }
IndentedChunk
  = head:IndentedChankLine
    follow:(PrependingMarkers line:IndentedChankLine {return line})*
    {return [head].concat(follow)}
ICBBlankLine
  = bl:blankLine { return (bl.length>5 ? ' '.repeat(bl.length-5) : '')+'\n' }
IndentedChankLine
  = !blankLine
    ind:(sp:MoreThanFourSpaces {return (sp.length>4 ? ' '.repeat(sp.length-4) : '');})
    content:(!lineEnding any:. {return any})+
    le:lineEnding
    {return (ind+content.join('')+le)}

// -------------------- FencedCodeBlock
FencedCodeBlock
  = indents:OptionalThreeSpaces
    start:CodeFence space* infostr:InfoString space* lineEnding
    content:(
      PrependingMarkers
      !( OptionalThreeSpaces 
         flag:CodeFence
         !{return (start.length>flag.length)||(start[0]!==flag[0])}
         space*
         lineEnding
       )
      sp:(s:space* {
        return ( indents.length>0 ?
        (s.length > indents.length ? ' '.repeat(s.length-indents.length) : '') :
        s.join('') )
      })
      line:FencedCodeBlockLine
      {return sp+line;}
    / BQPartialPrependingMarkers
      sp:(s:space* {
        return ( indents.length>0 ?
        (s.length > indents.length ? ' '.repeat(s.length-indents.length) : '') :
        s.join('') )
      })
      lineEnding
      {return sp+'\n';}
    )*
    ( PrependingMarkers
      OptionalThreeSpaces
      end:CodeFence !{return (start.length>end.length)||(start[0]!==end[0])}
      space* lineEnding
    )?
    {
      return visitor.visitFencedCodeBlock({
        node:{
          type: NODE_TYPES.FencedCodeBlock,
          infoString: infostr,
          text: content.join('') }
      });
    }
CodeFence
  = fence:( "``" $"`"+ / "~~" $"~"+ )
    {return fence.join('');}
InfoString
  = str:(!(space* lineEnding / "`" / "~") any:. {return any})*  {return str.join('');}
FencedCodeBlockLine
  = line:(!lineEnding any:. {return any})* le:lineEnding {return line.join('')+le;}
// -------------------- HTMLBlock
HTMLBlock
  = content:( HTMLBlockInterpretation / HTMLBlock7 )
    {
      return visitor.visitHTMLBlock({
        node:{
          type: NODE_TYPES.HTMLBlock,
          text: content.join('')
        }
      });
    }
HTMLBlockInterpretation
  = HTMLBlock1 / HTMLBlock2 / HTMLBlock3 / HTMLBlock4 / HTMLBlock5 / HTMLBlock6

HTMLBlock1
  = sps:$OptionalThreeSpaces start:$HTMLBStart1
    lines:(!HTMLBEnd1 c:(le:lineEnding PrependingMarkers {return le} / !lineEnding c:. {return c}) {return c})*
    end:$HTMLBEnd1
    follow:$(!(lineEnding / documentEnding) .)*
    le:$(lineEnding / documentEnding)
    {return [sps,start,lines.join(''),end,follow,le]}
HTMLBlock2
  = sps:$OptionalThreeSpaces start:$HTMLBStart2
    lines:(!HTMLBEnd2 c:(le:lineEnding PrependingMarkers {return le} / !lineEnding c:. {return c}) {return c})*
    end:$HTMLBEnd2
    follow:$(!(lineEnding/documentEnding) .)*
    le:$(lineEnding/documentEnding)
    {return [sps,start,lines.join(''),end,follow,le]}
HTMLBlock3
  = sps:$OptionalThreeSpaces start:$HTMLBStart3
    lines:(!HTMLBEnd3 c:(le:lineEnding PrependingMarkers {return le} / !lineEnding c:. {return c}) {return c})*
    end:$HTMLBEnd3
    follow:$(!(lineEnding/documentEnding) .)*
    le:$(lineEnding/documentEnding)
    {return [sps,start,lines.join(''),end,follow,le]}
HTMLBlock4
  = sps:$OptionalThreeSpaces start:$HTMLBStart4
    lines:(!HTMLBEnd4 c:(le:lineEnding PrependingMarkers {return le} / !lineEnding c:. {return c}) {return c})*
    end:$HTMLBEnd4
    follow:$(!(lineEnding/documentEnding) .)*
    le:$(lineEnding/documentEnding)
    {return [sps,start,lines.join(''),end,follow,le]}
HTMLBlock5
  = sps:$OptionalThreeSpaces start:$HTMLBStart5
    lines:(!HTMLBEnd5 c:(le:lineEnding PrependingMarkers {return le} / !lineEnding c:. {return c}) {return c})*
    end:$HTMLBEnd5
    follow:$(!(lineEnding/documentEnding) .)*
    le:$(lineEnding/documentEnding)
    {return [sps,start,lines.join(''),end,follow,le]}
HTMLBlock6
  = sps:$OptionalThreeSpaces start:$HTMLBStart6
    lines:(!HTMLBEnd6 c:(le:lineEnding PrependingMarkers {return le} / !lineEnding c:. {return c}) {return c})*
    le:$(lineEnding/documentEnding)
    {return [sps,start,lines.join(''),le]}
HTMLBlock7
  = sps:$OptionalThreeSpaces start:HTMLBStart7
    lines:(!HTMLBEnd7 c:(le:lineEnding PrependingMarkers {return le} / !lineEnding c:. {return c}) {return c})*
    le:$(lineEnding/documentEnding)
    {return [sps,start,lines.join(''),le]}

//HTMLBlock(Start/End)Conditions
HTMLBStart1 = "<" ("script"i / "pre"i / "style"i )
                  (&lineEnding / whitespaceCharacter / ">" / documentEnding)
HTMLBEnd1 = "</" ("script"i / "pre"i / "style"i ) ">" / documentEnding
HTMLBStart2 = "<!--"
HTMLBEnd2 = "-->" / documentEnding
HTMLBStart3 = "<?"
HTMLBEnd3 = "?>" / documentEnding
HTMLBStart4 = "<!" [A-Z]+
HTMLBEnd4 = ">" / documentEnding
HTMLBStart5 = "<![CDATA["
HTMLBEnd5 = "]]>" / documentEnding
HTMLBStart6 = "<" "/"?
      ( "address"i / "article"i / "aside"i / "base"i / "basefont"i / "blockquote"i
      / "body"i / "caption"i / "center"i / "col"i / "colgroup"i / "dd"i / "details"i
      / "dialog"i / "dir"i / "div"i / "dl"i / "dt"i / "fieldset"i / "figcaption"i
      / "figure"i / "footer"i / "form"i / "frame"i / "frameset"i
      / "h1"i / "h2"i / "h3"i / "h4"i / "h5"i / "h6"i
      / "head"i / "header"i / "hr"i / "html"i / "iframe"i / "legend"i / "li"i / "link"i
      / "main"i / "menu"i / "menuitem"i / "meta"i / "nav"i
      / "noframes"i / "ol"i / "optgroup"i / "option"i / "p"i / "param"i
      / "section"i / "source"i / "summary"i / "table"i / "tbody"i / "td"i / "tfoot"i
      / "th"i / "thead"i / "title"i / "tr"i / "track"i / "ul"i )
      (&lineEnding / whitespaceCharacter / ("/"? ">"))
HTMLBEnd6 = lineEnding blankLine / lineEnding? documentEnding
HTMLBStart7
  = tag:(t:OpenTag {return t.text} / t:ClosingTag {return t.text})
    !{ return /\n/.test(tag)}
    !{ return tag.startsWith('script')||tag.startsWith('pre')||tag.startsWith('style')}
    &(lineEnding / whitespaceCharacter)
    {return tag}
HTMLBEnd7 = lineEnding blankLine / lineEnding? documentEnding


// -------------------- LinkReferenceDefinition
LinkReferenceDefinition
  = OptionalThreeSpaces
    label:LinkLabel ":"
    (!lineEnding whitespaceCharacter)*
    (lineEnding (!lineEnding whitespaceCharacter)*)? 
    dest:LinkDestination
    title:(
      ( (!lineEnding whitespaceCharacter)+ (lineEnding (!lineEnding whitespaceCharacter)*)?
      / lineEnding (!lineEnding whitespaceCharacter)*
      )
      t:LinkTitle
      {return t}
    )?
    (!lineEnding whitespaceCharacter)*
    ( lineEnding / !. )
    {
      return visitor.visitLinkReferenceDefinition({
        node: {
          type: NODE_TYPES.LinkReferenceDefinition,
          label: label.text,
          dest,
          title,
        }
      });
    }

// -------------------- Paragraph and SetextHeading
Paragraph
  = OptionalThreeSpaces
    first:ParagraphFirstLine
    follow:ParagraphContinuationLine*
    result:(
      !(PrependingMarkers SetextHeadingUnderLine)
      {return visitor.visitParagraph({
        node: {
          type: NODE_TYPES.Paragraph,
          text:(first+follow.join('')).trim()}})}
    / PrependingMarkers level:SetextHeadingUnderLine
      {return visitor.visitSetextHeading({
        node: {
          type: NODE_TYPES.SetextHeading,
          level: level,
          text:(first+follow.join('')).trim()}
      })}
    )
    {return result}
ParagraphFirstLine
  = !blankLine
    line:(!lineEnding any:. {return any})+
    (lineEnding / !.)
    {return line.join('')}
ParagraphContinuationLine
  = !ParagraphInterrupts
    PartialPrependingMarkers
    line:ParagraphFirstLine
    {return '\n'+line}
ParagraphInterrupts
  = PrependingMarkers
    ( SetextHeadingUnderLine
    / head:ListItemNormalHead
      !{ return  head.marker.type == LIST_TYPES.Ordered && head.marker.num != 1 }
    / head:ListItemBeginWithICBHead
      !{ return  head.marker.type == LIST_TYPES.Ordered && head.marker.num != 1 }
    )
  / !PrependingMarkers PartialPrependingMarkers
    ( ListItemBeginWithBlanklineHead
    / ListItemBeginWithICBHead
    / ListItemNormalHead
    )
  / PartialPrependingMarkers
    ( blankLine
    / ThematicBreak
    / ATXHeading
    / FencedCodeBlock
    / BlockQuote
    / HTMLBlockInterpretation
    )
SetextHeadingUnderLine
  = OptionalThreeSpaces level:( "="+ {return 1} / "-"+ {return 2} ) space* lineEnding
    {return level}

// -------------------- BlankLines
BlankLine
  = blankLine (PartialPrependingMarkers blankLine)*
    {return visitor.visitBlankLine({node: {text:''}});}

// ###############################################
// ContainerBlock
// ###############################################
// -------------------- BlockQuote
BlockQuote
  = BQMarker
    !{ Util.pushBlockStack(blockStack, {type:NODE_TYPES.BlockQuote}) }
    first:Block
    follow:(PrependingMarkers block:Block { return block })*
    !{ Util.popBlockStack(blockStack) }
    {
      return visitor.visitBlockQuote({
        node:{
          type: NODE_TYPES.BlockQuote,
          children:[first].concat(follow),
        }
      })
    }
BQMarker
  = OptionalThreeSpaces ">" space?
// -------------------- List
List
  = !{ Util.pushListIndentStack(states.listIndentStack, 3) }
    first:(
      ListItem 
    / &{ Util.popListIndentStack(states.listIndentStack) }
      . // suppress infinite loop error in pegjs
    )
    follow:( 
      bl:(PartialPrependingMarkers blankLine)*
      !ThematicBreak
      PrependingMarkers
      item:ListItem
      &{ return first.marker.delimiter == item.marker.delimiter}
      {return {item, hasBlankline:bl.length!=0}}
    )*
    !{ Util.popListIndentStack(states.listIndentStack) }
    {
      const children = [first].concat(follow.map(x => x.item))
      return visitor.visitList({
        node: {
          type: NODE_TYPES.List,
          isLoose: !follow.every(x=>!x.hasBlankline) || !children.every(x=>!x.hasBlankline),
          markerType: first.marker.type,
          delimiter: first.marker.delimiter,
          startNum: first.marker.num,
          children: children,
        },
      })
    }
// -------------------- ListItem
ListItem
  = ListItemBeginWithBlankline / ListItemBeginWithICB / ListItemNormal
ListItemNormalHead
  = pre:ListItemPre
    space
    innerIndNum:OptionalThreeSpaces
    !blankLine
    {return {
      marker:pre.marker,
      length:pre.length+innerIndNum.length+1,
      pre
    }}
ListItemNormal
  = head:ListItemNormalHead
    !{ Util.pushBlockStack(blockStack, {
      type: NODE_TYPES.ListItem,
      size: head.length,
      delimiter: head.marker.delimiter})
    }
    !{ Util.changeListIndentStack(states.listIndentStack, head.length-1) }
    first:Block
    follow:( 
      /*TODO tight */
      bl:(PartialPrependingMarkers blankLine)*
      !ThematicBreak
      PrependingMarkers
      block:Block
      {return {block,hasBlankline:bl.length!=0}}
    )*
    !{ Util.popBlockStack(blockStack) }
    {
      return visitor.visitListItem({
        node: {
          type: NODE_TYPES.ListItem,
          hasBlankline: !follow.every(x=>!x.hasBlankline),
          marker: head.marker,
          indent: head.length,
          pre: head.pre,
          children: [first].concat(follow.map(x => x.block)),
        },
      });
    }
ListItemBeginWithICBHead
  = pre:ListItemPre
    space
    &MoreThanFourSpaces
    !blankLine
    {return {
      marker:pre.marker,
      length:pre.length+1,pre
    }}
ListItemBeginWithICB
  = head:ListItemBeginWithICBHead
    !{ Util.pushBlockStack(blockStack, {
      type: NODE_TYPES.ListItem,
      size: head.length,
      delimiter: head.marker.delimiter})
    }
    !{ Util.changeListIndentStack(states.listIndentStack, head.length-1) }
    first:Block
    follow:(
      /*TODO tight */
      bl:(PartialPrependingMarkers blankLine)*
      !ThematicBreak
      PrependingMarkers
      block:Block
      {return {block,hasBlankline:bl.length!=0}}
    )*
    !{ Util.popBlockStack(blockStack) }
    {
      return visitor.visitListItem({
        node: {
          type: NODE_TYPES.ListItem,
          hasBlankline: !follow.every(x=>!x.hasBlankline),
          marker: head.marker,
          indent: head.length,
          pre: head.pre,
          children: [first].concat(follow.map(x => x.block)),
        },
      });
    }
ListItemBeginWithBlanklineHead
  = pre:ListItemPre (blankLine / !.)
    {return {marker:pre.marker,length:pre.length+1,pre}}
ListItemBeginWithBlankline
  = head:ListItemBeginWithBlanklineHead
    !{ Util.pushBlockStack(blockStack, {
      type: NODE_TYPES.ListItem,
      size: head.length,
      delimiter: head.marker.delimiter})
    }
    !{ Util.changeListIndentStack(states.listIndentStack, head.length-1) }
    b:(
      PrependingMarkers
      first:Block
      follow:(
        /*TODO tight */
        bl:(PartialPrependingMarkers blankLine)*
        !ThematicBreak
        PrependingMarkers
        block:Block
        {return {block,hasBlankline:bl.length!=0}}
      )*
      {return {first, follow}}
    )?
    !{ Util.popBlockStack(blockStack) }
    {
      return visitor.visitListItem({
        node: {
          type: NODE_TYPES.ListItem,
          hasBlankline: b?(!b.follow.every(x=>!x.hasBlankline)):false,
          marker: head.marker,
          indent: head.length,
          pre: head.pre,
          children: b?[b.first].concat(b.follow.map(x => x.block)):[],
        },
      });
    }
ListItemPre
  = indent:OptionalListItemSpaces
    marker:ListMarker
    { return {length:indent.length+marker.text.length, marker, indent} }

ListMarker = BulletListMarker / OrderedListMarker
BulletListMarker
  = marker:[\-+*]
    { return {text:marker, type: LIST_TYPES.Bullet, delimiter: marker} }
OrderedListMarker
  = num:$([0-9] [0-9]? [0-9]? [0-9]? [0-9]? [0-9]? [0-9]? [0-9]? [0-9]?)
    delimiter:[.)]
    { return {text: num+delimiter, type: LIST_TYPES.Ordered, delimiter, num:parseInt(num, 10)} }

OptionalListItemSpaces
  = !{ states.currentListIndentPos=0; }
    spaces:(
      &{ return states.currentListIndentPos < states.listIndentStack[states.listIndentStack.length-1] }
      sp:space
      !{ states.currentListIndentPos++; }
      {return sp}
    )*
    {return spaces.join('')}
// ###############################################
// Stack
// ###############################################
BQPartialPrependingMarkers
  = IndentationLoop
    !{ return Util.isUnreadPrependingBQ(blockStack, states.currentBlockStackPos); }
PartialPrependingMarkers
  = IndentationLoop
PrependingMarkers
  = IndentationLoop
    &{ return blockStack.length == states.currentBlockStackPos; }
IndentationLoop
  = !{ states.currentBlockStackPos=0; }
    ( &{ return states.currentBlockStackPos<blockStack.length; }
      ( BQIndentation
      / ListItemIndentation
      )
      !{ states.currentBlockStackPos++; }
    )*
BQIndentation
  = &{ return blockStack[states.currentBlockStackPos].type == NODE_TYPES.BlockQuote; }
    BQMarker
ListItemIndentation
  = &{ return blockStack[states.currentBlockStackPos].type == NODE_TYPES.ListItem; }
    !{ states.currentListItemSpacePos=0; }
    ( &{ return states.currentListItemSpacePos < blockStack[states.currentBlockStackPos].size; }
      space
      !{ states.currentListItemSpacePos++; }
    )+
    &{ return blockStack[states.currentBlockStackPos].size == states.currentListItemSpacePos; }










Inlines
  = items:Inline*
    {
      return visitor.visitInlines(
        {
          children: items.reduce((acc,val)=>{ return acc.concat(val); },[]),
        }
      );
    }
// ###############################################
// Inline
// ###############################################
Inline
  = InlineLastCharWhitespaceAndLineEnding
  / InlineLastCharIndefinite
  / InlineLastCharPunctuation
  / InlineLastCharOther

InlineLastCharWhitespaceAndLineEnding
  = inline:(
      HardLineBreak
    / SoftLineBreak
    / &unicodeWhitespaceCharacter t:TextualContent {return t}
    )
    !{states.precededCharacterType = PRECEDED_CHARACTER_TYPES.WHITESPACE_AND_LINEENDING}
    {return inline}
InlineLastCharIndefinite
  = Emphasis
InlineLastCharPunctuation
  = inline:(
      CodeSpan
    / Autolink
    / RawHTML
    / BackslashEscape
    / EntityAndNumericReference
    / Link
    / Image
    / &asciiPunctuationCharacter t:TextualContent {return t}
    )
    !{states.precededCharacterType = PRECEDED_CHARACTER_TYPES.PUNCTUATION}
    {return inline}
InlineLastCharOther
  = !( unicodeWhitespaceCharacter / asciiPunctuationCharacter )
    t:TextualContent
    !{states.precededCharacterType = PRECEDED_CHARACTER_TYPES.OTHER}
    {return t}

EscapeAndReference = BackslashEscape / EntityAndNumericReference

// -------------------- BackslashEscape
BackslashEscape
  = "\\" character:asciiPunctuationCharacter
    {
      return visitor.visitBackslashEscape(
        {
          type: NODE_TYPES.BackslashEscape,
          text: '\\'+character,
          content: character,
        }
      );
    }

// -------------------- Entity and numeric character references
EntityAndNumericReference = EntityReferences / NumericReferences
EntityReferences
  = name:$("&" (!';' any:. {return any})+ ";")
    &{return entities[name]}
    {
      return visitor.visitEntityReference(
        {
          type: NODE_TYPES.EntityCharacterReference,
          text: name,
          content: entities[name].characters,
          entity:{
            name,
            info: entities[name],
          },
        }
      );
    }
NumericReferences
  = "&#"
    num:( ( decimal:[0-9]+ &{return decimal.length<9}
          { return parseInt(decimal.join(''), 10); })
        / ( [xX] hex:[0-9a-f]i+ &{return hex.length<8}
          { return parseInt(hex.join(''), 16); }) )
    ";"
    {
      return visitor.visitNumericReference(
        {
          type: NODE_TYPES.NumericCharacterReference,
          text: "&#"+num+";",
          content: String.fromCodePoint(Util.replaceUnicodeCodePoint(num)),
          entity: {
            num: Util.replaceUnicodeCodePoint(num),
            text: num,
          },
        }
      );
    }

// -------------------- CodeSpan
CodeSpan
  = start:"`"+
    content:( !( innerBacktick:"`"+ &{return start.length === innerBacktick.length} )
              cc:( whitespace {return " ";}
                 / str:"`"+ {return str.join('');}
                 / $. )
              {return cc}
    )+
    end:"`"+
    &{return start.length === end.length}
    {
      return visitor.visitCodeSpan(
        {
          type: NODE_TYPES.CodeSpan,
          content: content.join('').trim(),
          text: start.join('')+content.join('')+end.join(''),
          backtick: start,
        }
      );
    }

// -------------------- EmphasisAndStrongEmphasis
Emphasis
  = open:EmphasisOpen
    blocks:(EmphasisBlock+ / PopInlineStack &{return false})
    PopInlineStack
    !( next:.
      &{ return next !== open[0]}
      &{states.precededCharacterType = PRECEDED_CHARACTER_TYPES.PUNCTUATION}
    )
    { return buildEmphasis(open, blocks) }
EmphasisOpen
  = open:OpenEmphasis
    !{ Util.pushInlineStack(inlineStack, Util.getDelimiterType(open), open.length) }
    {return open}
PopInlineStack
  = !{ Util.popInlineStack(inlineStack) }
  
EmphasisBlock
  = block:(
      !EmphasisClose
      !HasUnprocessedClose
      !IsClosedCurrentStack
      !IsInterceptedCurrentStack
      !CanInterceptLinkOrImage
      !CanInterceptAnotherDelimiter
      item:Inline
      {return item}
    )+
    closeSize:(
      delim:EmphasisClose
      { return Util.closeEmphasis(inlineStack, delim) }
    / HasUnprocessedClose
      { return inlineStack[inlineStack.length-1].unprocessedCloseSize }
    / IsClosedCurrentStack
      { return inlineStack[inlineStack.length-1].size-inlineStack[inlineStack.length-1].currentSize }
    )
    { return {
      items: block.reduce((acc,val)=>{ return acc.concat(val); },[]),
      closeSize
    } }

EmphasisClose
  = canOpen:( &OpenEmphasis { return true } )?
    &(
      d:OpenDelimiterRun
      !{ return canOpen && (inlineStack[inlineStack.length-1].size + d.length) % 3 === 0 }
    )
    delim:CloseEmphasis
    &{ return inlineStack[inlineStack.length-1].type === Util.getDelimiterType(delim) }
    { return delim }
HasUnprocessedClose
  = &{ return Util.hasUnprocessedClose(inlineStack) }
IsClosedCurrentStack
  = &{ return Util.isClosedCurrentStack(inlineStack) }
IsInterceptedCurrentStack
  = &{ return Util.isInterceptedCurrentStack(inlineStack) }
CanInterceptLinkOrImage
  = &( "]" &{ return Util.interceptLinkOrImage(inlineStack) } )
CanInterceptAnotherDelimiter
  = &( delim:CloseEmphasis
      &{ return inlineStack[inlineStack.length-1].type !== Util.getDelimiterType(delim) }
      &{ return Util.interceptAnotherDelimiterRun(inlineStack, delim) }
    )

OpenEmphasis
  = ( &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.PUNCTUATION }
    / &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.WHITESPACE_AND_LINEENDING }
    )
    &("*"/"_") delim:LFDR
    { return delim }
  / &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.OTHER }
    &"*" delim:LFDR
    { return delim }
CloseEmphasis
  = ( &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.PUNCTUATION }
    / &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.OTHER }
    )
    delim:( &"*" delim:RFDR {return delim}
    / &"_" !LFDR delim:RFDR {return delim}
    / &"_" &LFDR delim:RFDR &punctuationCharacter {return delim}
    )
    {return delim}

LFDR
  = ( &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.PUNCTUATION }
    / &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.WHITESPACE_AND_LINEENDING }
    )
    delim:OpenDelimiterRun
    !(unicodeWhitespaceCharacter / lineEnding / !.)
    { return delim }
  / &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.OTHER }
    delim:OpenDelimiterRun
    !(unicodeWhitespaceCharacter / punctuationCharacter / lineEnding / !.)
    { return delim }
RFDR
  = &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.OTHER }
    delim:CloseDelimiterRun
    {return delim}
  / &{ return states.precededCharacterType === PRECEDED_CHARACTER_TYPES.PUNCTUATION }
    &( d:OpenDelimiterRun
      &(unicodeWhitespaceCharacter / punctuationCharacter / lineEnding / !.)
    )
    delim:CloseDelimiterRun
    { return delim }
    
OpenDelimiterRun = $( "*"+ / "_"+ )
CloseDelimiterRun
  = first:("*"/"_")
    !{ states.maxCloseDelimiterRunSize = Util.totalCurrentOpenSize(inlineStack,first) }
    !{ states.tempCloseDelimiterRunSize = 1 }
    follow:(
      &{ return (states.tempCloseDelimiterRunSize < states.maxCloseDelimiterRunSize) }
      c:("*"/"_")
      &{return first === c}
      !{ states.tempCloseDelimiterRunSize++ }
      {return c}
    )*
    {return first+follow.join('')}

// -------------------- Link
Link
  = &"[" 
    !{ Util.pushInlineStack(inlineStack, INLINE_STACK_TYPES.Link, 0) }
    link:(InlineLink / ReferenceLink / &{ Util.popInlineStack(inlineStack) } .)
    &{ return Util.popLinkStack(inlineStack) }
    {return link}
InlineLink
  = text:LinkText "(" whitespace?
    destAndTitle:(
      dest:LinkDestination title:(whitespace t:LinkTitle {return t})?
      {return {dest,title}}
    / title:LinkTitle
      {return {title}}
    )?
    whitespace? ")"
{
  return visitor.visitInlineLink(
    {
      type: NODE_TYPES.Link,
      content: text.map(x=>x.text).join(),
      text: text.map(x=>x.text).join(),
      dest: destAndTitle ? destAndTitle.dest : null,
      title:destAndTitle ? destAndTitle.title : null,
      children: text,
    }
  )
}
ReferenceLink
  = ref:( FullReferenceLink
        / CollapsedReferenceLink
        / ShortcutReferenceLink )
    &{return !!visitor.def[ref.label.text.toLowerCase()] }
{
  return visitor.visitReferenceLink(
    {
      type: NODE_TYPES.Link,
      content: ref.text ? undefined : ref.label.text,
      text: ref.text ? undefined : ref.label.text,
      dest: visitor.def[ref.label.text.toLowerCase()].dest,
      title:visitor.def[ref.label.text.toLowerCase()].title,
      children: ref.text ? ref.text : ref.label.items,
    }
  )
}
FullReferenceLink = text:LinkText label:LinkLabel {return {text, label}}
CollapsedReferenceLink = label:InlineLinkLabel "[]" {return {label}}
ShortcutReferenceLink = label:InlineLinkLabel !LinkLabel {return {label}}

LinkText
  = '['
    items:(
      !(Link) nest:NestedBracketLinkText {return nest}
    / !(Link / [\[\]]) content:Inline {return content}
    )*
    ']'
    { return Util.buildLinkText(items); }
NestedBracketLinkText
  = &'[' start:TextualContent
    items:(
      !(Link) nest:NestedBracketLinkText {return nest}
    / !(Link / [\[\]]) content:Inline {return content}
    )*
    &']' end:TextualContent
    { return Util.buildLinkText([start].concat(items,end)); }
LinkDestination
  = "<" 
    str:$(
      !(space / lineEnding )
      $(EscapeAndReference / [^<>])
    )*
    ">"
    { return str}
  / text:(
      "(" item:NestedLinkDestination ")" {return '('+item+')';}
    / ( node:EscapeAndReference {return node.content}
      / !(asciiControlCharacters / space / [()]) c:. {return c}
      )
    )+
    {return text.join('')}
NestedLinkDestination
  = dest:(
      "(" item:NestedLinkDestination ")" {return '('+item+')';}
    / text:(
        node:EscapeAndReference {return node.content}
      / !(asciiControlCharacters / space / [()]) c:. {return c}
      )
      {return text}
    )*
    {return dest.join('');}
LinkTitle
  = '"' 
    title:(
      char:(
        node:EscapeAndReference {return node.content}
      / !('"'/(lineEnding blankLine)) c:. {return c}
      )
      {return char}
    )*
    '"'
    {return title.join('')}
  / "'"
    title:(
      char:(
        node:EscapeAndReference {return node.content}
      / !("'"/(lineEnding blankLine)) c:. {return c}
      )
      {return char}
    )*
    "'"
    {return title.join('')}
  / "("
    title:(
      char:(
        node:EscapeAndReference {return node.content}
      / !(")"/(lineEnding blankLine)) c:. {return c}
      )
      {return char}
    )*
    ")"
    {return title.join('')}
LinkLabel
  = "["
    whitespace?
    label:(
      !([\[\]])
      char:(ref:EscapeAndReference {return ref.text}/ .)
      {return char}
    )+
    &{return label.length<1000}
    "]"
    {
      return {
        text: Util.normalizeLinkLabel(label.join('')),
      }
    }
InlineLinkLabel
  = "["
    whitespace?
    items:(
      !(Link / [\[\]]) content:Inline {return content}
    )+
    &{return Util.normalizeLinkLabel(
          items.reduce((acc,val)=>{return acc.concat(val)},[]).map(x=>x.text)
               .join('')
        ).length<1000}
    "]"
    {
      return {
        items: items.reduce((acc,val)=>{return acc.concat(val)},[]),
        text: Util.normalizeLinkLabel(
          items.reduce((acc,val)=>{return acc.concat(val)},[]).map(x=>x.text)
               .join('')
        ),
      }
    }

// -------------------- Image
Image
  = &"![" 
    !{ Util.pushInlineStack(inlineStack, INLINE_STACK_TYPES.Link, 0) }
    image:(InlineImage / ReferenceImage / &{ Util.popInlineStack(inlineStack) } .)
    &{ return Util.popInlineStack(inlineStack) }
    {return image}
InlineImage
  = desc:ImageDescription "(" whitespace?
    destAndTitle:(
      dest:LinkDestination title:(whitespace t:LinkTitle {return t})?
      {return {dest,title}}
    / title:LinkTitle
      {return {title}}
    )? 
    whitespace? ")"
{
  return visitor.visitInlineImage(
    {
      type: NODE_TYPES.Image,
      content: desc.map(x=>x.text).join(),
      text: desc.map(x=>x.text).join(),
      dest: destAndTitle ? destAndTitle.dest : null,
      title:destAndTitle ? destAndTitle.title : null,
      children: desc,
    }
  )
}
ReferenceImage
  = ref:( FullReferenceImage
        / CollapsedReferenceImage
        / ShortcutReferenceImage )
    &{return !!visitor.def[ref.label.text.toLowerCase()] }
{
  return visitor.visitReferenceImage(
    {
      type: NODE_TYPES.Image,
      content: ref.desc ? undefined : ref.label.text,
      text: ref.desc ? undefined : ref.label.text,
      dest: visitor.def[ref.label.text.toLowerCase()].dest,
      title:visitor.def[ref.label.text.toLowerCase()].title,
      children: ref.desc ? ref.desc : ref.label.items,
    }
  )
}
FullReferenceImage = desc:ImageDescription label:LinkLabel {return {desc, label}}
CollapsedReferenceImage = "!" label:InlineLinkLabel "[]" {return {label}}
ShortcutReferenceImage = "!" label:InlineLinkLabel !LinkLabel {return {label}}

ImageDescription
  = "!["
    desc:( !([\[\]]) content:Inline {return content} )*
    "]"
    { return Util.buildImageDesc(desc); }
// -------------------- Autolink
Autolink = URIAutolink / EmailAutolink
URIAutolink
  = "<" uri:AbsoluteURI ">" 
    {
      return visitor.visitAutolink(
        {
          type: NODE_TYPES.Autolink,
          text: uri,
          content: '<'+uri+'>',
          linkType: AUTOLINK_TYPE.Uri,
        }
      )
    }
EmailAutolink
  = "<" email:EmailAddress ">"
    {
      return visitor.visitAutolink(
        {
          type: NODE_TYPES.Autolink,
          text: email,
          content: '<'+email+'>',
          linkType: AUTOLINK_TYPE.Mail,
        }
      )
    }
AbsoluteURI
  = $(Scheme ":" (!(whitespaceCharacter / asciiControlCharacters / [<>]) .)*)
Scheme = $([a-zA-Z] followed:[a-zA-Z0-9+.-]+ &{return followed.length<32})
EmailAddress
  = str:$( (!">" .)+ )
  &{return /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/.test(str) }
  {return str}

// -------------------- RawHTML
RawHTML
  = tag:( OpenTag / ClosingTag / HTMLComment / ProcessingInstruction
         / Declaration / CDATASection )
    { 
      return visitor.visitRawHTML(
        {
          type: NODE_TYPES.RawHTML,
          text: tag.text,
          content: tag.text,
        }
      );
    }
OpenTag = "<" name:TagName attrs:Attribute* ws:whitespace? s:"/"? ">"
          { return {
            name,
            attrs,
            text: '<'+name+attrs.map(v=>v.text).join('')+(ws?ws:'')+(s?s:'')+'>'
          } }
ClosingTag = "</" name:TagName ws:whitespace? ">"
              { return {name, text: '</'+name+(ws?ws:'')+'>'} }
HTMLComment = text:$("<!--" !(">" / "->") (!("--") .)* !("---") "-->")
              {return {text}}
ProcessingInstruction = text:$("<?" (!"?>" .)* "?>")
                        {return {text}}
Declaration = text:$("<!" [A-Z]+ whitespace (!">" .)* ">")
              {return {text}}
CDATASection = text:$("<![CDATA[" (!"]]>" .)* "]]>")
              {return {text}}

TagName = $([a-zA-Z] [a-zA-Z0-9-]*)
Attribute = ws:whitespace name:AttributeName v:AttributeValueSpecification?
            {return {text: ws+name+(v?v.text:''), name, value: v?v.value:''}}
AttributeName = $([a-zA-Z_:] [a-zA-Z0-9_.:-]*)
AttributeValueSpecification = ws1:whitespace? "=" ws2:whitespace? v:AttributeValue
                              {return {text:(ws1?ws1:'')+"="+(ws2?ws2:'')+v.text, value:v.value}}
AttributeValue
  = UnquotedAttributeValue / SingleQuotedAttributeValue / DoubleQuotedAttributeValue
UnquotedAttributeValue = value:(arr:[^ "'=<>`]+ {return arr.join('')})
                         {return {text:value, value}}
SingleQuotedAttributeValue = "'" value:(arr:[^']* {return arr.join('')}) "'"
                             {return {text:"'"+value+"'", value}}
DoubleQuotedAttributeValue = '"' value:(arr:[^"]* {return arr.join('')}) '"'
                             {return {text:'"'+value+'"', value}}

// -------------------- HardLineBreaks
HardLineBreak
  = pre:(space sp:space+ {return ' '+sp.join('')} / "\\" ) lineEnding spaces:space*
    {
      return visitor.visitHardLineBreak(
        {
          type: NODE_TYPES.HardLineBreak,
          text: pre+'\n'+spaces.join(''),
          content: '\n',
        }
      );
    }

// -------------------- SoftLineBreaks
SoftLineBreak
  = sp:space? lineEnding spaces:space*
    {
      return visitor.visitSoftLineBreak(
        {
          type: NODE_TYPES.SoftLineBreak,
          text: (sp?sp:'')+'\n'+spaces.join(''),
          content: '\n',
        }
      );
    }

// -------------------- TextualContent
TextualContent
  = text:(
      '`'+
    / "*"+
    / "_"+
    / c:. {return [c]}
    )
    {
      return text.map((val)=>{
        return visitor.visitTextualContent({
            type: NODE_TYPES.TextualContent,
            text: val,
            content: val,
        });
      });
    }

// ###############################################
// Preliminaries
// ###############################################
OptionalThreeSpaces = $(space? space? space?)
MoreThanFourSpaces = sps:($space $space $space spc:(sp:space+ {return sp.join("");}))
                      {return sps.join('')}

line = (!lineEnding any:. {return any})*
lineEnding = ("\u000A" / ("\u000D" "\u000A"?)) {return '\n'}

blankLine
  = spaces:[\u0020\u0009]* le:lineEnding
    {return spaces.join('')+le}

whitespaceCharacter
  = "\u0020" / "\u0009" / "\u000A" / "\u000B" / "\u000C" / "\u000D"
whitespace = $(whitespaceCharacter+)

unicodeWhitespaceCharacter
  = UnicodeZs
  / "\u0009" / "\u000D" / "\u000A" / "\u000C"
unicodeWhitespace = unicodeWhitespaceCharacter+

space = "\u0020"

asciiPunctuationCharacter = [!"#$%&'()*+,-./:;<=>?@^_`{|}\\~\u005B\u005D]

punctuationCharacter
  = asciiPunctuationCharacter
  / UnicodePc / UnicodePd / UnicodePe / UnicodePf
  / UnicodePi / UnicodePo / UnicodePs

asciiControlCharacters = [\u0000-\u001F\u007F]

documentEnding = !.
// #######################Unicode categories########################

UnicodeZs = character:. &{ return Zs[character] }
UnicodePc = character:. &{ return Pc[character] }
UnicodePd = character:. &{ return Pd[character] }
UnicodePe = character:. &{ return Pe[character] }
UnicodePf = character:. &{ return Pf[character] }
UnicodePi = character:. &{ return Pi[character] }
UnicodePo = character:. &{ return Po[character] }
UnicodePs = character:. &{ return Ps[character] }








//gfm extension
// -------------------- Autolink
AutolinkExtension
  = ExtendedWWWAutolink / ExtendedURLAutolink / ExtendedEmailAutolink
ExtendedWWWAutolink
  = ValidDomain
ExtendedURLAutolink
  = ('http' / 'https' / 'ftp')
    '://'
    ValidDomain
ExtendedEmailAutolink // TODO
  = (alphanumeric/[._+-])+
    '@'
    (alphanumeric/[_-])+
    '.'
    (  alphanumeric/[._-])+
ValidDomain // TODO
  = [a-z]i
  / '_' / '-' / '.'
alphanumeric = [a-z] // TODO
