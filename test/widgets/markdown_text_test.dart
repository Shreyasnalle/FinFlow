import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/widgets/markdown_text.dart';

Future<List<RichText>> render(WidgetTester tester, String md) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: MarkdownText(md)))));
  return tester.widgetList<RichText>(find.byType(RichText)).toList();
}

String plain(List<RichText> rts) => rts.map((r) => r.text.toPlainText()).join('\n');

void main() {
  group('parser', () {
    test('splits headings, paragraphs, lists, rules', () {
      final b = parseMarkdown('# Title\n\nHello **you**\n\n- a\n- b\n\n---\n1. one\n2) two');
      expect(b.whereType<MdHeading>().single.text, 'Title');
      expect(b.whereType<MdParagraph>().single.text, 'Hello **you**');
      final items = b.whereType<MdListItem>().toList();
      expect(items.map((e) => e.marker), ['•', '•', '1.', '2.']);
      expect(b.whereType<MdRule>().length, 1);
    });

    test('table with separator row', () {
      final b = parseMarkdown('| Cat | Limit |\n|---|---:|\n| Food | 5000 |\n| Rent | 22000 |');
      final t = b.whereType<MdTable>().single;
      expect(t.header, ['Cat', 'Limit']);
      expect(t.rows, [
        ['Food', '5000'],
        ['Rent', '22000']
      ]);
    });

    test('code fence and quote', () {
      final b = parseMarkdown('> note one\n> note two\n\n```\nx = 1\n```');
      expect(b.whereType<MdQuote>().single.text, 'note one\nnote two');
      expect(b.whereType<MdCode>().single.text, 'x = 1');
    });

    test('a line that starts with bold is a paragraph, not a list', () {
      final b = parseMarkdown('**Summary** of spending');
      expect(b.single, isA<MdParagraph>());
    });
  });

  group('rendering never shows markdown symbols', () {
    testWidgets('bold and italic', (tester) async {
      final text = plain(await render(tester, 'You saved **₹25,900** this month, *nice* work and ***wow***.'));
      expect(text, 'You saved ₹25,900 this month, nice work and wow.');
    });

    testWidgets('headings are bold and lose the hashes', (tester) async {
      final rts = await render(tester, '## Your plan\n\nDo this.');
      expect(plain(rts), isNot(contains('#')));
      final heading = rts.firstWhere((r) => r.text.toPlainText() == 'Your plan');
      expect(((heading.text as TextSpan).children!.first as TextSpan).style!.fontWeight, FontWeight.w800);
    });

    testWidgets('bullets and numbers', (tester) async {
      final text = plain(await render(tester, '- **Rent** is 41%\n- Food is 8%\n\n1. First\n2. Second'));
      expect(text, contains('Rent is 41%'));
      expect(text, contains('•'));
      expect(text, contains('1.'));
      expect(text, isNot(contains('**')));
      expect(text, isNot(contains('- ')));
    });

    testWidgets('table cells', (tester) async {
      final text = plain(await render(tester, '| **Item** | Cost |\n|---|---|\n| Food | 5000 |'));
      expect(text, contains('Item'));
      expect(text, contains('5000'));
      expect(text, isNot(contains('|')));
      expect(text, isNot(contains('---')));
    });

    testWidgets('code, links and strike', (tester) async {
      final text = plain(await render(tester, 'Use `SIP` and [read more](https://example.com) ~~old~~'));
      expect(text, 'Use SIP and read more old');
    });

    testWidgets('snake_case and math are left alone', (tester) async {
      final text = plain(await render(tester, 'Set my_var_name = 2*3 and 5 * 4'));
      expect(text, 'Set my_var_name = 2*3 and 5 * 4');
    });

    testWidgets('unclosed markers stay literal, escapes work', (tester) async {
      final text = plain(await render(tester, 'Cost **unclosed and \\*literal\\*'));
      expect(text, 'Cost **unclosed and *literal*');
    });
  });
}
