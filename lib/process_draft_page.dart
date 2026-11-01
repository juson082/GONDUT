import 'package:flutter/material.dart';

import 'local_ai.dart';
import 'store.dart';
import 'app_strings.dart';

/// A draft is never applied until the user reviews and explicitly accepts it.
class ProcessDraftPage extends StatefulWidget {
  const ProcessDraftPage(
      {super.key,
      required this.store,
      required this.memoId,
      required this.source,
      required this.items});
  final Store store;
  final int memoId;
  final String source;
  final List<Map<String, String>> items;

  @override
  State<ProcessDraftPage> createState() => _ProcessDraftPageState();
}

class _DraftItem {
  _DraftItem(Map<String, String> item)
      : kind = item['kind']!,
        original = item['quote']!,
        controller = TextEditingController(text: item['quote']);
  String kind;
  final String original;
  final TextEditingController controller;
}

class _ProcessDraftPageState extends State<ProcessDraftPage> {
  late final List<_DraftItem> items = widget.items.map(_DraftItem.new).toList();
  final List<_DraftItem> removed = [];
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final item in [...items, ...removed]) {
      item.controller.dispose();
    }
    super.dispose();
  }

  Future<void> apply() async {
    final reviewed = <Map<String, String>>[];
    for (final item in items) {
      final text = item.controller.text.trim();
      if (text.isEmpty || text.length > 200) {
        setState(() => error = tr(context, '각 항목을 1~200자로 입력하거나 삭제해 주세요.'));
        return;
      }
      reviewed.add({'kind': item.kind, 'quote': text});
    }
    if (reviewed.isEmpty) {
      setState(() => error = tr(context, '추가할 항목이 없습니다.'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final added = await widget.store.appendReviewedProcessDraft(
          widget.memoId, widget.source, reviewed, categoryNames: {
        for (final label in processDraftLabels) label: tr(context, label)
      });
      if (!mounted) return;
      if (!added) {
        setState(() {
          saving = false;
          error =
              tr(context, '메모가 바뀌었거나 삭제되어 적용하지 않았습니다. 메모를 확인한 뒤 다시 생성해 주세요.');
        });
        return;
      }
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          saving = false;
          error = tr(context, '초안을 저장하지 못했습니다. 기존 메모와 가지는 그대로입니다.');
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !saving,
        child: Scaffold(
          appBar: AppBar(title: Text(tr(context, '과정 초안 확인'))),
          body: ListView(padding: EdgeInsets.all(20), children: [
            Text(tr(context, 'AI가 찾은 과정을 확인해 주세요'),
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            Text(tr(context,
                'AI가 종류를 잘못 판단할 수 있습니다. 예측과 실제 결과를 구분해 확인하고, 필요하면 수정하거나 삭제해 주세요. 기존 가지는 그대로 유지됩니다.')),
            ExpansionTile(title: Text(tr(context, '원문 보기')), children: [
              Padding(
                  padding: EdgeInsets.all(12),
                  child: SelectableText(widget.source)),
            ]),
            for (var i = 0; i < items.length; i++)
              Card(
                  key: ObjectKey(items[i]),
                  child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: DropdownButtonFormField<String>(
                                initialValue: items[i].kind,
                                decoration: InputDecoration(
                                    labelText: tr(context, '과정 종류')),
                                items: [
                                  for (final label in processDraftLabels)
                                    DropdownMenuItem(
                                        value: label,
                                        child: Text(tr(context, label)))
                                ],
                                onChanged: saving
                                    ? null
                                    : (value) {
                                        if (value != null)
                                          setState(() => items[i].kind = value);
                                      },
                              )),
                              IconButton(
                                  tooltip: tr(context, '초안 항목 삭제'),
                                  onPressed: saving
                                      ? null
                                      : () => setState(
                                          () => removed.add(items.removeAt(i))),
                                  icon: Icon(Icons.close)),
                            ]),
                            SizedBox(height: 12),
                            TextField(
                                controller: items[i].controller,
                                enabled: !saving,
                                maxLines: null,
                                maxLength: 200,
                                decoration: InputDecoration(
                                    labelText: tr(context, '가지 내용'))),
                            Text('${tr(context, '원문')}: ${items[i].original}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]))),
            if (error != null)
              Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            SizedBox(height: 12),
            FilledButton.icon(
                onPressed: saving ? null : apply,
                icon: Icon(Icons.account_tree_outlined),
                label: Text(saving
                    ? tr(context, '추가 중…')
                    : tr(context, '확인한 초안을 나무에 추가'))),
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: Text(tr(context, '취소'))),
          ]),
        ),
      );
}
