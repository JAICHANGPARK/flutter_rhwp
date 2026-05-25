import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_rhwp/flutter_rhwp.dart';
import 'package:flutter_rhwp/src/rust/api/rhwp.dart' as rust;
import 'package:flutter_rhwp/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insert text command serializes to the Rust command envelope', () {
    final command = RhwpCommand.insertText(
      section: 0,
      paragraph: 1,
      offset: 2,
      text: 'hello',
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'text': 'hello',
    });
  });

  test('split paragraph command serializes to the Rust command envelope', () {
    final command = RhwpCommand.splitParagraph(
      section: 0,
      paragraph: 1,
      offset: 2,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'splitParagraph',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
    });
  });

  test('insert page break command serializes to the Rust command envelope', () {
    final command = RhwpCommand.insertPageBreak(
      section: 0,
      paragraph: 1,
      offset: 2,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'insertPageBreak',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
    });
  });

  test(
    'insert column break command serializes to the Rust command envelope',
    () {
      final command = RhwpCommand.insertColumnBreak(
        section: 0,
        paragraph: 1,
        offset: 2,
      );

      expect(jsonDecode(jsonEncode(command.toJson())), {
        'type': 'insertColumnBreak',
        'section': 0,
        'paragraph': 1,
        'offset': 2,
      });
    },
  );

  test('insert footnote command serializes to the Rust command envelope', () {
    final command = RhwpCommand.insertFootnote(
      section: 0,
      paragraph: 1,
      offset: 2,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'insertFootnote',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
    });
  });

  test('insert equation command serializes to the Rust command envelope', () {
    final command = RhwpCommand.insertEquation(
      section: 0,
      paragraph: 1,
      offset: 2,
      script: 'x^2 + y^2',
      fontSize: 1200,
      color: 0x2563eb,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'insertEquation',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'script': 'x^2 + y^2',
      'fontSize': 1200,
      'color': 0x2563eb,
    });
  });

  test('insert picture command serializes to the Rust command envelope', () {
    final command = RhwpCommand.insertPicture(
      section: 0,
      paragraph: 1,
      offset: 2,
      imageData: Uint8List.fromList([1, 2, 3]),
      width: 750,
      height: 1500,
      naturalWidthPx: 10,
      naturalHeightPx: 20,
      extension: 'png',
      description: 'sample.png',
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'insertPicture',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'imageData': [1, 2, 3],
      'width': 750,
      'height': 1500,
      'naturalWidthPx': 10,
      'naturalHeightPx': 20,
      'extension': 'png',
      'description': 'sample.png',
    });
  });

  test('insert table command serializes to the Rust command envelope', () {
    final command = RhwpCommand.insertTable(
      section: 0,
      paragraph: 1,
      offset: 2,
      rows: 3,
      columns: 4,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'insertTable',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'rows': 3,
      'columns': 4,
    });
  });

  test('table row and column commands serialize to Rust envelopes', () {
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.insertTableRow(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            row: 3,
            below: true,
          ).toJson(),
        ),
      ),
      {
        'type': 'insertTableRow',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'row': 3,
        'below': true,
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.insertTableColumn(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            column: 4,
            right: true,
          ).toJson(),
        ),
      ),
      {
        'type': 'insertTableColumn',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'column': 4,
        'right': true,
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.deleteTableRow(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            row: 3,
          ).toJson(),
        ),
      ),
      {
        'type': 'deleteTableRow',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'row': 3,
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.deleteTableColumn(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            column: 4,
          ).toJson(),
        ),
      ),
      {
        'type': 'deleteTableColumn',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'column': 4,
      },
    );
  });

  test('table cell commands serialize to Rust envelopes', () {
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.insertTextInTableCell(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            cellIndex: 3,
            cellParagraph: 0,
            offset: 4,
            text: 'cell',
          ).toJson(),
        ),
      ),
      {
        'type': 'insertTextInTableCell',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'cellIndex': 3,
        'cellParagraph': 0,
        'offset': 4,
        'text': 'cell',
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.deleteTextInTableCell(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            cellIndex: 3,
            cellParagraph: 0,
            offset: 4,
            count: 1,
          ).toJson(),
        ),
      ),
      {
        'type': 'deleteTextInTableCell',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'cellIndex': 3,
        'cellParagraph': 0,
        'offset': 4,
        'count': 1,
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.applyCharFormatInTableCell(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            cellIndex: 3,
            cellParagraph: 0,
            startOffset: 1,
            endOffset: 4,
            bold: true,
            fontSize: 1100,
            textColor: '#2563eb',
          ).toJson(),
        ),
      ),
      {
        'type': 'applyCharFormatInTableCell',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'cellIndex': 3,
        'cellParagraph': 0,
        'startOffset': 1,
        'endOffset': 4,
        'properties': {'bold': true, 'fontSize': 1100, 'textColor': '#2563eb'},
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.applyTableCellStyle(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            cellIndex: 3,
            fillColor: '#fef08a',
            borderColor: '#475569',
            verticalAlign: 1,
          ).toJson(),
        ),
      ),
      {
        'type': 'applyTableCellStyle',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'cellIndex': 3,
        'properties': {
          'fillType': 'solid',
          'fillColor': '#fef08a',
          'borderLeft': {'type': 1, 'width': 1, 'color': '#475569'},
          'borderRight': {'type': 1, 'width': 1, 'color': '#475569'},
          'borderTop': {'type': 1, 'width': 1, 'color': '#475569'},
          'borderBottom': {'type': 1, 'width': 1, 'color': '#475569'},
          'verticalAlign': 1,
        },
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.mergeTableCells(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            startRow: 0,
            startColumn: 0,
            endRow: 1,
            endColumn: 1,
          ).toJson(),
        ),
      ),
      {
        'type': 'mergeTableCells',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'startRow': 0,
        'startColumn': 0,
        'endRow': 1,
        'endColumn': 1,
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.splitTableCell(
            section: 0,
            paragraph: 1,
            controlIndex: 2,
            row: 0,
            column: 0,
          ).toJson(),
        ),
      ),
      {
        'type': 'splitTableCell',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'row': 0,
        'column': 0,
      },
    );
  });

  test('object control commands serialize to Rust envelopes', () {
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.deleteObjectControl(
            section: 0,
            paragraph: 2,
            controlIndex: 4,
            objectType: 'shape',
          ).toJson(),
        ),
      ),
      {
        'type': 'deleteObjectControl',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 4,
        'objectType': 'shape',
      },
    );

    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.changeObjectZOrder(
            section: 0,
            paragraph: 2,
            controlIndex: 4,
            objectType: 'shape',
            operation: RhwpObjectZOrderOperation.forward,
          ).toJson(),
        ),
      ),
      {
        'type': 'changeObjectZOrder',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 4,
        'objectType': 'shape',
        'operation': 'forward',
      },
    );

    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.getObjectProperties(
            section: 0,
            paragraph: 2,
            controlIndex: 4,
            objectType: 'shape',
          ).toJson(),
        ),
      ),
      {
        'type': 'getObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 4,
        'objectType': 'shape',
      },
    );

    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.setObjectProperties(
            section: 0,
            paragraph: 2,
            controlIndex: 4,
            objectType: 'shape',
            width: 1200,
            height: 2400,
            horzOffset: 80,
            vertOffset: 90,
          ).toJson(),
        ),
      ),
      {
        'type': 'setObjectProperties',
        'section': 0,
        'paragraph': 2,
        'controlIndex': 4,
        'objectType': 'shape',
        'properties': {
          'width': 1200,
          'height': 2400,
          'horzOffset': 80,
          'vertOffset': 90,
        },
      },
    );
  });

  test('delete range command serializes to the Rust command envelope', () {
    final command = RhwpCommand.deleteRange(
      section: 0,
      startParagraph: 1,
      startOffset: 2,
      endParagraph: 3,
      endOffset: 4,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'deleteRange',
      'section': 0,
      'startParagraph': 1,
      'startOffset': 2,
      'endParagraph': 3,
      'endOffset': 4,
    });
  });

  test('apply char format command serializes to the Rust command envelope', () {
    final command = RhwpCommand.applyCharFormat(
      section: 0,
      paragraph: 1,
      startOffset: 2,
      endOffset: 4,
      bold: true,
      italic: true,
      underline: true,
      strikethrough: true,
      fontSize: 1250,
      textColor: '#dc2626',
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'applyCharFormat',
      'section': 0,
      'paragraph': 1,
      'startOffset': 2,
      'endOffset': 4,
      'properties': {
        'bold': true,
        'italic': true,
        'underline': true,
        'strikethrough': true,
        'fontSize': 1250,
        'textColor': '#dc2626',
      },
    });
  });

  test(
    'apply char format range command serializes to the Rust command envelope',
    () {
      final command = RhwpCommand.applyCharFormatRange(
        section: 0,
        startParagraph: 1,
        startOffset: 2,
        endParagraph: 3,
        endOffset: 4,
        bold: true,
        strikethrough: true,
        fontSize: 1100,
        textColor: '#2563eb',
      );

      expect(jsonDecode(jsonEncode(command.toJson())), {
        'type': 'applyCharFormatRange',
        'section': 0,
        'startParagraph': 1,
        'startOffset': 2,
        'endParagraph': 3,
        'endOffset': 4,
        'properties': {
          'bold': true,
          'strikethrough': true,
          'fontSize': 1100,
          'textColor': '#2563eb',
        },
      });
    },
  );

  test('apply para format command serializes to the Rust command envelope', () {
    final command = RhwpCommand.applyParaFormat(
      section: 0,
      paragraph: 1,
      alignment: 'center',
      lineSpacing: 180,
      lineSpacingType: 'Percent',
      indent: 120,
      marginLeft: 300,
      marginRight: 400,
      spacingBefore: 50,
      spacingAfter: 60,
    );

    expect(jsonDecode(jsonEncode(command.toJson())), {
      'type': 'applyParaFormat',
      'section': 0,
      'paragraph': 1,
      'properties': {
        'alignment': 'center',
        'lineSpacing': 180,
        'lineSpacingType': 'Percent',
        'indent': 120,
        'marginLeft': 300,
        'marginRight': 400,
        'spacingBefore': 50,
        'spacingAfter': 60,
      },
    });
  });

  test(
    'apply para format range command serializes to the Rust command envelope',
    () {
      final command = RhwpCommand.applyParaFormatRange(
        section: 0,
        startParagraph: 1,
        endParagraph: 3,
        alignment: 'right',
        lineSpacing: 200,
        lineSpacingType: 'Fixed',
        indent: -40,
        marginLeft: 100,
        marginRight: 200,
        spacingBefore: 10,
        spacingAfter: 20,
      );

      expect(jsonDecode(jsonEncode(command.toJson())), {
        'type': 'applyParaFormatRange',
        'section': 0,
        'startParagraph': 1,
        'endParagraph': 3,
        'properties': {
          'alignment': 'right',
          'lineSpacing': 200,
          'lineSpacingType': 'Fixed',
          'indent': -40,
          'marginLeft': 100,
          'marginRight': 200,
          'spacingBefore': 10,
          'spacingAfter': 20,
        },
      });
    },
  );

  test(
    'apply para format in table cell command serializes to the Rust command envelope',
    () {
      final command = RhwpCommand.applyParaFormatInTableCell(
        section: 0,
        paragraph: 1,
        controlIndex: 2,
        cellIndex: 3,
        cellParagraph: 0,
        alignment: 'center',
        lineSpacing: 180,
        lineSpacingType: 'Percent',
        indent: 120,
        marginLeft: 300,
        marginRight: 400,
        spacingBefore: 50,
        spacingAfter: 60,
      );

      expect(jsonDecode(jsonEncode(command.toJson())), {
        'type': 'applyParaFormatInTableCell',
        'section': 0,
        'paragraph': 1,
        'controlIndex': 2,
        'cellIndex': 3,
        'cellParagraph': 0,
        'properties': {
          'alignment': 'center',
          'lineSpacing': 180,
          'lineSpacingType': 'Percent',
          'indent': 120,
          'marginLeft': 300,
          'marginRight': 400,
          'spacingBefore': 50,
          'spacingAfter': 60,
        },
      });
    },
  );

  test('create header and footer commands serialize to the Rust envelope', () {
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.createHeaderFooter(
            section: 1,
            isHeader: true,
            applyTo: 2,
          ).toJson(),
        ),
      ),
      {
        'type': 'createHeaderFooter',
        'section': 1,
        'isHeader': true,
        'applyTo': 2,
      },
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.createHeaderFooter(section: 0, isHeader: false).toJson(),
        ),
      ),
      {
        'type': 'createHeaderFooter',
        'section': 0,
        'isHeader': false,
        'applyTo': 0,
      },
    );
  });

  test('page setup commands serialize to the Rust envelope', () {
    expect(
      jsonDecode(jsonEncode(RhwpCommand.getPageSetup(section: 1).toJson())),
      {'type': 'getPageSetup', 'section': 1},
    );
    expect(
      jsonDecode(
        jsonEncode(
          RhwpCommand.setPageSetup(
            section: 1,
            width: 59528,
            height: 84189,
            marginLeft: 8504,
            marginRight: 8504,
            marginTop: 5669,
            marginBottom: 4252,
            marginHeader: 4252,
            marginFooter: 4252,
            marginGutter: 0,
            landscape: true,
            binding: 1,
          ).toJson(),
        ),
      ),
      {
        'type': 'setPageSetup',
        'section': 1,
        'properties': {
          'width': 59528,
          'height': 84189,
          'marginLeft': 8504,
          'marginRight': 8504,
          'marginTop': 5669,
          'marginBottom': 4252,
          'marginHeader': 4252,
          'marginFooter': 4252,
          'marginGutter': 0,
          'landscape': true,
          'binding': 1,
        },
      },
    );
  });

  test('snapshot commands serialize to the Rust command envelope', () {
    expect(jsonDecode(jsonEncode(RhwpCommand.saveSnapshot().toJson())), {
      'type': 'saveSnapshot',
    });
    expect(jsonDecode(jsonEncode(RhwpCommand.restoreSnapshot(7).toJson())), {
      'type': 'restoreSnapshot',
      'snapshotId': 7,
    });
    expect(jsonDecode(jsonEncode(RhwpCommand.discardSnapshot(8).toJson())), {
      'type': 'discardSnapshot',
      'snapshotId': 8,
    });
  });

  test('closed exception has a stable message', () {
    expect(
      const RhwpClosedException().toString(),
      'RhwpException: The rhwp document is already closed.',
    );
  });

  test('Web editor controller reports unsupported off Web', () {
    final controller = RhwpWebEditorController();
    addTearDown(controller.dispose);

    expect(controller.isAttached, isFalse);
    expect(
      controller.exportHwp(),
      throwsA(isA<RhwpUnsupportedPlatformException>()),
    );
    expect(
      controller.exportDocument(RhwpExportFormat.hwp),
      throwsA(isA<RhwpUnsupportedPlatformException>()),
    );
  });

  test('generated FRB bridge can call a mock Rust API', () async {
    final api = _FakeRustLibApi();
    RustLib.initMock(api: api);
    addTearDown(RustLib.dispose);

    expect(await rust.rhwpVersion(), 'mock-rhwp');
    expect(api.versionCalls, 1);
  });

  test('document convenience edit methods use command envelopes', () async {
    final session = _FakeRhwpSession();
    final document = RhwpDocument.fromSession(session);

    await document.insertText(
      section: 0,
      paragraph: 1,
      offset: 2,
      text: 'hello',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertText',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'text': 'hello',
    });

    await document.deleteText(section: 0, paragraph: 1, offset: 2, count: 3);

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'deleteText',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'count': 3,
    });

    await document.deleteRange(
      section: 0,
      startParagraph: 1,
      startOffset: 2,
      endParagraph: 3,
      endOffset: 4,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'deleteRange',
      'section': 0,
      'startParagraph': 1,
      'startOffset': 2,
      'endParagraph': 3,
      'endOffset': 4,
    });

    await document.applyCharFormat(
      section: 0,
      paragraph: 1,
      startOffset: 2,
      endOffset: 4,
      bold: true,
      fontSize: 1200,
      textColor: '#16a34a',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyCharFormat',
      'section': 0,
      'paragraph': 1,
      'startOffset': 2,
      'endOffset': 4,
      'properties': {'bold': true, 'fontSize': 1200, 'textColor': '#16a34a'},
    });

    await document.applyCharFormatRange(
      section: 0,
      startParagraph: 1,
      startOffset: 2,
      endParagraph: 3,
      endOffset: 4,
      italic: true,
      strikethrough: true,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyCharFormatRange',
      'section': 0,
      'startParagraph': 1,
      'startOffset': 2,
      'endParagraph': 3,
      'endOffset': 4,
      'properties': {'italic': true, 'strikethrough': true},
    });

    await document.applyParaFormat(
      section: 0,
      paragraph: 1,
      alignment: 'center',
      lineSpacing: 180,
      lineSpacingType: 'Percent',
      indent: 120,
      marginLeft: 300,
      marginRight: 400,
      spacingBefore: 50,
      spacingAfter: 60,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyParaFormat',
      'section': 0,
      'paragraph': 1,
      'properties': {
        'alignment': 'center',
        'lineSpacing': 180,
        'lineSpacingType': 'Percent',
        'indent': 120,
        'marginLeft': 300,
        'marginRight': 400,
        'spacingBefore': 50,
        'spacingAfter': 60,
      },
    });

    await document.applyParaFormatRange(
      section: 0,
      startParagraph: 1,
      endParagraph: 3,
      alignment: 'right',
      lineSpacing: 200,
      lineSpacingType: 'Fixed',
      indent: -40,
      marginLeft: 100,
      marginRight: 200,
      spacingBefore: 10,
      spacingAfter: 20,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyParaFormatRange',
      'section': 0,
      'startParagraph': 1,
      'endParagraph': 3,
      'properties': {
        'alignment': 'right',
        'lineSpacing': 200,
        'lineSpacingType': 'Fixed',
        'indent': -40,
        'marginLeft': 100,
        'marginRight': 200,
        'spacingBefore': 10,
        'spacingAfter': 20,
      },
    });

    await document.applyParaFormatInTableCell(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      cellIndex: 2,
      cellParagraph: 0,
      alignment: 'center',
      lineSpacing: 180,
      lineSpacingType: 'Percent',
      indent: 120,
      marginLeft: 300,
      marginRight: 400,
      spacingBefore: 50,
      spacingAfter: 60,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyParaFormatInTableCell',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'cellIndex': 2,
      'cellParagraph': 0,
      'properties': {
        'alignment': 'center',
        'lineSpacing': 180,
        'lineSpacingType': 'Percent',
        'indent': 120,
        'marginLeft': 300,
        'marginRight': 400,
        'spacingBefore': 50,
        'spacingAfter': 60,
      },
    });

    await document.splitParagraph(section: 0, paragraph: 1, offset: 2);

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'splitParagraph',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
    });

    await document.insertPageBreak(section: 0, paragraph: 1, offset: 2);

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertPageBreak',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
    });

    await document.insertColumnBreak(section: 0, paragraph: 1, offset: 2);

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertColumnBreak',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
    });

    await document.insertFootnote(section: 0, paragraph: 1, offset: 2);

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertFootnote',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
    });

    await document.insertEquation(
      section: 0,
      paragraph: 1,
      offset: 2,
      script: 'x^2 + y^2',
      fontSize: 1200,
      color: 0x2563eb,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertEquation',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'script': 'x^2 + y^2',
      'fontSize': 1200,
      'color': 0x2563eb,
    });

    await document.insertPicture(
      section: 0,
      paragraph: 1,
      offset: 2,
      imageData: Uint8List.fromList([1, 2, 3]),
      width: 750,
      height: 1500,
      naturalWidthPx: 10,
      naturalHeightPx: 20,
      extension: 'png',
      description: 'sample.png',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertPicture',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'imageData': [1, 2, 3],
      'width': 750,
      'height': 1500,
      'naturalWidthPx': 10,
      'naturalHeightPx': 20,
      'extension': 'png',
      'description': 'sample.png',
    });

    await document.insertShape(
      section: 0,
      paragraph: 1,
      offset: 2,
      width: 9000,
      height: 6750,
      horzOffset: 0,
      vertOffset: 0,
      shapeType: 'rectangle',
      treatAsChar: false,
      textWrap: 'InFrontOfText',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertShape',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'width': 9000,
      'height': 6750,
      'horzOffset': 0,
      'vertOffset': 0,
      'shapeType': 'rectangle',
      'treatAsChar': false,
      'textWrap': 'InFrontOfText',
      'lineFlipX': false,
      'lineFlipY': false,
    });

    await document.insertShape(
      section: 0,
      paragraph: 1,
      offset: 10,
      width: 12000,
      height: 6000,
      shapeType: 'textbox',
      treatAsChar: true,
      textWrap: 'Square',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertShape',
      'section': 0,
      'paragraph': 1,
      'offset': 10,
      'width': 12000,
      'height': 6000,
      'horzOffset': 0,
      'vertOffset': 0,
      'shapeType': 'textbox',
      'treatAsChar': true,
      'textWrap': 'Square',
      'lineFlipX': false,
      'lineFlipY': false,
    });

    await document.insertTable(
      section: 0,
      paragraph: 1,
      offset: 2,
      rows: 3,
      columns: 4,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertTable',
      'section': 0,
      'paragraph': 1,
      'offset': 2,
      'rows': 3,
      'columns': 4,
    });

    await document.insertTextInTableCell(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      cellIndex: 2,
      cellParagraph: 0,
      offset: 2,
      text: 'cell',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertTextInTableCell',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'cellIndex': 2,
      'cellParagraph': 0,
      'offset': 2,
      'text': 'cell',
    });

    await document.deleteTextInTableCell(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      cellIndex: 2,
      cellParagraph: 0,
      offset: 2,
      count: 1,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'deleteTextInTableCell',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'cellIndex': 2,
      'cellParagraph': 0,
      'offset': 2,
      'count': 1,
    });

    await document.applyCharFormatInTableCell(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      cellIndex: 2,
      cellParagraph: 0,
      startOffset: 0,
      endOffset: 4,
      bold: true,
      fontSize: 1100,
      textColor: '#2563eb',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyCharFormatInTableCell',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'cellIndex': 2,
      'cellParagraph': 0,
      'startOffset': 0,
      'endOffset': 4,
      'properties': {'bold': true, 'fontSize': 1100, 'textColor': '#2563eb'},
    });

    await document.applyTableCellStyle(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      cellIndex: 2,
      fillColor: '#dbeafe',
      borderColor: '#475569',
      verticalAlign: 2,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'applyTableCellStyle',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'cellIndex': 2,
      'properties': {
        'fillType': 'solid',
        'fillColor': '#dbeafe',
        'borderLeft': {'type': 1, 'width': 1, 'color': '#475569'},
        'borderRight': {'type': 1, 'width': 1, 'color': '#475569'},
        'borderTop': {'type': 1, 'width': 1, 'color': '#475569'},
        'borderBottom': {'type': 1, 'width': 1, 'color': '#475569'},
        'verticalAlign': 2,
      },
    });

    await document.insertTableRow(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      row: 2,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertTableRow',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'row': 2,
      'below': true,
    });

    await document.insertTableColumn(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      column: 2,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'insertTableColumn',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'column': 2,
      'right': true,
    });

    await document.deleteTableRow(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      row: 2,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'deleteTableRow',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'row': 2,
    });

    await document.deleteTableColumn(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      column: 2,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'deleteTableColumn',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'column': 2,
    });

    await document.mergeTableCells(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      startRow: 0,
      startColumn: 0,
      endRow: 1,
      endColumn: 1,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'mergeTableCells',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'startRow': 0,
      'startColumn': 0,
      'endRow': 1,
      'endColumn': 1,
    });

    await document.splitTableCell(
      section: 0,
      paragraph: 1,
      controlIndex: 0,
      row: 0,
      column: 0,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'splitTableCell',
      'section': 0,
      'paragraph': 1,
      'controlIndex': 0,
      'row': 0,
      'column': 0,
    });

    await document.deleteObjectControl(
      section: 0,
      paragraph: 2,
      controlIndex: 1,
      objectType: 'shape',
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'deleteObjectControl',
      'section': 0,
      'paragraph': 2,
      'controlIndex': 1,
      'objectType': 'shape',
    });

    await document.changeObjectZOrder(
      section: 0,
      paragraph: 2,
      controlIndex: 1,
      objectType: 'shape',
      operation: RhwpObjectZOrderOperation.front,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'changeObjectZOrder',
      'section': 0,
      'paragraph': 2,
      'controlIndex': 1,
      'objectType': 'shape',
      'operation': 'front',
    });

    final objectProperties = await document.objectProperties(
      section: 0,
      paragraph: 2,
      controlIndex: 1,
      objectType: 'shape',
    );

    expect(objectProperties.width, 1000);
    expect(objectProperties.height, 2000);
    expect(objectProperties.horzOffset, 30);
    expect(objectProperties.vertOffset, 40);
    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'getObjectProperties',
      'section': 0,
      'paragraph': 2,
      'controlIndex': 1,
      'objectType': 'shape',
    });

    await document.setObjectProperties(
      section: 0,
      paragraph: 2,
      controlIndex: 1,
      objectType: 'shape',
      width: 1200,
      height: 2400,
      horzOffset: 80,
      vertOffset: 90,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'setObjectProperties',
      'section': 0,
      'paragraph': 2,
      'controlIndex': 1,
      'objectType': 'shape',
      'properties': {
        'width': 1200,
        'height': 2400,
        'horzOffset': 80,
        'vertOffset': 90,
      },
    });

    final pageSetup = await document.pageSetup(section: 0);
    expect(pageSetup.width, 59528);
    expect(pageSetup.height, 84189);
    expect(pageSetup.marginLeft, 8504);
    expect(pageSetup.landscape, isFalse);
    expect(pageSetup.binding, 0);
    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'getPageSetup',
      'section': 0,
    });

    await document.setPageSetup(
      section: 0,
      width: 56693,
      height: 85040,
      marginLeft: 2835,
      marginRight: 2835,
      marginTop: 4252,
      marginBottom: 4252,
      marginHeader: 2835,
      marginFooter: 2835,
      marginGutter: 0,
      landscape: true,
      binding: 1,
    );

    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'setPageSetup',
      'section': 0,
      'properties': {
        'width': 56693,
        'height': 85040,
        'marginLeft': 2835,
        'marginRight': 2835,
        'marginTop': 4252,
        'marginBottom': 4252,
        'marginHeader': 2835,
        'marginFooter': 2835,
        'marginGutter': 0,
        'landscape': true,
        'binding': 1,
      },
    });

    expect(await document.saveSnapshot(), 1);
    expect(jsonDecode(session.lastCommandJson!), {'type': 'saveSnapshot'});

    await document.restoreSnapshot(1);
    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'restoreSnapshot',
      'snapshotId': 1,
    });

    await document.discardSnapshot(1);
    expect(jsonDecode(session.lastCommandJson!), {
      'type': 'discardSnapshot',
      'snapshotId': 1,
    });
  });

  test('document export helpers forward supported formats', () async {
    final session = _FakeRhwpSession();
    final document = RhwpDocument.fromSession(session);

    expect(await document.exportHwp(), [0x48, 0x57, 0x50]);
    expect(await document.exportHwpx(), [0x48, 0x57, 0x50, 0x58]);
    expect(await document.exportPdf(), [0x50, 0x44, 0x46]);
    expect(await document.exportDocx(), [0x44, 0x4f, 0x43, 0x58]);
    expect(utf8.decode(await document.exportText(page: 2)), 'text page 2');
    expect(utf8.decode(await document.exportMarkdown(page: 3)), '# page 3');
    expect(
      utf8.decode(await document.exportPageSvg(page: 4)),
      '<svg data-page="4"/>',
    );

    expect(session.exportHwpCalls, 1);
    expect(session.exportHwpxCalls, 1);
    expect(session.exportPdfCalls, 1);
    expect(session.exportDocxCalls, 1);
    expect(session.extractedTextPages, [2]);
    expect(session.extractedMarkdownPages, [3]);
    expect(session.renderedSvgPages, [4]);
  });

  test('export formats expose save metadata', () {
    expect(RhwpExportFormat.hwp.fileExtension, 'hwp');
    expect(RhwpExportFormat.hwpx.mimeType, 'application/vnd.hancom.hwpx');
    expect(RhwpExportFormat.pdf.mimeType, 'application/pdf');
    expect(
      RhwpExportFormat.docx.mimeType,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(RhwpExportFormat.text.fileExtension, 'txt');
    expect(RhwpExportFormat.markdown.fileExtension, 'md');
    expect(RhwpExportFormat.svg.mimeType, 'image/svg+xml');
  });

  test('document exportDocument returns bytes with save metadata', () async {
    final session = _FakeRhwpSession();
    session.fileName = '/tmp/source/sample.hwp';
    final document = RhwpDocument.fromSession(session);

    final pdf = await document.exportDocument(RhwpExportFormat.pdf);

    expect(pdf.format, RhwpExportFormat.pdf);
    expect(pdf.bytes, [0x50, 0x44, 0x46]);
    expect(pdf.fileName, 'sample.pdf');
    expect(pdf.mimeType, 'application/pdf');

    final svg = await document.exportDocument(
      RhwpExportFormat.svg,
      sourceFileName: 'picked.hwpx',
      page: 2,
    );

    expect(utf8.decode(svg.bytes), '<svg data-page="2"/>');
    expect(svg.fileName, 'picked-page-3.svg');
    expect(svg.mimeType, 'image/svg+xml');
    expect(session.renderedSvgPages, [2]);
  });

  test('exported document default file names are robust', () {
    expect(
      RhwpExportedDocument.defaultFileName(
        format: RhwpExportFormat.markdown,
        sourceFileName: r'C:\docs\report.hwp',
      ),
      'report.md',
    );
    expect(
      RhwpExportedDocument.defaultFileName(format: RhwpExportFormat.text),
      'document.txt',
    );
    expect(
      RhwpExportedDocument.defaultFileName(
        format: RhwpExportFormat.svg,
        sourceFileName: '.hwp',
        page: 0,
      ),
      'document-page-1.svg',
    );
  });

  test('page layer tree model flattens tolerant layer JSON', () {
    final tree = RhwpLayerTree.fromJsonString(
      0,
      jsonEncode({
        'type': 'page',
        'children': [
          {
            'kind': 'paragraph',
            'runs': [
              {
                'type': 'span',
                'text': 'Hello',
                'bounds': {'x': 12, 'y': 34, 'width': 56, 'height': 78},
              },
            ],
          },
          {
            'type': 'shape',
            'rect': {'left': 1, 'top': 2, 'right': 11, 'bottom': 22},
          },
        ],
      }),
    );

    expect(tree.page, 0);
    expect(tree.root.type, 'page');
    expect(tree.nodes.map((node) => node.type), [
      'page',
      'paragraph',
      'span',
      'shape',
    ]);
    expect(tree.textNodes.single.text, 'Hello');
    expect(tree.textNodes.single.bounds, const Rect.fromLTWH(12, 34, 56, 78));
    expect(
      tree.findByType('shape').single.bounds,
      const Rect.fromLTRB(1, 2, 11, 22),
    );
    expect(tree.objects, hasLength(1));
    expect(tree.objects.single.type, 'shape');
    expect(tree.objectForPoint(const Offset(5, 10)), same(tree.objects.single));
    expect(tree.objectForPoint(const Offset(20, 20)), isNull);
    expect(tree.boundedNodes.length, 2);
  });

  test('document page layer tree helper decodes session JSON', () async {
    final session = _FakeRhwpSession();
    session.pageLayerTreeJson = jsonEncode({
      'type': 'page',
      'nodes': [
        {
          'type': 'text',
          'content': 'from session',
          'bbox': [1, 2, 3, 4],
        },
      ],
    });
    final document = RhwpDocument.fromSession(session);

    final tree = await document.pageLayerTreeModel(5);

    expect(session.pageLayerTreePages, [5]);
    expect(tree.textNodes.single.text, 'from session');
    expect(tree.textNodes.single.bounds, const Rect.fromLTWH(1, 2, 3, 4));
  });

  test('page layer tree model maps text run source offsets to page rects', () {
    final tree = RhwpLayerTree.fromJsonString(
      0,
      jsonEncode(_textRunLayerTreeJson(charStart: 3)),
    );

    final run = tree.textRuns.single;
    expect(tree.pageSize, const Size(240, 180));
    expect(run.section, 0);
    expect(run.paragraph, 0);
    expect(run.charStart, 3);
    expect(run.charEnd, 7);
    expect(run.bounds, const Rect.fromLTWH(20, 30, 60, 12));

    final caret = tree.caretRectFor(section: 0, paragraph: 0, offset: 5);
    expect(caret!.left, closeTo(40, 0.001));
    expect(caret.top, 30);

    final selection = tree.selectionRectsFor(
      section: 0,
      paragraph: 0,
      startOffset: 4,
      endOffset: 7,
    );
    expect(selection.single, const Rect.fromLTRB(30, 30, 60, 42));

    final hit = tree.textPositionForPoint(const Offset(52, 36));
    expect(hit, isNotNull);
    expect(hit!.section, 0);
    expect(hit.paragraph, 0);
    expect(hit.offset, 6);
    expect(
      tree.textPositionForPoint(const Offset(52, 80), verticalTolerance: 2),
      isNull,
    );
  });

  test('page layer tree model maps table cell hit context', () {
    final tree = RhwpLayerTree.fromJsonString(
      0,
      jsonEncode(_tableCellLayerTreeJson()),
    );

    expect(tree.tableCells, hasLength(1));
    final cell = tree.tableCells.single;
    expect(cell.bounds, const Rect.fromLTWH(90, 50, 40, 30));
    expect(cell.section, 0);
    expect(cell.paragraph, 5);
    expect(cell.controlIndex, 2);
    expect(cell.row, 1);
    expect(cell.column, 3);
    expect(cell.rowSpan, 2);
    expect(cell.columnSpan, 1);
    expect(cell.modelCellIndex, 7);
    expect(cell.endRow, 2);
    expect(cell.endColumn, 3);
    expect(tree.tableCellForPoint(const Offset(100, 60)), same(cell));
    expect(tree.tableCellForPoint(const Offset(10, 10)), isNull);
  });

  test('page layer tree model maps table cell text source context', () {
    final tree = RhwpLayerTree.fromJsonString(
      0,
      jsonEncode(_cellTextRunLayerTreeJson()),
    );

    final hit = tree.textPositionForPoint(const Offset(118, 68));

    expect(hit, isNotNull);
    expect(hit!.offset, 3);
    expect(hit.cellContext, isNotNull);
    expect(hit.cellContext!.parentParagraph, 5);
    expect(hit.cellContext!.controlIndex, 2);
    expect(hit.cellContext!.cellIndex, 7);
    expect(hit.cellContext!.cellParagraph, 0);
    expect(hit.cellContext!.textDirection, 0);
  });

  test('page layer tree model maps multi-paragraph selection ranges', () {
    final tree = RhwpLayerTree.fromJsonString(
      0,
      jsonEncode(_multiParagraphLayerTreeJson()),
    );

    final selection = tree.selectionRectsForRange(
      startSection: 0,
      startParagraph: 0,
      startOffset: 2,
      endSection: 0,
      endParagraph: 1,
      endOffset: 2,
    );

    expect(selection, [
      const Rect.fromLTRB(40, 30, 60, 42),
      const Rect.fromLTRB(20, 60, 40, 72),
    ]);

    final text = tree.textForRange(
      startSection: 0,
      startParagraph: 0,
      startOffset: 2,
      endSection: 0,
      endParagraph: 1,
      endOffset: 2,
    );
    expect(text, 'cd\nab');
  });
}

Map<String, Object?> _textRunLayerTreeJson({required int charStart}) {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        {
          'kind': 'leaf',
          'bounds': {'x': 20, 'y': 30, 'width': 60, 'height': 12},
          'ops': [
            {
              'type': 'textRun',
              'bbox': {'x': 20, 'y': 30, 'width': 60, 'height': 12},
              'text': 'abcd',
              'source': {
                'id': 0,
                'utf16Range': {'start': 0, 'end': 4},
                'stableSourceKey': 'section:0/para:0/char:$charStart',
              },
              'placement': {
                'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 20, 'f': 40},
                'baselineY': 0,
              },
              'clusters': [
                _textCluster(0, 1, 0),
                _textCluster(1, 2, 10),
                _textCluster(2, 3, 20),
                _textCluster(3, 4, 30),
              ],
            },
          ],
        },
      ],
    },
    'textSources': [
      {
        'id': 0,
        'text': 'abcd',
        'utf16Range': {'start': 0, 'end': 4},
        'stableSourceKey': 'section:0/para:0/char:$charStart',
        'annotations': [],
      },
    ],
  };
}

Map<String, Object?> _tableCellLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        {
          'kind': 'group',
          'bounds': {'x': 80, 'y': 40, 'width': 100, 'height': 80},
          'groupKind': {
            'kind': 'table',
            'sectionIndex': 0,
            'paraIndex': 5,
            'controlIndex': 2,
            'rowCount': 4,
            'colCount': 5,
          },
          'children': [
            {
              'kind': 'group',
              'bounds': {'x': 90, 'y': 50, 'width': 40, 'height': 30},
              'groupKind': {
                'kind': 'tableCell',
                'row': 1,
                'col': 3,
                'rowSpan': 2,
                'colSpan': 1,
                'modelCellIndex': 7,
              },
            },
          ],
        },
      ],
    },
  };
}

Map<String, Object?> _cellTextRunLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        {
          'kind': 'leaf',
          'bounds': {'x': 90, 'y': 60, 'width': 80, 'height': 16},
          'ops': [
            {
              'type': 'textRun',
              'bbox': {'x': 90, 'y': 60, 'width': 80, 'height': 16},
              'text': 'cell',
              'source': {
                'id': 0,
                'utf16Range': {'start': 0, 'end': 4},
                'stableSourceKey': 'section:0/para:5/char:0/cell:5:2:7:0:0',
              },
              'placement': {
                'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 90, 'f': 72},
                'baselineY': 0,
              },
              'clusters': [
                _textCluster(0, 1, 0),
                _textCluster(1, 2, 10),
                _textCluster(2, 3, 20),
                _textCluster(3, 4, 30),
              ],
            },
          ],
        },
      ],
    },
  };
}

Map<String, Object?> _multiParagraphLayerTreeJson() {
  return {
    'pageWidth': 240,
    'pageHeight': 180,
    'root': {
      'kind': 'group',
      'bounds': {'x': 0, 'y': 0, 'width': 240, 'height': 180},
      'children': [
        _textRunLayerNode(paragraph: 0, y: 30),
        _textRunLayerNode(paragraph: 1, y: 60),
      ],
    },
  };
}

Map<String, Object?> _textRunLayerNode({
  required int paragraph,
  required double y,
}) {
  return {
    'kind': 'leaf',
    'bounds': {'x': 20, 'y': y, 'width': 60, 'height': 12},
    'ops': [
      {
        'type': 'textRun',
        'bbox': {'x': 20, 'y': y, 'width': 60, 'height': 12},
        'text': 'abcd',
        'source': {
          'id': paragraph,
          'utf16Range': {'start': 0, 'end': 4},
          'stableSourceKey': 'section:0/para:$paragraph/char:0',
        },
        'placement': {
          'runToPage': {'a': 1, 'b': 0, 'c': 0, 'd': 1, 'e': 20, 'f': y + 10},
          'baselineY': 0,
        },
        'clusters': [
          _textCluster(0, 1, 0),
          _textCluster(1, 2, 10),
          _textCluster(2, 3, 20),
          _textCluster(3, 4, 30),
        ],
      },
    ],
  };
}

Map<String, Object?> _textCluster(int start, int end, double x) {
  return {
    'textRangeUtf16': {'start': start, 'end': end},
    'origin': {'x': x, 'y': 0},
    'advance': {'dx': 10, 'dy': 0},
  };
}

class _FakeRustLibApi implements RustLibApi {
  int versionCalls = 0;

  @override
  Future<void> crateApiRhwpInitApp() async {}

  @override
  Future<String> crateApiRhwpRhwpVersion() async {
    versionCalls += 1;
    return 'mock-rhwp';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRhwpSession implements rust.RhwpSession {
  String? lastCommandJson;
  String? fileName = 'sample.hwp';
  int exportHwpCalls = 0;
  int exportHwpxCalls = 0;
  int exportPdfCalls = 0;
  int exportDocxCalls = 0;
  final extractedTextPages = <int?>[];
  final extractedMarkdownPages = <int?>[];
  final renderedSvgPages = <int>[];
  final pageLayerTreePages = <int>[];
  String pageLayerTreeJson = '{"type":"page"}';
  int nextSnapshotId = 1;
  bool _disposed = false;

  @override
  Future<String> applyCommand({required String commandJson}) async {
    lastCommandJson = commandJson;
    final command = jsonDecode(commandJson);
    if (command is Map && command['type'] == 'saveSnapshot') {
      final snapshotId = nextSnapshotId;
      nextSnapshotId += 1;
      return '{"ok":true,"snapshotId":$snapshotId}';
    }
    if (command is Map && command['type'] == 'getObjectProperties') {
      return '{"width":1000,"height":2000,"horzOffset":30,"vertOffset":40}';
    }
    if (command is Map && command['type'] == 'getPageSetup') {
      return '{"width":59528,"height":84189,"marginLeft":8504,"marginRight":8504,"marginTop":5669,"marginBottom":4252,"marginHeader":4252,"marginFooter":4252,"marginGutter":0,"landscape":false,"binding":0}';
    }
    return '{"ok":true}';
  }

  @override
  Future<rust.RhwpDocumentInfo> documentInfo() async {
    return rust.RhwpDocumentInfo(
      pageCount: 5,
      sourceFormat: 'hwp',
      fileName: fileName,
      rawJson: '{"pageCount":5}',
    );
  }

  @override
  Future<Uint8List> exportDocx() async {
    exportDocxCalls += 1;
    return Uint8List.fromList([0x44, 0x4f, 0x43, 0x58]);
  }

  @override
  Future<Uint8List> exportHwp() async {
    exportHwpCalls += 1;
    return Uint8List.fromList([0x48, 0x57, 0x50]);
  }

  @override
  Future<Uint8List> exportHwpx() async {
    exportHwpxCalls += 1;
    return Uint8List.fromList([0x48, 0x57, 0x50, 0x58]);
  }

  @override
  Future<Uint8List> exportPdf() async {
    exportPdfCalls += 1;
    return Uint8List.fromList([0x50, 0x44, 0x46]);
  }

  @override
  Future<String> extractText({int? page}) async {
    extractedTextPages.add(page);
    return 'text page ${page ?? 'all'}';
  }

  @override
  Future<String> extractMarkdown({int? page}) async {
    extractedMarkdownPages.add(page);
    return '# page ${page ?? 'all'}';
  }

  @override
  Future<String> renderPageSvg({required int page}) async {
    renderedSvgPages.add(page);
    return '<svg data-page="$page"/>';
  }

  @override
  Future<String> pageLayerTree({required int page}) async {
    pageLayerTreePages.add(page);
    return pageLayerTreeJson;
  }

  @override
  Future<int> pageCount() async => 5;

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
