import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Renders the markdown the coach replies with (headings, **bold**, *italic*,
/// lists, tables, quotes, code, links, rules) as styled text, so people never
/// see raw `**` or `#` characters. Headings are bold. Not selectable, so it
/// never competes with scrolling.
class MarkdownText extends StatefulWidget {
  const MarkdownText(this.data, {super.key, this.color, this.fontSize = 15});

  final String data;
  final Color? color;
  final double fontSize;

  @override
  State<MarkdownText> createState() => _MarkdownTextState();
}

class _MarkdownTextState extends State<MarkdownText> {
  final _recognizers = <TapGestureRecognizer>[];
  List<Widget>? _cache;
  Object? _cacheKey;

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.fg;
    final key = Object.hash(widget.data, color, widget.fontSize, context.isDark);
    if (_cache == null || _cacheKey != key) {
      for (final r in _recognizers) {
        r.dispose();
      }
      _recognizers.clear();
      final base = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle())
          .copyWith(fontSize: widget.fontSize, fontWeight: FontWeight.w500, height: 1.45, color: color);
      _cache = _MarkdownBuilder(
        base: base,
        color: color,
        accent: context.accent,
        border: context.border,
        recognizers: _recognizers,
      ).build(parseMarkdown(widget.data));
      _cacheKey = key;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: _cache!);
  }
}

// ── Block model and parser (pure Dart, unit-tested) ──

sealed class MdBlock {}

class MdHeading extends MdBlock {
  MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class MdParagraph extends MdBlock {
  MdParagraph(this.text);
  final String text;
}

class MdListItem extends MdBlock {
  MdListItem(this.depth, this.marker, this.text);
  final int depth;
  final String marker; // '•' or '1.'
  final String text;
}

class MdQuote extends MdBlock {
  MdQuote(this.text);
  final String text;
}

class MdCode extends MdBlock {
  MdCode(this.text);
  final String text;
}

class MdRule extends MdBlock {}

class MdTable extends MdBlock {
  MdTable(this.header, this.rows);
  final List<String> header;
  final List<List<String>> rows;
}

final _headingRe = RegExp(r'^(#{1,6})\s+(.+?)\s*#*\s*$');
final _ruleRe = RegExp(r'^([-*_])(\s*\1){2,}\s*$');
final _listRe = RegExp(r'^(\s*)([-*+•]|\d+[.)])\s+(.*)$');
final _tableSepRe = RegExp(r'^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?$');

List<String> _splitRow(String line) {
  var t = line.trim();
  if (t.startsWith('|')) t = t.substring(1);
  if (t.endsWith('|')) t = t.substring(0, t.length - 1);
  return t.split('|').map((c) => c.trim()).toList();
}

List<MdBlock> parseMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  final para = <String>[];
  final quote = <String>[];

  void flushPara() {
    if (para.isNotEmpty) {
      blocks.add(MdParagraph(para.join('\n')));
      para.clear();
    }
  }

  void flushQuote() {
    if (quote.isNotEmpty) {
      blocks.add(MdQuote(quote.join('\n')));
      quote.clear();
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final t = line.trim();

    if (t.startsWith('```')) {
      flushPara();
      flushQuote();
      final code = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        code.add(lines[i]);
        i++;
      }
      blocks.add(MdCode(code.join('\n')));
      continue;
    }
    if (t.isEmpty) {
      flushPara();
      flushQuote();
      continue;
    }
    if (!t.startsWith('>')) flushQuote();

    final h = _headingRe.firstMatch(t);
    if (h != null) {
      flushPara();
      blocks.add(MdHeading(h.group(1)!.length, h.group(2)!));
      continue;
    }
    if (_ruleRe.hasMatch(t)) {
      flushPara();
      blocks.add(MdRule());
      continue;
    }
    if (t.contains('|') && i + 1 < lines.length && _tableSepRe.hasMatch(lines[i + 1].trim()) && lines[i + 1].contains('-')) {
      flushPara();
      final header = _splitRow(t);
      final rows = <List<String>>[];
      i += 2;
      while (i < lines.length && lines[i].trim().contains('|')) {
        final cells = _splitRow(lines[i]);
        rows.add([for (var c = 0; c < header.length; c++) c < cells.length ? cells[c] : '']);
        i++;
      }
      i--;
      blocks.add(MdTable(header, rows));
      continue;
    }
    if (t.startsWith('>')) {
      flushPara();
      quote.add(t.replaceFirst(RegExp(r'^>\s?'), ''));
      continue;
    }
    final li = _listRe.firstMatch(line);
    if (li != null) {
      flushPara();
      final marker = li.group(2)!;
      final isBullet = RegExp(r'^[-*+•]$').hasMatch(marker);
      final indent = li.group(1)!.replaceAll('\t', '    ').length;
      blocks.add(MdListItem((indent ~/ 2).clamp(0, 3), isBullet ? '•' : marker.replaceAll(')', '.'), li.group(3)!));
      continue;
    }
    para.add(t);
  }
  flushPara();
  flushQuote();
  return blocks;
}

// ── Inline parser: turns **bold**, *italic*, `code`, [links](url) into spans ──

class _MarkdownBuilder {
  _MarkdownBuilder({
    required this.base,
    required this.color,
    required this.accent,
    required this.border,
    required this.recognizers,
  });

  final TextStyle base;
  final Color color;
  final Color accent;
  final Color border;
  final List<TapGestureRecognizer> recognizers;

  static const _escapable = r'\`*_{}[]()#+-.!|~>';

  List<Widget> build(List<MdBlock> blocks) {
    final out = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final first = i == 0;
      switch (b) {
        case MdHeading():
          final size = switch (b.level) { 1 => base.fontSize! + 7, 2 => base.fontSize! + 4, 3 => base.fontSize! + 2, _ => base.fontSize! + 0.5 };
          out.add(Padding(
            padding: EdgeInsets.only(top: first ? 0 : 10, bottom: 4),
            child: _rich(b.text, base.copyWith(fontSize: size, fontWeight: FontWeight.w800, height: 1.25)),
          ));
        case MdParagraph():
          out.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: _rich(b.text, base)));
        case MdListItem():
          out.add(Padding(
            padding: EdgeInsets.only(left: b.depth * 14.0, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: b.marker == '•' ? 16 : 24,
                  child: Text(b.depth > 0 && b.marker == '•' ? '◦' : b.marker,
                      style: base.copyWith(fontWeight: FontWeight.w700, color: accent)),
                ),
                Expanded(child: _rich(b.text, base)),
              ],
            ),
          ));
        case MdQuote():
          out.add(Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
            child: _rich(b.text, base.copyWith(color: color.withValues(alpha: 0.75))),
          ));
        case MdCode():
          out.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(b.text, style: base.copyWith(fontFamily: 'monospace', fontSize: base.fontSize! - 2, height: 1.4)),
            ),
          ));
        case MdRule():
          out.add(Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: border)));
        case MdTable():
          out.add(_table(b));
      }
    }
    return out;
  }

  Widget _table(MdTable t) {
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          decoration: header ? BoxDecoration(color: color.withValues(alpha: 0.06)) : null,
          children: [
            for (final c in cells)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: _rich(c, base.copyWith(fontSize: base.fontSize! - 1, fontWeight: header ? FontWeight.w800 : FontWeight.w500)),
              ),
          ],
        );
    // Column widths follow the content (capped so long cells wrap), so words never break mid-word.
    // A table wider than the screen scrolls sideways instead of being squeezed.
    final cols = t.header.length;
    double need(int c) {
      var longest = 0;
      for (final r in [t.header, ...t.rows]) {
        if (c < r.length) {
          final len = r[c].replaceAll(RegExp(r'[*_`~]'), '').length;
          if (len > longest) longest = len;
        }
      }
      return (longest * (base.fontSize! * 0.52) + 22).clamp(76.0, 190.0);
    }

    final widths = [for (var c = 0; c < cols; c++) need(c)];
    final total = widths.fold<double>(0, (a, b) => a + b);

    return LayoutBuilder(
      builder: (context, box) {
        final scale = total < box.maxWidth ? box.maxWidth / total : 1.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Table(
              border: TableBorder(horizontalInside: BorderSide(color: border)),
              columnWidths: {for (var c = 0; c < cols; c++) c: FixedColumnWidth(widths[c] * scale)},
              children: [row(t.header, header: true), for (final r in t.rows) row(r)],
            ),
          ),
        );
      },
    );
  }

  Widget _rich(String text, TextStyle style) => Text.rich(TextSpan(style: style, children: _inline(text, style)));

  List<InlineSpan> _inline(String s, TextStyle style) {
    final spans = <InlineSpan>[];
    final buf = StringBuffer();

    void flush() {
      if (buf.isNotEmpty) {
        spans.add(TextSpan(text: buf.toString()));
        buf.clear();
      }
    }

    bool wordChar(String c) => RegExp(r'[A-Za-z0-9]').hasMatch(c);

    var i = 0;
    while (i < s.length) {
      final c = s[i];

      if (c == '\\' && i + 1 < s.length && _escapable.contains(s[i + 1])) {
        buf.write(s[i + 1]);
        i += 2;
        continue;
      }

      // ***bold italic***
      if (s.startsWith('***', i)) {
        final end = s.indexOf('***', i + 3);
        if (end > i + 3) {
          flush();
          final st = style.copyWith(fontWeight: FontWeight.w800, fontStyle: FontStyle.italic);
          spans.add(TextSpan(style: st, children: _inline(s.substring(i + 3, end), st)));
          i = end + 3;
          continue;
        }
      }

      // **bold** / __bold__
      if (s.startsWith('**', i) || s.startsWith('__', i)) {
        final tok = s.substring(i, i + 2);
        final end = s.indexOf(tok, i + 2);
        final prevWord = tok == '__' && i > 0 && wordChar(s[i - 1]);
        if (end > i + 2 && !prevWord) {
          flush();
          final st = style.copyWith(fontWeight: FontWeight.w800);
          spans.add(TextSpan(style: st, children: _inline(s.substring(i + 2, end), st)));
          i = end + 2;
          continue;
        }
      }

      // ~~strike~~
      if (s.startsWith('~~', i)) {
        final end = s.indexOf('~~', i + 2);
        if (end > i + 2) {
          flush();
          final st = style.copyWith(decoration: TextDecoration.lineThrough);
          spans.add(TextSpan(style: st, children: _inline(s.substring(i + 2, end), st)));
          i = end + 2;
          continue;
        }
      }

      // `code`
      if (c == '`') {
        final end = s.indexOf('`', i + 1);
        if (end > i + 1) {
          flush();
          spans.add(TextSpan(
            text: s.substring(i + 1, end),
            style: style.copyWith(fontFamily: 'monospace', fontSize: style.fontSize! - 1, backgroundColor: color.withValues(alpha: 0.08)),
          ));
          i = end + 1;
          continue;
        }
      }

      // *italic* / _italic_
      if (c == '*' || c == '_') {
        final prevWord = c == '_' && i > 0 && wordChar(s[i - 1]);
        final afterSame = i > 0 && s[i - 1] == c;
        if (!prevWord && !afterSame && i + 1 < s.length && s[i + 1] != ' ' && s[i + 1] != c) {
          var end = i + 1;
          var found = -1;
          while (end < s.length) {
            end = s.indexOf(c, end);
            if (end == -1) break;
            final nextWord = c == '_' && end + 1 < s.length && wordChar(s[end + 1]);
            if (s[end - 1] != ' ' && s[end - 1] != '\\' && !nextWord && !(end + 1 < s.length && s[end + 1] == c)) {
              found = end;
              break;
            }
            end++;
          }
          if (found > i + 1) {
            flush();
            final st = style.copyWith(fontStyle: FontStyle.italic);
            spans.add(TextSpan(style: st, children: _inline(s.substring(i + 1, found), st)));
            i = found + 1;
            continue;
          }
        }
      }

      // [text](url)
      if (c == '[') {
        final m = RegExp(r'^\[([^\]]+)\]\((\S+?)\)').firstMatch(s.substring(i));
        if (m != null) {
          flush();
          final url = m.group(2)!;
          final uri = Uri.tryParse(url);
          final ok = uri != null && (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'mailto');
          final st = style.copyWith(color: accent, decoration: TextDecoration.underline, fontWeight: FontWeight.w700);
          TapGestureRecognizer? rec;
          if (ok) {
            rec = TapGestureRecognizer()..onTap = () => launchUrl(uri, mode: LaunchMode.externalApplication);
            recognizers.add(rec);
          }
          spans.add(TextSpan(text: m.group(1), style: st, recognizer: rec));
          i += m.group(0)!.length;
          continue;
        }
      }

      buf.write(c);
      i++;
    }
    flush();
    return spans;
  }
}
