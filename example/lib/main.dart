// ignore_for_file: avoid_print

import 'dart:math' show min;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_prism/flutter_prism.dart' show Prism, PrismStyle;
import 'package:hive_flutter/hive_flutter.dart' show Hive;
import 'package:markdown_viewer/markdown_viewer.dart'
    show MarkdownStyle, MarkdownViewer;
import 'package:markdown_viewer_example/image.dart'
    show buildImage, initImageCache;
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;

import 'extension.dart';

const markdown = r'''
## Images

![Minion](https://octodex.github.com/images/minion.png)
![Stormtroopocat](https://octodex.github.com/images/stormtroopocat.jpg "The Stormtroopocat")

Like links, Images also have a footnote style syntax

![Alt text][id]

With a reference later in the document defining the URL location:

[id]: https://octodex.github.com/images/dojocat.jpg  "The Dojocat"


# h1 Heading 8-)
## h2 Heading
### h3 Heading
#### h4 Heading
##### h5 Heading
###### h6 Heading


## Horizontal Rules

___

---

***


## Typographic replacements

Enable typographer option to see result.

(c) (C) (r) (R) (tm) (TM) (p) (P) +-

test.. test... test..... test?..... test!....

!!!!!! ???? ,,  -- ---

"Smartypants, double quotes" and 'single quotes'


## Emphasis

**This is bold text**

__This is bold text__

*This is italic text*

_This is italic text_

~~Strikethrough~~


## Blockquotes


> Blockquotes can also be nested...
>> ...by using additional greater-than signs right next to each other...
> > > ...or with spaces between arrows.


## Lists

Unordered

+ Create a list by starting a line with `+`, `-`, or `*`
+ Sub-lists are made by indenting 2 spaces:
  - Marker character change forces new list start:
    * Ac tristique libero volutpat at
    + Facilisis in pretium nisl aliquet
    - Nulla volutpat aliquam velit
+ Very easy!

Ordered

1. Lorem ipsum dolor sit amet
2. Consectetur adipiscing elit
3. Integer molestie lorem at massa


1. You can use sequential numbers...
1. ...or keep all the numbers as `1.`

Start numbering with offset:

57. foo
1. bar


## Code

Inline `code`

Indented code

    // Some comments
    line 1 of code
    line 2 of code
    line 3 of code


Block code "fences"

```
Sample text here...
```

Syntax highlighting

``` js
var foo = function (bar) {
  return bar++;
};

console.log(foo(5));
```

## Tables

| Option | Description |
| ------ | ----------- |
| data   | path to data files to supply the data that will be passed into templates. |
| engine | engine to be used for processing templates. Handlebars is the default. |
| ext    | extension to be used for dest files. |

Right aligned columns

| Option | Description |
| ------:| -----------:|
| data   | path to data files to supply the data that will be passed into templates. |
| engine | engine to be used for processing templates. Handlebars is the default. |
| ext    | extension to be used for dest files. |


## Links

[link text](http://dev.nodeca.com)

[link with title](http://nodeca.github.io/pica/demo/ "title text!")

Autoconverted link https://github.com/nodeca/pica (enable linkify to see)


## Plugins

The killer feature of `markdown-it` is very effective support of
[syntax plugins](https://www.npmjs.org/browse/keyword/markdown-it-plugin).


### [Emojies](https://github.com/markdown-it/markdown-it-emoji)

> Classic markup: :wink: :cry: :laughing: :yum:
>
> Shortcuts (emoticons): :-) :-( 8-) ;)

see [how to change output](https://github.com/markdown-it/markdown-it-emoji#change-output) with twemoji.


### [Subscript](https://github.com/markdown-it/markdown-it-sub) / [Superscript](https://github.com/markdown-it/markdown-it-sup)

- 19^th^
- H~2~O


### [\<ins>](https://github.com/markdown-it/markdown-it-ins)

++Inserted text++


### [\<mark>](https://github.com/markdown-it/markdown-it-mark)

==Marked text==


### [Footnotes](https://github.com/markdown-it/markdown-it-footnote)

Footnote 1 link[^first].

Footnote 2 link[^second].

Inline footnote^[Text of inline footnote] definition.

Duplicated footnote reference[^second].

[^first]: Footnote **can have markup**

    and multiple paragraphs.

[^second]: Footnote text.


### [Definition lists](https://github.com/markdown-it/markdown-it-deflist)

Term 1

:   Definition 1
with lazy continuation.

Term 2 with *inline markup*

:   Definition 2

        { some code, part of Definition 2 }

    Third paragraph of definition 2.

_Compact style:_

Term 1
  ~ Definition 1

Term 2
  ~ Definition 2a
  ~ Definition 2b


### [Abbreviations](https://github.com/markdown-it/markdown-it-abbr)

This is HTML abbreviation example.

It converts "HTML", but keep intact partial entries like "xxxHTMLyyy" and so on.

*[HTML]: Hyper Text Markup Language

### [Custom containers](https://github.com/markdown-it/markdown-it-container)

::: warning
*here be dragons*
:::

---

Turndown Demo
=============

This demonstrates [turndown](https://github.com/mixmark-io/turndown) – an HTML to Markdown converter in JavaScript.

Usage
-----

    var turndownService = new TurndownService()
    console.log(
      turndownService.turndown('<h1>Hello world</h1>')
    )

* * *

It aims to be [CommonMark](http://commonmark.org/) compliant, and includes options to style the output. These options include:

*   headingStyle (setext or atx)
*   horizontalRule (\*, -, or \_)
*   bullet (\*, -, or +)
*   codeBlockStyle (indented or fenced)
*   fence (\` or ~)
*   emDelimiter (\_ or \*)
*   strongDelimiter (\*\* or \_\_)
*   linkStyle (inlined or referenced)
*   linkReferenceStyle (full, collapsed, or shortcut)

---

## Markdown example

Hello **Markdown**!

### Highlights

- [x] ==100%== conform to CommonMark.
- [x] ==100%== conform to GFM.
- [x] Easy to implement syntax **highlighting**, for example `flutter_prism`:
   ```dart
   // Dart language.
   void main() {
     print('Hello, World!');
   }
   ```
- [x] Easy to custom, for example:
  > This is a #custom_extension

---
### Dependencies
| Name | Required|
|--|--:|
|`dart_markdown`|Yes|
|`flutter_prism`|No|

''';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getTemporaryDirectory();
  Hive.init(dir.path);
  initImageCache(await Hive.openLazyBox('images'));
  runApp(const MyApp());
}

var _tablet = false;
double _round(double value, double round) {
  return (value / round).ceil() * round;
}
double resolveMaxWidth(BuildContext context) {
  final maxWidth = MediaQuery.of(context).size.width;
  return !_tablet || Orientation.portrait == MediaQuery.of(context).orientation
      ? maxWidth
      : min(
          maxWidth,
          maxWidth > 1200
              ? (maxWidth * 0.75).floorToDouble()
              : _round(maxWidth * 0.74, 10),
        );
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      title: 'MarkdownViewer Demo',
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
      scrollBehavior: CustomScrollBehavior(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxWidth = resolveMaxWidth(context);
    return Scaffold(
      //appBar: AppBar(title: const Text('MarkdownViewer Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 80, left: 28, right: 28, bottom: 40),
        child: MarkdownViewer(
          markdown,
          enableTaskList: true,
          enableSuperscript: false,
          enableSubscript: false,
          enableFootnote: false,
          enableImageSize: false,
          enableKbd: false,
          syntaxExtensions: [ExampleSyntax()],
          imageBuilder: (uri, info) => buildImage(
            uri,
            info.width,
            info.height,
            maxWidth: maxWidth,
          ),
          highlightBuilder: (text, language, infoString) {
            final prism = Prism(
              mouseCursor: SystemMouseCursors.text,
              style: Theme.of(context).brightness == Brightness.dark
                  ? const PrismStyle.dark()
                  : const PrismStyle(),
            );
            return prism.render(text, language ?? 'plain');
          },
          onTapLink: (href, title) {
            print({href, title});
          },
          elementBuilders: [
            ExampleBuilder(),
          ],
          styleSheet: const MarkdownStyle(
            listItemMarkerTrailingSpace: 12,
            codeSpan: TextStyle(
              fontFamily: 'RobotoMono',
            ),
            codeBlock: TextStyle(
              fontSize: 14,
              letterSpacing: -0.3,
              fontFamily: 'RobotoMono',
            ),
          ),
        ),
      ),
    );
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
